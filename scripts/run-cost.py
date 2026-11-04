#!/usr/bin/env python3
"""Estimate the EC2 cost of a Nextflow run on AWS Batch from its trace file.

    uv run --with boto3 scripts/run-cost.py trace-rnaseq.txt

AWS Batch itself is free; the bill is the EC2 instances in the compute environment,
and several jobs share one instance. This script therefore reports two numbers:

  attributed  what each job "used": instance price x job runtime x the share of the
              instance's vCPU or memory the job reserved (whichever is larger). This is
              the same allocation logic as AWS Split Cost Allocation Data, computed
              locally and immediately instead of from the Cost and Usage Report a day
              later.
  incurred    what the run actually caused to be billed: every instance it used, from
              launch to termination, at the On-Demand price. The gap between the two is
              instance start-up, image pulls and idle time between jobs.

Instance details come from the Batch job (describe-jobs), the ECS container instance
and EC2. Terminated instances disappear from those APIs after about an hour, so run the
script soon after the pipeline finishes. For older runs the script falls back to the
Fargate On-Demand vCPU-hour and GB-hour rates as a proxy and says so.

Requires: batch:DescribeJobs, ecs:DescribeContainerInstances, ec2:DescribeInstances,
pricing:GetProducts, ssm:GetParameter. EBS, S3 and CloudWatch Logs are not included.
"""
import csv
import json
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone

try:
    import boto3
except ImportError:
    sys.exit("boto3 is not installed. Run:  uv run --with boto3 scripts/run-cost.py <trace>")

FARGATE_VCPU_HOUR = 0.04048   # us-east-1 Linux/x86 On-Demand, proxy only
FARGATE_GB_HOUR = 0.004445
MIB_PER_GIB = 1024.0


def chunks(seq, n):
    for i in range(0, len(seq), n):
        yield seq[i:i + n]


def read_trace(path):
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f, delimiter="\t"))
    rows = [r for r in rows if r.get("native_id") and r["native_id"] != "-"]
    if not rows:
        sys.exit(f"no Batch job ids (native_id) in {path}")
    return rows


def describe_jobs(batch, job_ids):
    out = {}
    for group in chunks(job_ids, 100):
        for j in batch.describe_jobs(jobs=group)["jobs"]:
            out[j["jobId"]] = j
    return out


def job_resources(job):
    vcpu = mem_mib = None
    for r in job.get("container", {}).get("resourceRequirements", []):
        if r["type"] == "VCPU":
            vcpu = float(r["value"])
        elif r["type"] == "MEMORY":
            mem_mib = float(r["value"])
    return vcpu or 1.0, mem_mib or 1024.0


def describe_instances(ecs, ec2, jobs):
    """container-instance ARN -> {instance_id, type, vcpu, mem_mib, launch, end}"""
    by_cluster = defaultdict(set)
    for j in jobs.values():
        arn = j.get("container", {}).get("containerInstanceArn")
        if arn:
            m = re.match(r"arn:aws:ecs:[^:]+:\d+:container-instance/([^/]+)/(.+)", arn)
            if m:
                by_cluster[m.group(1)].add(arn)
    info = {}
    ec2_ids = {}
    for cluster, arns in by_cluster.items():
        for group in chunks(sorted(arns), 100):
            try:
                resp = ecs.describe_container_instances(cluster=cluster, containerInstances=group)
            except Exception as e:  # cluster or instances already gone
                print(f"  note: {cluster}: {e.__class__.__name__}, instance details unavailable", file=sys.stderr)
                continue
            for ci in resp.get("containerInstances", []):
                res = {r["name"]: r for r in ci.get("registeredResources", [])}
                rec = {
                    "instance_id": ci["ec2InstanceId"],
                    "vcpu": res["CPU"]["integerValue"] / 1024.0 if "CPU" in res else None,
                    "mem_mib": float(res["MEMORY"]["integerValue"]) if "MEMORY" in res else None,
                    "type": None, "launch": None, "end": None,
                }
                info[ci["containerInstanceArn"]] = rec
                ec2_ids[ci["ec2InstanceId"]] = rec
    if ec2_ids:
        for group in chunks(sorted(ec2_ids), 100):
            try:
                resp = ec2.describe_instances(InstanceIds=group)
            except Exception as e:
                print(f"  note: describe-instances: {e.__class__.__name__}", file=sys.stderr)
                continue
            for r in resp["Reservations"]:
                for inst in r["Instances"]:
                    rec = ec2_ids[inst["InstanceId"]]
                    rec["type"] = inst["InstanceType"]
                    rec["launch"] = inst["LaunchTime"]
                    if inst["State"]["Name"] == "terminated":
                        m = re.search(r"\((\d{4}-\d\d-\d\d \d\d:\d\d:\d\d) GMT\)", inst.get("StateTransitionReason", ""))
                        if m:
                            rec["end"] = datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)
    return info


def on_demand_price(pricing, ssm, region, instance_type, cache={}):
    if instance_type in cache:
        return cache[instance_type]
    location = ssm.get_parameter(Name=f"/aws/service/global-infrastructure/regions/{region}/longName")["Parameter"]["Value"]
    flt = [
        {"Type": "TERM_MATCH", "Field": "instanceType", "Value": instance_type},
        {"Type": "TERM_MATCH", "Field": "location", "Value": location},
        {"Type": "TERM_MATCH", "Field": "operatingSystem", "Value": "Linux"},
        {"Type": "TERM_MATCH", "Field": "tenancy", "Value": "Shared"},
        {"Type": "TERM_MATCH", "Field": "preInstalledSw", "Value": "NA"},
        {"Type": "TERM_MATCH", "Field": "capacitystatus", "Value": "Used"},
    ]
    price = None
    for item in pricing.get_products(ServiceCode="AmazonEC2", Filters=flt)["PriceList"]:
        for term in json.loads(item)["terms"]["OnDemand"].values():
            for dim in term["priceDimensions"].values():
                price = float(dim["pricePerUnit"]["USD"])
    cache[instance_type] = price
    return price


