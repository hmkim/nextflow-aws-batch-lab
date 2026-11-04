#!/usr/bin/env bash
# setup-nextflow-batch.sh
#
# One-shot environment setup for the "Nextflow on AWS Batch" lab. Run it from the
# repository root (bash scripts/setup-nextflow-batch.sh) on any Linux machine with
# AWS credentials. Every step is idempotent, so it is safe to run again.
#
#   1. Install Java 17 and Nextflow on this machine (the Nextflow "head node")
#   2. Discover the region, default VPC, subnets and workshop buckets
#   3. Deploy the AWS Batch stack (batch-nextflow.yaml) with CloudFormation
#   4. Write nextflow.config with a "batch" profile pointing at the new job queue
#   5. Make sure main.nf (GreetingsNF) is in LAB_DIR
#
# Options (environment variables):
#   STACK_NAME         CloudFormation stack name        (default: nextflow-batch)
#   LAB_DIR            where main.nf/nextflow.config go  (default: repository root)
#   TEMPLATE_FILE      path to batch-nextflow.yaml       (default: <repo>/cfn/batch-nextflow.yaml)
#   WORK_BUCKET        S3 bucket for the Nextflow work dir (default: first omics-output-* bucket)
#   DATA_BUCKET        optional bucket with reference data (default: first genomics-data-* bucket, or none)
#   MOUNT_DATA_BUCKET  true|false, mount DATA_BUCKET with Mountpoint for S3 (default: false)
#   MAX_VCPUS          compute environment ceiling       (default: 16)
#   NXF_VER            Nextflow release to install       (default: 24.10.5, same major as HealthOmics)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_NAME="${STACK_NAME:-nextflow-batch}"
LAB_DIR="${LAB_DIR:-$REPO_DIR}"
TEMPLATE_FILE="${TEMPLATE_FILE:-$REPO_DIR/cfn/batch-nextflow.yaml}"
MOUNT_DATA_BUCKET="${MOUNT_DATA_BUCKET:-false}"
MAX_VCPUS="${MAX_VCPUS:-16}"
NXF_VER="${NXF_VER:-24.10.5}"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[1;32m%s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

mkdir -p "$LAB_DIR"
[ -f "$TEMPLATE_FILE" ] || die "template not found: $TEMPLATE_FILE"

# ---------------------------------------------------------------------------
step "1/5 Installing Java 17 and Nextflow"
# ---------------------------------------------------------------------------
if java -version 2>&1 | grep -Eq 'version "(17|21)'; then
  ok "Java already installed: $(java -version 2>&1 | head -1)"
else
  sudo dnf install -y -q java-17-amazon-corretto-headless
  ok "Installed $(java -version 2>&1 | head -1)"
fi

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
# Pin the same Nextflow release HealthOmics runs (24.10.x), so the main.nf from module
# 140 runs unchanged. Nextflow 25+ enables the strict parser, which rejects the
# top-level `if (...) exit 1` guard in that file.
if nextflow -version 2>/dev/null | grep -q "version $NXF_VER"; then
  ok "Nextflow $NXF_VER already installed"
else
  curl -fsSL "https://github.com/nextflow-io/nextflow/releases/download/v${NXF_VER}/nextflow-${NXF_VER}-dist" \
    -o "$HOME/.local/bin/nextflow"
  chmod +x "$HOME/.local/bin/nextflow"
  ok "Installed $(nextflow -version 2>/dev/null | grep -i version | xargs)"
fi

# ---------------------------------------------------------------------------
step "2/5 Discovering region, VPC and buckets"
# ---------------------------------------------------------------------------
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300" || true)
AWS_REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || true)
AWS_REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || echo "${AWS_DEFAULT_REGION:-us-east-1}")}"
export AWS_REGION AWS_DEFAULT_REGION="$AWS_REGION"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true \
  --query 'Vpcs[0].VpcId' --output text)
[ "$VPC_ID" != "None" ] || die "no default VPC in $AWS_REGION; set VPC_ID/SUBNET_IDS manually"
SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$VPC_ID" Name=default-for-az,Values=true \
  --query 'Subnets[].SubnetId' --output text | tr '\t' ',')
WORK_BUCKET="${WORK_BUCKET:-$(aws s3api list-buckets \
  --query "Buckets[?starts_with(Name, 'omics-output-')].Name | [0]" --output text)}"
DATA_BUCKET="${DATA_BUCKET:-$(aws s3api list-buckets \
  --query "Buckets[?starts_with(Name, 'genomics-data-')].Name | [0]" --output text)}"
[ -n "$WORK_BUCKET" ] && [ "$WORK_BUCKET" != "None" ] \
  || die "no work bucket: set WORK_BUCKET=<bucket> (no omics-output-* bucket found in this account)"
aws s3api head-bucket --bucket "$WORK_BUCKET" >/dev/null 2>&1 || die "cannot access s3://$WORK_BUCKET"
[ "$DATA_BUCKET" != "None" ] || DATA_BUCKET=""

