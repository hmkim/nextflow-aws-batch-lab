# Kiro로 따라가는 라이브 실습

[English guide](KIRO.md) · [繁體中文指南](KIRO.zh-TW.md)

이 가이드는 세션 전 환경 설정이 끝난 시점부터 시작합니다. [참가자 페이지](https://aws-sa.notion.site/Taiwan-Bioinformatics-Workflow-Workshop-AWS-Hands-on-Guide-14-November-2026-41455978597981039feac5474c869e6d)를 따라 Workshop Studio에 접속하고 Kiro IDE를 연 뒤, 리포지토리를 복제하고 10:25까지 AWS Batch 환경을 준비하세요.

라이브 세션에서는 이 가이드를 열어 두고 각 프롬프트를 같은 Kiro 채팅에 붙여 넣습니다. 그래야 Kiro가 앞 단계의 파일과 실행 결과를 이어서 사용할 수 있습니다.

> 랩에서 제공하는 샘플 데이터만 사용하세요. 환자 데이터, 개인을 식별할 수 있는 데이터, 독점 데이터, 미공개 연구 데이터를 임시 워크숍 계정에 업로드하지 마세요.

## 시작 준비 확인

다음 상태이면 라이브 실습을 시작할 수 있습니다.

- Kiro에서 `nextflow-aws-batch-lab` 폴더가 열려 있고 신뢰된 상태입니다.
- `nextflow-batch-queue`가 `ENABLED`와 `VALID` 상태입니다.
- 컴퓨팅 환경이 `VALID`이고 desired vCPU가 0입니다.

하나라도 맞지 않으면 첫 실행 전에 손을 들어 도움을 요청하세요. 개인 환경에서 진행하는 방법은 [이 가이드의 마지막](#self-paced-setup)에 접어 두었습니다.

## 1. 콜드 런과 웜 런 실행

이 프롬프트는 GreetingsNF를 연속으로 두 번 실행합니다. 첫 번째 작업은 0에서 컴퓨팅 환경을 시작합니다. 두 번째 작업은 실행 중인 인스턴스를 재사용할 수 있도록 첫 번째 작업 직후 제출됩니다.

Kiro에 붙여 넣으세요.

```text
Run the GreetingsNF pipeline on AWS Batch twice from the repository root.

First run:
nextflow run main.nf -profile batch --addressee 'AWS Batch' -with-trace trace-cold.txt

As soon as it finishes, immediately run:
nextflow run main.nf -profile batch --addressee 'warm run' -with-trace trace-warm.txt

Do not pause between the two runs. When both are complete, show the Duration and Succeeded count for each run, show the content of /mnt/workflow/pubdir/output, and compare how long the two Batch jobs waited between submission and start.
```

Kiro가 실행하는 동안 [AWS Batch 작업 페이지](https://console.aws.amazon.com/batch/home#jobs)를 여세요. `nextflow-batch-queue`를 선택하고 **Search**를 누른 뒤 작업 상태가 `RUNNABLE`, `STARTING`, `RUNNING` 순서로 바뀌는 것을 확인합니다.

![AWS Batch 작업](images/jobs-list.png)

첫 실행은 AWS Batch가 Amazon EC2 인스턴스를 시작하고 컨테이너 이미지를 받아야 하므로 보통 2~4분 걸립니다. 첫 인스턴스가 남아 있으면 두 번째 실행은 몇 초 안에 시작합니다.

> 확인 기준: 두 실행이 모두 성공하고 최종 출력이 `hello warm run`입니다. 두 번째 실행도 콜드 런이 되었다면 실패가 아닙니다. 컴퓨팅 환경이 다시 0으로 축소된 결과입니다.

## 2. Nextflow와 AWS Batch의 실행 관계 확인

Kiro가 두 실행의 설정, trace 파일, Batch 작업 metadata를 읽어 실행 관계를 설명합니다.

Kiro에 붙여 넣으세요.

```text
Using nextflow.config, trace-cold.txt, trace-warm.txt and AWS Batch job metadata, explain:

1. Which job queue and container image were used.
2. How one invocation of the Greet process became one Batch job.
3. What Nextflow registered as the job definition.
4. Compare how long the two jobs waited and explain why they did or did not differ.

Keep the explanation under 200 words.
```

Job definition은 AWS Batch가 컨테이너를 실행할 때 사용하는 템플릿입니다. Nextflow는 컨테이너 이미지에 맞는 job definition을 만들거나 재사용하고, 작업을 제출할 때 해당 task의 resource request를 전달합니다.

> 확인 기준: `Greet` process 한 번의 실행이 Batch 작업 하나로 연결됩니다. Kiro가 `nextflow-batch-queue`와 `ubuntu:22.04` 컨테이너 이미지를 확인합니다.

## 3. Resource request 변경

이 단계에서는 pipeline을 수정하지 않습니다. 별도 설정 파일로 `Greet` process의 CPU와 memory request만 바꿉니다.

Kiro에 붙여 넣으세요.

```text
Without editing main.nf or nextflow.config, create resources.config that sets cpus = 4 and memory = '8 GB' for the Greet process only, using process { withName: 'Greet' { ... } }.

Run:
nextflow run main.nf -profile batch -c resources.config --addressee 'bigger' -with-trace trace-bigger.txt

When the run finishes, read the `native_id` from trace-bigger.txt and inspect that exact AWS Batch job. Report the VCPU and MEMORY values that Batch received, and confirm whether the existing job definition was reused. Report the EC2 instance type if it is still available, but explain that the exact type can vary.
```

> 확인 기준: AWS Batch가 `4 VCPU`와 `8192 MEMORY`를 받았습니다. EC2 instance type은 실행 시점의 가용 용량에 따라 달라질 수 있으므로 통과 기준이 아닙니다.

## 4. nf-core/sarek 시작

마지막 라이브 실습에서는 여러 process로 구성된 실제 bioinformatics workflow를 시작합니다. Test profile은 작은 공개 데이터셋을 사용하며 background에서 실행됩니다.

Kiro에 붙여 넣으세요.

```text
Start the nf-core/sarek test profile on the Batch environment in the background. Read the work bucket from nextflow.config and run:

nextflow -bg run nf-core/sarek -r 3.5.1 -profile test,batch --outdir s3://<work-bucket>/nextflow-batch/sarek-test -with-trace trace-sarek.txt -ansi-log false > sarek.log 2>&1

Replace <work-bucket> with the bucket from nextflow.config. Do not use nohup. Do not wait for completion. Confirm that the run started, show the first lines of sarek.log, and return control to me.
```

참가자 실행이 계속되는 동안 진행자가 완료된 reference run을 보여 줍니다. Reference run은 23개 task를 약 10~15분 안에 완료했습니다. 결과에는 VCF 파일(variant call 결과 파일)과 MultiQC report(품질 관리 결과를 모은 보고서)가 포함됩니다.

나중에 다음 프롬프트로 진행 상태를 확인할 수 있습니다.

```text
Check the nf-core/sarek run. Show the last ten lines of sarek.log. Count submitted tasks from .nextflow.log and completed tasks from trace-sarek.txt, excluding the header. Tell me whether the workflow is still running or has completed.
```

> 확인 기준: nf-core/sarek 실행이 background에서 시작됐습니다. Q&A 전에 완료될 때까지 기다릴 필요는 없습니다.

## 라이브 실습 완료

Nextflow process를 AWS Batch 작업으로 실행했고, AWS Batch가 용량을 새로 시작하거나 기존 용량을 재사용하는 모습을 확인했습니다. Pipeline을 수정하지 않고 task resource를 변경했으며 nf-core/sarek workflow를 시작했습니다.

Q&A는 11:20에 시작합니다. 워크숍 계정은 직접 정리하지 않아도 됩니다. 환경은 Taipei time 18:00까지 사용할 수 있습니다.

> Kiro는 준비된 랩을 실행하고 결과를 설명합니다. Scientific 또는 clinical 결과를 검증하거나, 민감 데이터 사용을 승인하거나, 정확한 실행 시간과 instance type 및 비용을 보장하지는 않습니다.

수동 명령, 문제 해결, 비용 측정, Mountpoint for Amazon S3, AWS HealthOmics 비교는 [참가자 Appendix](https://aws-sa.notion.site/Appendix-References-Troubleshooting-and-Self-Paced-Exercises-41755978597981a6adebc897ae969f67) 또는 [README](README.ko.md)를 참고하세요.

---

<a id="self-paced-setup"></a>

<details>
<summary><b>라이브 워크숍 밖에서 직접 설정하기</b></summary>

라이브 워크숍에서는 첫 실행 전에 참가자 페이지를 따라 아래 단계를 완료합니다. 다른 환경에서 랩을 다시 실행할 때 이 섹션을 사용하세요.

### 요구 사항

AWS account, `sudo`를 사용할 수 있는 Linux shell, Nextflow work directory용 S3 bucket이 필요합니다. 설정 과정에서 IAM role과 AWS Batch resource를 만들기 때문에 administrator 수준의 권한이 필요합니다. 전체 권한은 [README의 사전 요구 사항](README.ko.md#사전-요구-사항)을 참고하세요.

Shell에서 AWS credentials를 사용할 수 있는지 확인합니다.

```bash
aws sts get-caller-identity --query Arn --output text
```

Kiro CLI 사용자는 로그인 상태를 확인합니다.

```bash
kiro-cli whoami
```

Identity가 출력되지 않으면 `kiro-cli login`을 실행합니다. Kiro IDE에서는 account menu를 확인합니다. Workshop Studio IDE는 API key로 미리 로그인되어 있습니다.

### 리포지토리 복제 및 신뢰

```bash
git clone https://github.com/hmkim/nextflow-aws-batch-lab.git
cd nextflow-aws-batch-lab
```

Kiro IDE에서 이 폴더를 열거나 repository root에서 Kiro CLI를 시작합니다.

```bash
kiro-cli chat
```

Kiro가 workspace 신뢰 여부를 묻는다면 **Trust**를 선택합니다. 그러면 Kiro가 `.kiro/steering/aws-batch-lab.md`를 읽고 랩에서 허용된 범위 안에서 작업합니다.

### 환경 설정

Kiro에 붙여 넣으세요.

```text
Run the lab setup script: bash scripts/setup-nextflow-batch.sh from the repository root, and show me its output. Do not modify the script or the CloudFormation template, and do not deploy anything by other means. When it finishes, check with aws batch describe-job-queues and aws batch describe-compute-environments that the job queue nextflow-batch-queue is ENABLED and VALID and that the compute environment is VALID with 0 desired vCPUs, then tell me the stack is ready.
```

워크숍 밖에서는 `<your-work-bucket>`을 자신의 bucket 이름으로 바꾸고 다음 프롬프트를 붙여 넣으세요.

```text
Run the lab setup script with WORK_BUCKET=<your-work-bucket> bash scripts/setup-nextflow-batch.sh from the repository root, and show me its output. Do not modify the script or the CloudFormation template, and do not deploy anything by other means. When it finishes, check with aws batch describe-job-queues and aws batch describe-compute-environments that the job queue nextflow-batch-queue is ENABLED and VALID and that the compute environment is VALID with 0 desired vCPUs, then tell me the stack is ready.
```

Queue가 `ENABLED`와 `VALID`이고 compute environment가 `VALID`와 0 desired vCPUs이면 설정이 끝난 상태입니다.

</details>

<details>
<summary><b>개인 환경에서 Kiro 사용하기: 권한과 승인</b></summary>

Workshop Studio는 이 랩에서 사용하는 도구를 미리 승인합니다. 개인 Kiro 환경에서는 shell command 실행, file write, web page fetch, MCP tool 호출 전에 승인을 요청할 수 있습니다.

허용하기 전에 요청된 동작을 확인하세요. `nextflow *`와 read-only AWS command에 session 범위 규칙을 만들면 반복 요청을 줄일 수 있습니다. Setup script, CloudFormation template, `main.nf`, `nextflow.config`를 다시 쓰는 명령은 승인하지 마세요.

Kiro CLI의 foreground command는 15분 뒤 중단될 수 있습니다. 그래서 nf-core/sarek 단계는 `nextflow -bg`를 사용합니다. `nohup`으로 바꾸지 마세요.

</details>

<details>
<summary><b>선택: AWS MCP server로 문서 검색하기</b></summary>

라이브 AWS Batch 실습에는 MCP server가 필요하지 않습니다. 랩 이후 Kiro로 AWS documentation을 검색하려는 경우에만 `aws-mcp`를 설정하세요.

Workshop Studio IDE에는 미리 설정되어 있습니다. 다른 환경에서는 SigV4 proxy를 `~/.kiro/settings/mcp.json`에 추가합니다.

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

연결 방법은 [AWS MCP Server guide](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/getting-started-aws-mcp-server.html)를 참고하세요.

</details>

<details>
<summary><b>선택: 실행 비용 추정</b></summary>

Pipeline 종료 후 instance metadata가 남아 있는 약 1시간 안에 estimator를 실행하세요.

```text
Run these commands one at a time and do not modify the script:

uv run --with boto3 scripts/run-cost.py trace-cold.txt
uv run --with boto3 scripts/run-cost.py trace-warm.txt
uv run --with boto3 scripts/run-cost.py trace-bigger.txt

Explain the difference between attributed and incurred cost.
```

Attributed cost는 task가 사용한 몫의 추정치입니다. Incurred cost는 instance 시작부터 종료까지의 EC2 비용 추정치입니다. 최종 AWS 청구 금액은 아닙니다. Billing data를 이용한 방법은 [비용 측정](README.ko.md#비용-측정)을 참고하세요.

</details>

<details>
<summary><b>문제 해결</b></summary>

| 증상 | 다음 동작 |
|---|---|
| `Trace file already exists` | Kiro에게 해당 trace 파일만 삭제하게 한 뒤 단계를 다시 실행합니다. |
| 콜드 런이 2~3분 동안 조용함 | 기다립니다. AWS Batch가 용량을 시작하고 있습니다. |
| 작업이 10분 동안 `RUNNABLE` 상태임 | 손을 들어 도움을 요청하고 Kiro에게 compute environment의 status reason을 읽게 합니다. |
| Kiro가 `.nextflow.log`를 읽지 못함 | Repository root에서 채팅을 다시 시작합니다. |
| Kiro가 다른 설정을 제안하거나 보호된 랩 파일을 수정함 | Turn을 중단하고 repository steering file을 따르라고 지시합니다. |

더 많은 원인과 진단 명령은 [README의 문제 해결 표](README.ko.md#문제-해결)를 참고하세요.

</details>