def fmt_secs(s):
    s = int(round(s))
    return f"{s // 60}m{s % 60:02d}s" if s >= 60 else f"{s}s"


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    rows = read_trace(sys.argv[1])
    session = boto3.session.Session()
    region = session.region_name or "us-east-1"
    batch, ecs, ec2, ssm = (session.client(s) for s in ("batch", "ecs", "ec2", "ssm"))
    pricing = session.client("pricing", region_name="us-east-1")

    jobs = describe_jobs(batch, [r["native_id"] for r in rows])
    missing = [r["native_id"] for r in rows if r["native_id"] not in jobs]
    if missing:
        print(f"  note: {len(missing)} job(s) no longer in Batch (jobs expire after 7 days)", file=sys.stderr)
    instances = describe_instances(ecs, ec2, jobs)

    per_process = defaultdict(lambda: {"n": 0, "run_s": 0.0, "wait_s": 0.0, "usd": 0.0, "proxy": 0})
    per_instance = {}
    total_attr = total_wait = total_run = 0.0
    proxied = 0

    for r in rows:
        j = jobs.get(r["native_id"])
        if not j or "startedAt" not in j or "stoppedAt" not in j:
            continue
        name = re.sub(r" \(.*\)$", "", r["name"])
        vcpu, mem_mib = job_resources(j)
        run_s = (j["stoppedAt"] - j["startedAt"]) / 1000.0
        wait_s = (j["startedAt"] - j["createdAt"]) / 1000.0
        inst = instances.get(j.get("container", {}).get("containerInstanceArn"))
        if inst and inst["type"] and inst["vcpu"]:
            price = on_demand_price(pricing, ssm, region, inst["type"])
            share = max(vcpu / inst["vcpu"], mem_mib / inst["mem_mib"]) if inst["mem_mib"] else vcpu / inst["vcpu"]
            usd = price * run_s / 3600 * share
            key = inst["instance_id"]
            pi = per_instance.setdefault(key, {"type": inst["type"], "price": price, "launch": inst["launch"],
                                               "end": inst["end"], "jobs": 0, "last_stop": 0, "attr": 0.0})
            pi["jobs"] += 1
            pi["attr"] += usd
            pi["last_stop"] = max(pi["last_stop"], j["stoppedAt"] / 1000.0)
        else:
            usd = (vcpu * FARGATE_VCPU_HOUR + mem_mib / MIB_PER_GIB * FARGATE_GB_HOUR) * run_s / 3600
            per_process[name]["proxy"] += 1
            proxied += 1
        p = per_process[name]
        p["n"] += 1
        p["run_s"] += run_s
        p["wait_s"] += wait_s
        p["usd"] += usd
        total_attr += usd
        total_wait += wait_s
        total_run += run_s

    print(f"\nRun: {sys.argv[1]}   tasks: {len(rows)}   region: {region}\n")
    print(f"{'process':<58} {'tasks':>5} {'runtime':>9} {'wait':>9} {'attributed':>11}")
    for name, p in sorted(per_process.items(), key=lambda kv: -kv[1]["usd"]):
        flag = "*" if p["proxy"] else " "
        print(f"{name[:58]:<58} {p['n']:>5} {fmt_secs(p['run_s']):>9} {fmt_secs(p['wait_s']):>9} ${p['usd']:>9.4f}{flag}")
    print(f"{'TOTAL attributed (what the tasks used)':<58} {len(rows):>5} {fmt_secs(total_run):>9} {fmt_secs(total_wait):>9} ${total_attr:>9.4f}")
    if proxied:
        print(f"\n* {proxied} task(s) priced with Fargate per-vCPU/GB rates as a proxy: their instance is no longer "
              f"available to the API. Run this script within an hour of the pipeline finishing for exact figures.")

    if per_instance:
        print(f"\n{'instance':<20} {'type':<12} {'$/h':>7} {'jobs':>5} {'span':>9} {'incurred':>10} {'attributed':>11}")
        total_inc = 0.0
        now = datetime.now(timezone.utc).timestamp()
        for iid, pi in sorted(per_instance.items(), key=lambda kv: kv[1]["launch"] or 0):
            start = pi["launch"].timestamp() if pi["launch"] else None
            end = pi["end"].timestamp() if pi["end"] else None
            if start is None:
                span_txt, inc = "?", 0.0
            else:
                end_eff = end or max(pi["last_stop"], start)
                span = end_eff - start
                inc = pi["price"] * span / 3600
                span_txt = fmt_secs(span) + ("" if end else "+")
            total_inc += inc
            print(f"{iid:<20} {pi['type']:<12} {pi['price']:>7.4f} {pi['jobs']:>5} {span_txt:>9} ${inc:>8.4f} ${pi['attr']:>9.4f}")
        print(f"{'TOTAL incurred (what EC2 billed)':<46} {'':>9} ${total_inc:>8.4f} ${total_attr:>9.4f}")
        if any(pi["end"] is None for pi in per_instance.values()):
            print("\n+ instance still running or termination time not yet visible: span counted up to the last job on it;\n"
                  "  Batch keeps an idle instance a few more minutes before terminating it, so the final bill is a little higher.")
        if total_inc > 0:
            print(f"\nUtilisation (attributed / incurred): {100 * total_attr / total_inc:.0f}%  "
                  f"-- the rest is instance start-up, image pulls and idle time.")


if __name__ == "__main__":
    main()