ok "Region      : $AWS_REGION"
ok "Account     : $ACCOUNT_ID"
ok "VPC         : $VPC_ID"
ok "Subnets     : $SUBNET_IDS"
ok "Work bucket : s3://$WORK_BUCKET"
ok "Data bucket : ${DATA_BUCKET:-(none)}  mount=$MOUNT_DATA_BUCKET"

# ---------------------------------------------------------------------------
step "3/5 Deploying AWS Batch stack '$STACK_NAME' (3-5 minutes)"
# ---------------------------------------------------------------------------
PARAMS_FILE="$LAB_DIR/.stack-parameters.json"
cat > "$PARAMS_FILE" <<EOF
[
  {"ParameterKey": "VpcId",           "ParameterValue": "$VPC_ID"},
  {"ParameterKey": "SubnetIds",       "ParameterValue": "$SUBNET_IDS"},
  {"ParameterKey": "WorkBucket",      "ParameterValue": "$WORK_BUCKET"},
  {"ParameterKey": "DataBucket",      "ParameterValue": "$DATA_BUCKET"},
  {"ParameterKey": "MountDataBucket", "ParameterValue": "$MOUNT_DATA_BUCKET"},
  {"ParameterKey": "MaxvCpus",        "ParameterValue": "$MAX_VCPUS"}
]
EOF

aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --parameter-overrides "file://$PARAMS_FILE" \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset

JOB_QUEUE=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='JobQueueName'].OutputValue" --output text)
MOUNT_PATH=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='MountPath'].OutputValue" --output text)
ok "Job queue   : $JOB_QUEUE"
[ -z "$MOUNT_PATH" ] || ok "Mountpoint  : s3://$DATA_BUCKET -> $MOUNT_PATH (on compute instances)"

# ---------------------------------------------------------------------------
step "4/5 Writing $LAB_DIR/nextflow.config"
# ---------------------------------------------------------------------------
VOLUMES_LINE=""
[ -z "$MOUNT_PATH" ] || VOLUMES_LINE="        volumes = '$MOUNT_PATH:$MOUNT_PATH:ro'"

cat > "$LAB_DIR/nextflow.config" <<EOF
// Generated by setup-nextflow-batch.sh on $(date -u +%Y-%m-%dT%H:%MZ)
// Select with:  nextflow run main.nf -profile batch ...
// Credentials come from the environment (instance role or AWS CLI profile).
// Do not add aws.accessKey / aws.secretKey here.

profiles {
    batch {
        process {
            executor  = 'awsbatch'
            queue     = '$JOB_QUEUE'
            container = 'public.ecr.aws/docker/library/ubuntu:22.04'
            // Tags on every Batch job (and, via propagateTags, its ECS task). Activate them as
            // cost allocation tags to get per-run and per-process cost in the Cost and Usage Report.
            resourceLabels = { [
                'nf-run'      : workflow.runName,
                'nf-session'  : workflow.sessionId.toString(),
                'nf-pipeline' : (workflow.manifest.name ?: workflow.scriptName),
                'nf-process'  : task.process
            ] }
        }
        workDir = 's3://$WORK_BUCKET/nextflow-batch/work'
        aws {
            region = '$AWS_REGION'
            batch {
                // AWS CLI installed on the compute instances by the launch template.
                // Nextflow mounts it into each task container to stage files to/from S3.
                cliPath = '/opt/aws-cli/bin/aws'
                maxParallelTransfers = 4
$VOLUMES_LINE
            }
        }
    }
}
EOF
ok "profile 'batch' -> queue $JOB_QUEUE, workDir s3://$WORK_BUCKET/nextflow-batch/work"

# ---------------------------------------------------------------------------
step "5/5 Preparing the GreetingsNF pipeline"
# ---------------------------------------------------------------------------
# The same main.nf the HealthOmics workshop registers as a private workflow. publishDir
# points at /mnt/workflow/pubdir, the HealthOmics output path; create it here so the head
# node can publish results to it unchanged.
if [ -f "$REPO_DIR/main.nf" ] && [ ! -f "$LAB_DIR/main.nf" ]; then
  cp "$REPO_DIR/main.nf" "$LAB_DIR/main.nf"
  ok "Copied main.nf from the repository"
elif [ ! -f "$LAB_DIR/main.nf" ]; then
  cat > "$LAB_DIR/main.nf" <<'EOF'
nextflow.enable.dsl = 2

params.greeting = 'hello'
params.addressee = null

if (!params.addressee) exit 1, "required parameter 'addressee' missing"

process Greet {
    publishDir '/mnt/workflow/pubdir'
    input:
        val greeting
        val addressee
    output:
        path "output", emit: output_file
    script:
        """
        echo "${greeting} ${addressee}" | tee output
        """
}

workflow {
    Greet(params.greeting, params.addressee)
}
EOF
  ok "Created main.nf"
else
  ok "main.nf already present"
fi
sudo mkdir -p /mnt/workflow/pubdir
sudo chown "$(id -u):$(id -g)" /mnt/workflow/pubdir

cat <<EOF

Setup complete. Next:

    cd $LAB_DIR
    nextflow run main.nf -profile batch --addressee 'AWS Batch'

EOF
