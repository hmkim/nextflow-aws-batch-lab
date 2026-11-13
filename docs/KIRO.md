# Follow the live lab with Kiro

[한국어 가이드](KIRO.ko.md) · [繁體中文指南](KIRO.zh-TW.md)

This guide starts after the pre-session setup is complete. Use the [participant page](https://aws-sa.notion.site/Taiwan-Bioinformatics-Workflow-Workshop-AWS-Hands-on-Guide-14-November-2026-41455978597981039feac5474c869e6d) to join Workshop Studio, open Kiro IDE, clone the repository, and prepare the AWS Batch environment by 10:25.

Keep this guide open during the live session. Paste each prompt into the same Kiro chat so it can use the files and results from the previous step.

> Use only the sample data provided in the lab. Do not upload patient data, identifiable data, proprietary datasets, or unpublished research data to the temporary workshop account.

## Ready to start

You are ready when:

- The `nextflow-aws-batch-lab` folder is open and trusted in Kiro.
- `nextflow-batch-queue` is `ENABLED` and `VALID`.
- The compute environment is `VALID` with 0 desired vCPUs.

If one of these checks fails, raise your hand before starting the first run. Self-paced setup instructions are [at the end of this guide](#self-paced-setup).

## 1. Run the cold and warm pipelines

This prompt runs GreetingsNF twice. The first job starts the compute environment from zero. The second job is submitted immediately so it can reuse the running instance.

Paste into Kiro:

```text
Run the GreetingsNF pipeline on AWS Batch twice from the repository root.

First run:
nextflow run main.nf -profile batch --addressee 'AWS Batch' -with-trace trace-cold.txt

As soon as it finishes, immediately run:
nextflow run main.nf -profile batch --addressee 'warm run' -with-trace trace-warm.txt

Do not pause between the two runs. When both are complete, show the Duration and Succeeded count for each run, show the content of /mnt/workflow/pubdir/output, and compare how long the two Batch jobs waited between submission and start.
```

While Kiro runs, open the [AWS Batch jobs page](https://console.aws.amazon.com/batch/home#jobs). Select `nextflow-batch-queue`, choose **Search**, and watch the job move through `RUNNABLE`, `STARTING`, and `RUNNING`.

![AWS Batch jobs](images/jobs-list.png)

The first run normally takes two to four minutes because AWS Batch must launch an Amazon EC2 instance and pull the container image. The second run normally starts within seconds if that instance is still available.

> Checkpoint: Both runs succeeded. The final output reads `hello warm run`. If the second run is cold again, it is still a valid scale-to-zero result rather than a lab failure.

## 2. See how Nextflow maps to AWS Batch

Kiro now reads the configuration, trace files, and Batch job metadata from the two runs.

Paste into Kiro:

```text
Using nextflow.config, trace-cold.txt, trace-warm.txt and AWS Batch job metadata, explain:

1. Which job queue and container image were used.
2. How one invocation of the Greet process became one Batch job.
3. What Nextflow registered as the job definition.
4. Compare how long the two jobs waited and explain why they did or did not differ.

Keep the explanation under 200 words.
```

A job definition is the template AWS Batch uses to run a container. Nextflow creates or reuses one for the container image and sends the task-specific resource request when it submits the job.

> Checkpoint: One invocation of the `Greet` process mapped to one Batch job. Kiro identified `nextflow-batch-queue` and the `ubuntu:22.04` container image.

## 3. Change the resource request

The pipeline does not change in this step. A second configuration file changes only the CPU and memory request for the `Greet` process.

Paste into Kiro:

```text
Without editing main.nf or nextflow.config, create resources.config that sets cpus = 4 and memory = '8 GB' for the Greet process only, using process { withName: 'Greet' { ... } }.

Run:
nextflow run main.nf -profile batch -c resources.config --addressee 'bigger' -with-trace trace-bigger.txt

When the run finishes, read the `native_id` from trace-bigger.txt and inspect that exact AWS Batch job. Report the VCPU and MEMORY values that Batch received, and confirm whether the existing job definition was reused. Report the EC2 instance type if it is still available, but explain that the exact type can vary.
```

> Checkpoint: AWS Batch received `4 VCPU` and `8192 MEMORY`. The exact EC2 instance type is not a pass condition.

## 4. Start nf-core/sarek

The last live exercise starts a real, multi-process bioinformatics workflow. The test profile uses a small public dataset and runs in the background.

Paste into Kiro:

```text
Start the nf-core/sarek test profile on the Batch environment in the background. Read the work bucket from nextflow.config and run:

nextflow -bg run nf-core/sarek -r 3.5.1 -profile test,batch --outdir s3://<work-bucket>/nextflow-batch/sarek-test -with-trace trace-sarek.txt -ansi-log false > sarek.log 2>&1

Replace <work-bucket> with the bucket from nextflow.config. Do not use nohup. Do not wait for completion. Confirm that the run started, show the first lines of sarek.log, and return control to me.
```

The instructor will show a completed reference run while participant runs continue. The reference run completed 23 tasks in about 10 to 15 minutes. Its outputs include VCF files (variant-call results) and a MultiQC report (a combined quality-control report).

Check your run later with this prompt:

```text
Check the nf-core/sarek run. Show the last ten lines of sarek.log. Count submitted tasks from .nextflow.log and completed tasks from trace-sarek.txt, excluding the header. Tell me whether the workflow is still running or has completed.
```

> Checkpoint: The nf-core/sarek run started in the background. You do not need to wait for it to finish before Q&A.

## Live lab complete

You have run a Nextflow process as an AWS Batch job, observed how AWS Batch starts or reuses capacity, changed task resources without editing the pipeline, and started an nf-core/sarek workflow.

Q&A begins at 11:20. You do not need to clean up the workshop account. It remains available until 18:00 Taipei time.

> Kiro runs and explains the prepared lab. It does not validate scientific or clinical results, approve sensitive-data use, or guarantee exact timing, instance type, or cost.

For manual commands, troubleshooting, cost measurement, Mountpoint for Amazon S3, and the AWS HealthOmics comparison, use the [participant appendix](https://aws-sa.notion.site/Appendix-References-Troubleshooting-and-Self-Paced-Exercises-41755978597981a6adebc897ae969f67) or the [README](../README.md).

---

<a id="self-paced-setup"></a>

<details>
<summary><b>Self-paced setup outside the live workshop</b></summary>

The live workshop completes these steps from the participant page before the first run. Use this section when you repeat the lab elsewhere.

### Requirements

You need an AWS account, a Linux shell with `sudo`, and an S3 bucket for the Nextflow work directory. The setup creates IAM roles and AWS Batch resources, so it needs administrator-level permissions. See the [README prerequisites](../README.md#prerequisites) for the full policy details.

Check that the shell has AWS credentials:

```bash
aws sts get-caller-identity --query Arn --output text
```

Kiro CLI users can check sign-in with:

```bash
kiro-cli whoami
```

Run `kiro-cli login` if no identity is returned. Kiro IDE users can check the account menu. The Workshop Studio IDE is already signed in with an API key.

### Clone and trust the repository

```bash
git clone https://github.com/hmkim/nextflow-aws-batch-lab.git
cd nextflow-aws-batch-lab
```

Open this folder in Kiro IDE, or start Kiro CLI from the repository root:

```bash
kiro-cli chat
```

Choose **Trust** if Kiro asks whether to trust the workspace. This lets Kiro load `.kiro/steering/aws-batch-lab.md`, which limits the changes it may make during the lab.

### Set up the environment

Paste into Kiro:

```text
Run the lab setup script: bash scripts/setup-nextflow-batch.sh from the repository root, and show me its output. Do not modify the script or the CloudFormation template, and do not deploy anything by other means. When it finishes, check with aws batch describe-job-queues and aws batch describe-compute-environments that the job queue nextflow-batch-queue is ENABLED and VALID and that the compute environment is VALID with 0 desired vCPUs, then tell me the stack is ready.
```

Outside the workshop account, replace `<your-work-bucket>` and paste this prompt instead:

```text
Run the lab setup script with WORK_BUCKET=<your-work-bucket> bash scripts/setup-nextflow-batch.sh from the repository root, and show me its output. Do not modify the script or the CloudFormation template, and do not deploy anything by other means. When it finishes, check with aws batch describe-job-queues and aws batch describe-compute-environments that the job queue nextflow-batch-queue is ENABLED and VALID and that the compute environment is VALID with 0 desired vCPUs, then tell me the stack is ready.
```

Setup is complete when the queue is `ENABLED` and `VALID`, and the compute environment is `VALID` with 0 desired vCPUs.

</details>

<details>
<summary><b>Using Kiro on your own machine: permissions and approvals</b></summary>

Workshop Studio pre-approves the tools used by this lab. A personal Kiro installation can ask before it runs shell commands, writes files, fetches web pages, or calls MCP tools.

Review the requested action before allowing it. Session-scoped rules for `nextflow *` and the read-only AWS commands can reduce repeated prompts. Do not approve a command that rewrites the setup script, CloudFormation template, `main.nf`, or `nextflow.config`.

A foreground Kiro CLI command can stop after 15 minutes. The nf-core/sarek step uses `nextflow -bg` for that reason. Do not replace it with `nohup`.

</details>

<details>
<summary><b>Optional: AWS MCP server for documentation questions</b></summary>

The live AWS Batch lab does not require an MCP server. Configure `aws-mcp` only if you want Kiro to search AWS documentation after the lab.

The Workshop Studio IDE has it preconfigured. On another machine, add the SigV4 proxy to `~/.kiro/settings/mcp.json`:

```json
{
  "mcpServers": {
    "aws-mcp": {
      "command": "uvx",
      "args": ["mcp-proxy-for-aws@latest", "https://aws-mcp.us-east-1.api.aws/mcp"],
      "timeout": 100000,
      "transport": "stdio"
    }
  }
}
```

The [AWS MCP Server guide](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/getting-started-aws-mcp-server.html) covers the connection details.

</details>

<details>
<summary><b>Optional: estimate run cost</b></summary>

Run the estimator within about an hour of the pipeline finishing, while the instance metadata is still available:

```text
Run these commands one at a time and do not modify the script:

uv run --with boto3 scripts/run-cost.py trace-cold.txt
uv run --with boto3 scripts/run-cost.py trace-warm.txt
uv run --with boto3 scripts/run-cost.py trace-bigger.txt

Explain the difference between attributed and incurred cost.
```

Attributed cost estimates the share used by a task. Incurred cost estimates the EC2 instance cost from launch through termination. This is not the final AWS bill. See [Measuring cost](../README.md#measuring-cost) for the billing-data method.

</details>

<details>
<summary><b>Troubleshooting</b></summary>

| Symptom | Next action |
|---|---|
| `Trace file already exists` | Ask Kiro to delete only that old trace file, then repeat the step. |
| A cold run is quiet for two to three minutes | Wait. AWS Batch is launching capacity. |
| A job stays `RUNNABLE` for ten minutes | Raise your hand. Ask Kiro to read the compute environment status reason. |
| Kiro cannot read `.nextflow.log` | Start the chat from the repository root. |
| Kiro proposes a different setup or edits a protected lab file | Stop the turn and tell it to follow the repository steering file. |

The [README troubleshooting table](../README.md#troubleshooting) covers additional causes and diagnostic commands.

</details>
