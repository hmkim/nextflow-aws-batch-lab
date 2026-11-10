# Kiro로 따라가는 실습

[README](README.ko.md)는 터미널에서 명령을 직접 입력하며 이 랩을 진행합니다. 이 가이드는 같은 랩을 Kiro로 진행합니다. 단계마다 프롬프트 하나를 Kiro CLI 또는 Kiro IDE의 채팅에 붙여 넣으면 Kiro가 랩의 스크립트와 명령을 실행하고, 참가자는 그 보고를 읽습니다. 만들어지는 AWS 리소스, 파이프라인, 결과는 똑같습니다. 달라지는 것은 누가 명령을 치고 누가 출력을 설명하는가입니다.

[English guide](KIRO.md)

아래 각 단계는 네 부분으로 되어 있습니다. 붙여 넣을 프롬프트, 프롬프트를 따라 Kiro가 실제로 실행한 명령, 참가자가 보게 될 승인 프롬프트 횟수, 성공했을 때의 모습입니다. 소요 시간과 승인 횟수는 2026-11-10에 워크숍 IDE(Amazon Linux 2023, `m8i.large`, Kiro CLI 3.1.0, 기본 `auto` 모델)에서 랩 리소스가 하나도 없는 계정 상태로 시작해 이 가이드를 처음부터 끝까지 두 번 실행해 측정한 값입니다. 두 번의 값이 다른 곳은 둘 다 적었습니다. 실제 수치는 조금씩 다릅니다. 명령을 어떻게 묶을지는 Kiro가 정하고, 그날의 첫 실행은 언제나 가장 느립니다.

랩 전체를 하나의 채팅 세션에서 진행하세요. 뒤쪽 프롬프트에는 "run it again"처럼 앞 대화를 전제로 한 표현이 있어서, Kiro가 "it"이 무엇인지 알려면 앞선 턴이 필요합니다.

## 시작하기 전에

### 리포지토리 클론

```bash
git clone https://github.com/hmkim/nextflow-aws-batch-lab.git
cd nextflow-aws-batch-lab
```

이후 모든 일은 이 디렉터리 안에서 일어납니다. Kiro는 여기서 리포지토리의 steering 파일을 읽고, Nextflow는 여기에 로그를 쓰고, 설정 스크립트는 여기에 `nextflow.config`를 생성합니다.

### AWS 자격 증명

Kiro는 참가자 머신의 셸에서 `aws`와 `nextflow`를 실행하므로 그 셸에 AWS 자격 증명이 있어야 합니다. 워크숍 IDE에서는 인스턴스 역할, 그 밖의 환경에서는 AWS CLI 프로파일입니다. Kiro를 열기 전에 확인합니다.

```bash
aws sts get-caller-identity --query Arn --output text
```

필요한 권한은 수동 랩과 같습니다(README의 [사전 요구 사항](README.ko.md#사전-요구-사항) 참조). IAM 역할을 만드는 설정 단계에는 관리자 수준 권한이 필요하고, 실행 단계에는 훨씬 적은 권한으로 충분합니다.

### Kiro 로그인

Kiro CLI: `kiro-cli whoami`가 로그인된 계정을 출력합니다. 출력되지 않으면 `kiro-cli login`을 실행합니다. 워크숍 IDE의 터미널에는 API 키가 이미 들어 있어 로그인 단계가 없습니다.

Kiro IDE: Kiro 패널의 계정 메뉴가 로그인된 계정을 보여 줍니다. 워크숍 IDE에서는 "Signed in with API Key"로 표시됩니다.

### AWS MCP 서버

랩의 명령은 셸에서 실행되므로 단계 진행 자체에는 MCP 서버가 필요하지 않습니다. 마지막의 "Kiro에게 물어볼 것" 섹션은 AWS 문서를 찾을 때 [AWS MCP Server](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/getting-started-aws-mcp-server.html)(`aws-mcp`)를 사용하므로, 연결되어 있는지 확인해 둡니다.

Kiro CLI: `kiro-cli mcp list`가 에이전트별로 로드하는 서버를 출력합니다. `kiro_default` 아래에 `aws-mcp`가 보여야 합니다. 채팅 안에서는 `/mcp`가 같은 목록을 연결 상태와 함께 보여 줍니다.

Kiro IDE: Kiro 패널의 MCP Servers 섹션에 `aws-mcp`가 연결됨으로 표시되어야 합니다.

워크숍 IDE에는 `aws-mcp`가 미리 구성되어 있습니다. 개인 머신에서는 `~/.kiro/settings/mcp.json`에 SigV4 프록시 방식으로 추가합니다. 이 프록시는 셸이 쓰는 것과 같은 AWS 자격 증명으로 요청에 서명합니다.

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

첫 연결은 프록시를 내려받느라 1분 정도 걸릴 수 있습니다.

### 리포지토리 열기와 워크스페이스 신뢰

이 리포지토리에는 `inclusion: always`로 설정된 steering 파일 `.kiro/steering/aws-batch-lab.md`가 들어 있습니다. 랩의 각 파일이 무슨 역할인지, 스택이 어떤 이름을 쓰는지, 그리고 절대 하지 말아야 할 일이 적혀 있습니다. CloudFormation 템플릿을 새로 쓰는 것, Nextflow 버전을 바꾸는 것, 스크립트를 고치는 것, `nohup`을 쓰는 것, 계정 ID나 자격 증명을 출력하는 것이 그 금지 목록입니다. Kiro는 이 파일을 대화의 모든 턴에 불러오므로 프롬프트마다 규칙을 반복할 필요가 없습니다.

Kiro는 워크스페이스를 신뢰한 뒤에만 이런 워크스페이스 파일을 불러옵니다.

Kiro CLI: 리포지토리 루트에서 채팅을 시작합니다. 한 폴더에서 처음 실행하면 Kiro가 "Trust this workspace?" 화면을 띄우고, 그 폴더가 담을 수 있는 훅, 에이전트, MCP 서버, steering을 알려 줍니다. **Trust**를 선택합니다. 결정은 리포지토리 밖에 저장되므로 이 화면은 폴더마다 한 번만 나옵니다.

```bash
cd nextflow-aws-batch-lab
kiro-cli chat
```

Kiro IDE: `nextflow-aws-batch-lab` 폴더를 엽니다(File, Open Folder). 워크스페이스 신뢰 안내가 뜨면 수락합니다. 그러면 Kiro 패널의 Steering 섹션에 `aws-batch-lab`이 나타납니다.

파일이 로드됐는지 확인하려면 채팅에 다음을 붙여 넣습니다.

```text
Which steering rules apply to this lab? List the "never do" rules in one line each, then stop.
```

Kiro는 아무것도 실행하지 않고 몇 초 안에 `aws-batch-lab.md`의 여덟 가지 규칙으로 답합니다. 스크립트 밖의 CloudFormation 금지, Batch 설정 수동 변경 금지, Nextflow 버전 변경 금지, 스크립트 수정 금지, `nohup` 대신 `nextflow -bg`, 출력에 계정 ID와 자격 증명 금지, 작업 버킷 삭제 금지, 스택의 리전 유지입니다. steering이 로드되지 않았다고 답하면 워크스페이스를 신뢰하지 않았거나 리포지토리 루트 밖에서 Kiro를 시작한 것입니다.

### 승인은 어떻게 동작하나

Kiro는 셸 명령을 실행하거나, 파일을 쓰거나 지우거나, 웹 페이지를 가져오거나, MCP 도구를 호출하기 전에 승인을 요청합니다. 리포지토리 안의 파일을 읽을 때는 요청하지 않습니다. 요청에는 정확한 명령과 네 가지 선택지가 표시됩니다. Kiro CLI에서는 **Allow once**, **Deny once**, **Create allow rule to approve future similar actions**, **Create deny rule to block future similar actions**이고, IDE 카드에서는 같은 네 가지가 Allow, Deny, Always allow, Always deny로 표시됩니다. allow 규칙을 만들면 패턴(정확한 명령, 또는 `nextflow *`처럼 넓은 패턴)과 범위를 고릅니다. "This session"은 채팅을 닫을 때까지 규칙을 유지하는 범위로, 랩에 알맞습니다.

Kiro는 보통 관련된 명령 여러 개를 셸 호출 하나로 묶어 실행합니다(`aws batch describe-job-queues ...; aws batch describe-compute-environments ...`). 호출 하나가 프롬프트 하나이므로, 한 단계의 프롬프트 수는 명령 수보다 적습니다. 이 가이드의 횟수는 측정 실행에서 Kiro가 수행한 셸 호출, 파일 쓰기, MCP·웹 호출의 수이며, 매번 **Allow once**를 선택했다고 가정한 값입니다. 첫 파이프라인 실행에서 `nextflow *`, 첫 AWS CLI 호출에서 `aws *`에 대해 allow 규칙을 만들면 이후 대부분의 단계는 프롬프트 없이 진행됩니다.

Kiro CLI는 터미널에 프롬프트를 띄우며, 화살표 키와 Enter로 선택합니다. Kiro IDE는 채팅의 카드로 보여 줍니다. IDE에서는 두 자율 모드(Autopilot, Supervised) 모두 기본 권한에서 셸 명령에 승인을 요구합니다. Autopilot은 저장된 규칙이 이미 허용한 작업에 대해서만 프롬프트를 건너뜁니다.

CLI에서 한 가지 더: 전경(foreground)에서 실행하는 셸 명령은 15분이 지나면 중단됩니다. 아래 모든 단계는 이 한도 안에 넉넉히 끝나며, 유일한 예외인 선택 과제 nf-core 실행은 그래서 `nextflow -bg`로 시작합니다.

## 1단계: 환경 설정

프롬프트:

```text
Run the lab setup script: `bash scripts/setup-nextflow-batch.sh` from the repository root, and show me its output. Do not modify the script or the CloudFormation template, and do not deploy anything by other means. When it finishes, check with `aws batch describe-job-queues` and `aws batch describe-compute-environments` that the job queue nextflow-batch-queue is ENABLED and VALID and that the compute environment is VALID with 0 desired vCPUs, then tell me the stack is ready.
```

워크숍 계정 밖에서는 같은 프롬프트에 작업 버킷 이름을 넣습니다. "Run the lab setup script with `WORK_BUCKET=my-nextflow-work-bucket bash scripts/setup-nextflow-batch.sh` ..."

Kiro가 실행한 것: `bash scripts/setup-nextflow-batch.sh`를 셸 호출 하나로 실행하고 CloudFormation 배포까지 스크립트 전체가 끝나기를 기다린 뒤, 두 개의 `aws batch describe-*` 명령을 자체 `--query` 필터를 붙여 두 번째 호출 하나로 묶어 실행했습니다. 파일은 읽지 않았습니다. 스크립트가 필요한 것을 모두 출력하기 때문입니다.

승인: 2회.

성공한 모습: 스크립트의 다섯 섹션이 `Setup complete`로 끝나고, Kiro가 큐는 `ENABLED`와 `VALID`, 컴퓨팅 환경 `nextflow-batch-ce-lt1`은 `VALID`에 desired vCPU 0(최소 0, 최대 16)이라고 보고합니다. 스크립트는 계정 ID를 한 번 출력하는데, Kiro는 steering 파일의 요구대로 요약에서 이를 가립니다. 측정값: Java와 Nextflow 설치, 스택 생성까지 포함해 두 번 모두 턴 전체 3분 34초. 나중에 바꿀 것이 없는 상태로 같은 프롬프트를 다시 실행했을 때는 19초.

스크립트가 중간에 멈추면(CloudFormation 쿼터 오류, 기본 VPC 없음 등) Kiro는 오류와 그 오류가 가리키는 줄을 보여 주고 멈춥니다. steering 파일이 스크립트 수정을 금지하기 때문입니다. 원인을 고친 뒤 같은 프롬프트를 다시 붙여 넣으세요. 스크립트는 멱등합니다.

## 2단계: 파이프라인 실행

프롬프트:

```text
Run the GreetingsNF pipeline on AWS Batch from the repository root: `nextflow run main.nf -profile batch --addressee 'AWS Batch' -with-trace trace-cold.txt`. Run it in the foreground and wait for it to finish; the first run takes 2 to 4 minutes because the compute environment has to start an EC2 instance. Then show me the final Nextflow summary (Duration, Succeeded) and the content of /mnt/workflow/pubdir/output.
```

Kiro가 실행한 것: 적힌 그대로의 `nextflow run` 명령을 전경에서 실행한 뒤 `cat /mnt/workflow/pubdir/output`. 채팅에 터미널이 붙어 있지 않으면 Kiro가 `-ansi-log false`를 덧붙입니다. 그러면 Nextflow가 마지막 요약 블록을 출력하지 않으므로 Kiro는 `.nextflow.log`와 `trace-cold.txt`에서 Duration을 읽어 옵니다. 실행이 인스턴스를 기다리는 약 2분 동안은 아무 일도 없는 것처럼 보입니다. 수동 랩이 설명하는 것과 같은, 컴퓨팅 환경이 0에서 확장되는 대기입니다. 그동안 [AWS Batch 콘솔](https://console.aws.amazon.com/batch/home#jobs)에서 작업이 `RUNNABLE`, `STARTING`, `RUNNING`으로 넘어가는 것을 볼 수 있습니다.

승인: 3회.

성공한 모습: `Greet` 태스크가 종료 코드 0으로 끝나고, 로그에 `succeededCount=1`, Duration은 2~4분, 출력 파일 내용은 `hello AWS Batch`입니다. 측정값: 턴 전체 3분 00초와 2분 40초. 태스크는 제출부터 완료까지 2분 29초와 1분 59초가 걸렸고, 그중 140초와 112초는 작업이 `RUNNABLE` 상태로 인스턴스를 기다린 시간, 약 6초는 컨테이너가 실행된 시간입니다.

### 결과 확인

프롬프트:

```text
Explain the run that just finished, using nextflow.config, .nextflow.log and trace-cold.txt: which job queue and container image the Greet task used, how long the job waited between submission and start, and why that gap exists. Then list the work directory with `aws s3 ls --recursive` on the workDir path from nextflow.config, and run `aws batch describe-job-definitions --status ACTIVE`. Explain what Nextflow registered in AWS Batch on my behalf.
```

Kiro가 실행한 것: 파일 도구로 `nextflow.config`를 읽은 뒤, `.nextflow.log`에 `grep`과 `cat trace-cold.txt`를 셸 호출 하나로 실행했습니다. 이어서 트레이스의 작업 ID로 `aws batch describe-jobs`를 실행해 정확한 `createdAt`과 `startedAt` 타임스탬프를 얻고, `aws s3 ls --recursive s3://<work bucket>/nextflow-batch/work`와 `aws batch describe-job-definitions --status ACTIVE`를 실행했습니다.

승인: 4~5회.

성공한 모습: Kiro가 큐 `nextflow-batch-queue`와 이미지 `public.ecr.aws/docker/library/ubuntu:22.04`를 짚어 내고, 제출과 시작 사이의 대기(측정 실행에서 140초와 112초)를 컴퓨팅 환경이 0에서 인스턴스를 띄우고 이미지를 받는 시간으로 설명합니다. S3 목록에는 제출 시점에 올라간 `.command.run`과 `.command.sh`, 그리고 약 2분 뒤의 `.command.begin`이 보입니다. 작업 정의 목록에는 항목 하나, `nf-public-ecr-aws-docker-library-ubuntu-22-04`가 있고, 1 vCPU와 1024 MiB의 자리표시 요청, `/opt/aws-cli` 마운트, `nf-token` 파라미터가 들어 있습니다. Kiro는 Nextflow가 프로필의 컨테이너 이미지로 이 정의를 만들었고 매 실행에서 재사용한다고 설명합니다. 측정값: 28초와 31초.

### 다시 실행

프롬프트:

```text
Run the same pipeline again with `--addressee 'warm run' -with-trace trace-warm.txt`, in the foreground, and compare its Duration with the first run. Explain where the difference comes from.
```

Kiro가 실행한 것: `nextflow run main.nf -profile batch --addressee 'warm run' -with-trace trace-warm.txt`, 그리고 `trace-warm.txt`와 출력 파일을 읽고 두 작업 모두에 `aws batch describe-jobs`를 실행해 제출-시작 대기 시간을 나란히 놓는 호출 하나.

승인: 2~4회.

성공한 모습: 앞선 2~4분에 비해 1분이 훨씬 안 되는 Duration이 나오고, Kiro는 첫 실행의 인스턴스가 아직 컴퓨팅 환경에 등록된 채 남아 있어서 이미지가 이미 있는 호스트에서 작업이 몇 초 안에 시작됐다고 설명합니다. 측정값: 턴 전체 51초와 64초. 태스크는 두 번 모두 19초, 대기는 6~7초. 첫 실행 뒤 몇 분 이상 지났다면 Batch가 인스턴스를 이미 종료해 두 번째 실행도 콜드가 될 수 있습니다. Duration이 길게 나오면 Kiro가 그 점을 말해 주어야 합니다.

### 파이프라인을 건드리지 않고 자원 요청 바꾸기

프롬프트:

```text
Without editing main.nf or nextflow.config, create a file named resources.config that sets cpus = 4 and memory = '8 GB' for the Greet process only, using process { withName: 'Greet' { ... } }. Then run `nextflow run main.nf -profile batch -c resources.config --addressee 'bigger' -with-trace trace-bigger.txt` in the foreground. When it finishes, find the newest SUCCEEDED job in nextflow-batch-queue with `aws batch list-jobs`, run `aws batch describe-jobs` on it, and tell me the vCPU and memory values Batch received, the job definition revision it used, and the EC2 instance type Batch chose for it.
```

Kiro가 실행한 것: `resources.config`를 썼고(파일 쓰기, 승인 요청), 파이프라인을 실행했습니다. 이어서 `aws batch list-jobs --job-queue nextflow-batch-queue --job-status SUCCEEDED`를 생성 시각으로 정렬해 실행하고, 가장 새 ID에 `aws batch describe-jobs`를 실행했습니다. 인스턴스 유형을 찾기 위해 작업의 컨테이너 인스턴스를 `aws ecs describe-container-instances`와 `aws ec2 describe-instances`로 따라갔습니다.

승인: 5~7회(파일 쓰기 1회와 셸 호출 4~6회. 더 길었던 실행의 추가 호출은 트레이스 파일이 아직 없는지 확인하는 호출과 형식 실수 뒤의 재시도였습니다).

성공한 모습: `describe-jobs`가 처음 두 실행과 같은 작업 정의 리비전(새 계정에서는 리비전 1)에서 `4 VCPU`와 `8192 MEMORY`의 `resourceRequirements`를 보여 주고, 인스턴스 유형은 첫 실행보다 큽니다. Batch는 대기 중인 작업에 맞는 가장 저렴한 인스턴스를 고르므로 유형은 달라집니다. 측정 실행에서는 `r6i.xlarge`와 `m6i.xlarge`였습니다. Kiro는 `main.nf`도 작업 정의도 바뀌지 않았고, 크기 지정이 작업별 override로 전달됐다는 점을 짚어야 합니다. 측정값: 턴 전체 3분 07초와 3분 16초. Batch가 더 큰 인스턴스를 새로 띄워야 했기 때문에 태스크는 2분 19초와 2분 29초가 걸렸습니다.

## 비용 측정

프롬프트:

```text
Estimate what the three runs cost with the lab's script: run `uv run --with boto3 scripts/run-cost.py <trace file>` for trace-cold.txt, trace-warm.txt and trace-bigger.txt. Do not modify the script. Explain the difference between the attributed and incurred totals, and what the utilisation percentage means for a one-task pipeline.
```

Kiro가 실행한 것: 세 트레이스 파일에 대해 `uv run --with boto3 scripts/run-cost.py <trace>`를 호출하는 셸 루프 하나. 첫 호출은 `boto3`를 캐시 환경에 내려받느라 몇 초가 더 걸립니다.

승인: 1회.

성공한 모습: 작은 표 세 개. 각각 약 6초 실행된 `Greet` 태스크 하나, 1센트의 몇 분의 일인 귀속(attributed) 비용, 인스턴스 수명 전체에 대한 1센트 미만의 발생(incurred) 비용, 많아야 몇 퍼센트인 사용률을 보여 줍니다. 두 번 모두 콜드 런과 웜 런이 `c6i.large` 하나를 공유했고(발생 비용 약 $0.0055, 같은 인스턴스라서 두 보고서에 모두 나타남) bigger 런은 자기만의 더 큰 인스턴스를 썼습니다. 사용률은 한 번은 1%, 1%, 5%, 다른 한 번은 1%, 1%, 12%였는데, 후자는 bigger 런의 인스턴스가 아직 실행 중이어서 스크립트가 그 span에 `+`를 표시한 경우입니다. Kiro는 귀속 비용이 태스크가 실행된 몇 초 동안 예약한 인스턴스 몫이고, 발생 비용이 인스턴스 시작부터 종료까지 EC2가 청구한 금액이며, 0으로 축소되는 환경에서 태스크 하나짜리 파이프라인은 거의 전부를 시작과 유휴 시간에 지불한다고 설명합니다. 이 단계는 실행 후 1시간 안에 하세요. 그 뒤에는 인스턴스가 EC2와 ECS API에서 사라져 스크립트가 대체 단가로 물러나며, 그런 행은 `*`로 표시됩니다. 측정값: 22초와 32초.

Cost and Usage Report의 정확한 수치는 README의 [비용 측정](README.ko.md#비용-측정)에 설명되어 있습니다. 본인 계정의 결제 콘솔이 필요하고 하루 뒤에 도착하므로 세션 범위 밖입니다.

## 정리

프롬프트:

```text
Clean up the lab: run `aws cloudformation delete-stack --stack-name nextflow-batch`, remove the objects under the nextflow-batch/ prefix of the work bucket named in nextflow.config (only that prefix, not the bucket), then wait with `aws cloudformation wait stack-delete-complete --stack-name nextflow-batch` and confirm the stack is gone. Do not delete anything else.
```

Kiro가 실행한 것: `aws cloudformation delete-stack`, `aws s3 rm --recursive s3://<work bucket>/nextflow-batch/`, `aws cloudformation wait stack-delete-complete`, 그리고 리소스가 사라졌음을 보이기 위한 마지막 `describe-stacks`와 `describe-job-queues`. 컴퓨팅 환경을 삭제하면 남은 인스턴스가 종료되므로 대기에 몇 분이 걸립니다.

승인: 4회.

성공한 모습: 접두사 목록이 객체 0개를 보여 주고, 대기가 오류 없이 돌아오고, `describe-stacks`가 스택이 존재하지 않는다고 답합니다. Nextflow가 등록한 작업 정의는 남습니다. 비용은 들지 않으며, 등록 해제 방법은 README에 있습니다. Mountpoint 섹션을 진행했다면 버킷에 `reference/sample.gff3`도 남습니다. 버킷을 원래대로 돌리고 싶으면 Kiro에게 삭제를 요청하세요. 측정값: 2분 59초와 3분 17초.

나중에 랩으로 돌아올 예정이면 이 단계를 건너뛰세요. 컴퓨팅 환경이 0 vCPU인 동안 스택은 비용이 들지 않고, 유일하게 이어지는 비용은 S3 작업 디렉터리입니다.

## 선택: Mountpoint for Amazon S3로 참조 데이터 스트리밍

README의 [Mountpoint 섹션](README.ko.md#더-나아가기-mountpoint-for-amazon-s3로-참조-데이터-스트리밍)을 따릅니다. 마운트 플래그로 설정을 다시 실행하면 컴퓨팅 환경이 교체되므로, 본 단계들을 끝낸 뒤 정리 전에 진행하세요. `<bucket>`은 참조 데이터가 있는 버킷으로 바꿉니다. 연습에는 작업 버킷 자체를 써도 됩니다.

프롬프트:

```text
Switch the lab to the Mountpoint for Amazon S3 mode: re-run the setup script as `DATA_BUCKET=<bucket> MOUNT_DATA_BUCKET=true bash scripts/setup-nextflow-batch.sh` and show me the Mountpoint line it prints. Then create a small GFF3 test file named sample.gff3 with two comment lines and three feature lines, upload it to s3://<bucket>/reference/sample.gff3, and run `nextflow run pipeline/ref-check.nf -profile batch -with-trace trace-mount.txt` in the foreground. Show me what REF_SUMMARY printed, and explain why ref-check.nf passes the mounted directory as a val input instead of a path input.
```

Kiro가 실행한 것: `pipeline/ref-check.nf`를 읽고, 두 변수를 붙여 설정 스크립트를 실행하고(CloudFormation이 컴퓨팅 환경을 교체하는 데 약 2분), `printf`로 `sample.gff3`를 쓰고 `aws s3 cp`로 올리는 일을 호출 하나로 처리하고, 파이프라인을 실행했습니다. 그런 다음 `ref-check.nf`가 프로세스 출력을 콘솔에 보여 주지 않기 때문에, 태스크의 S3 작업 디렉터리에서 `.command.out`과 `summary.txt`를 `aws s3 cp ... -`로 가져왔습니다. 새 컴퓨팅 환경이 0에서 시작하므로 이 실행도 다시 콜드입니다.

승인: 4회.

성공한 모습: 스크립트가 `Mountpoint  : s3://<bucket> -> /mnt/s3-ref (on compute instances)`를 출력하고, `nextflow.config`에 `volumes = '/mnt/s3-ref:/mnt/s3-ref:ro'` 줄이 생기고, 태스크 출력에 `mount: 1 mountpoint-s3 filesystem(s) visible`, `reference/` 목록, `features: 3`이 나타납니다. Kiro는 `path` 입력이었다면 헤드 노드가 컴퓨팅 인스턴스에서만 보이는 파일을 스테이징하려 들었을 것이라고 설명합니다. 측정값: 턴 전체 5분 33초와 7분 04초, 태스크 2분 29초와 3분 29초.

## 선택: nf-core/sarek test 프로파일 실행

GreetingsNF는 동작 원리를 보여 주고, 실제 파이프라인은 스케줄링을 보여 줍니다. README의 [nf-core 섹션](README.ko.md#선택-실제-nf-core-파이프라인-실행)은 nf-core/rnaseq와 nf-core/sarek을 각자의 test 프로파일로 실행합니다. Kiro에게 맡길 것은 sarek test(태스크 23개, 랩의 16 vCPU 컴퓨팅 환경에서 10~15분)입니다. 백그라운드로 시작하고 읽는 동안 진행 상황을 물어보세요. 전경으로 실행하면 CLI의 15분 명령 한도에 걸릴 수 있습니다.

프롬프트:

```text
Run the nf-core/sarek test profile on the Batch environment in the background, using the work bucket from nextflow.config: `nextflow -bg run nf-core/sarek -r 3.5.1 -profile test,batch --outdir s3://<work bucket>/nextflow-batch/sarek-test -with-trace trace-sarek.txt -ansi-log false > sarek.log 2>&1`. Do not use nohup. Confirm it started by showing the first lines of sarek.log, then stop; I will ask you for progress myself.
```

Kiro가 실행한 것: `nextflow.config`에서 버킷 이름을 채운 `nextflow -bg run ...` 명령, 20초 대기, `head sarek.log`를 셸 호출 하나로.

승인: 1회.

그 뒤 진행 상황이 궁금할 때마다:

```text
How is the sarek run going? Count the submitted and completed processes in .nextflow.log, show the last ten lines of sarek.log, and tell me whether it has finished.
```

Kiro는 로그에 `grep -c`, `sarek.log`에 `tail`, Nextflow 프로세스에 `pgrep`을 셸 호출 1~3회로 실행합니다(15~35초). 두 개수가 모두 23이 되고 `.nextflow.log`에 `Workflow completed`가 있고 `sarek.log`가 `Pipeline completed successfully`로 끝나면 실행이 끝난 것입니다. 그동안 Batch 콘솔의 Environments 페이지를 보세요. 컴퓨팅 환경이 16 vCPU까지 올라갔다가 마지막 태스크 뒤에 0으로 돌아옵니다. 측정 실행은 13분과 10분이 걸렸습니다.

끝났으면:

```text
The sarek run has finished. Run `uv run --with boto3 scripts/run-cost.py trace-sarek.txt` and tell me which processes cost the most, how long the tasks waited in total, and how much of the instance time was idle.
```

승인: 1회.

성공한 모습: 몇 대의 인스턴스에 걸친 태스크 23개의 표, 6~7센트의 발생 비용 합계, 20% 안팎의 사용률. 한 번은 인스턴스 여섯 대(`c6i.2xlarge` 두 대, `c6i.large` 한 대, `m6i.xlarge` 두 대, `r6i.xlarge` 한 대)를 써서 귀속 $0.0125 대 발생 $0.0595, 사용률 21%였고, 다른 한 번은 `c6i.2xlarge` 두 대로 $0.0126 대 $0.0675, 19%였습니다. Batch가 인스턴스를 몇 대 띄우는지는 첫 태스크들이 어떻게 겹치는지에 따라 달라집니다. Kiro는 첫 인스턴스를 2~3분 기다린 첫 태스크들(`FASTQC`와 interval 준비)을 짚어야 합니다. 측정값: 16초와 25초. 끝난 뒤 출력은 `aws s3 rm --recursive s3://<work bucket>/nextflow-batch/sarek-test/`로 정리하거나(Kiro에게 요청, 승인 1회), `nextflow-batch/` 접두사 전체를 지우는 정리 단계에 맡겨 두세요.

## Kiro에게 물어볼 것

실행이 끝나면 `nextflow.config`, `.nextflow.log`, 트레이스 파일이 남고, Kiro는 `aws-mcp`와(워크숍 IDE에서는) 자체 웹 검색·가져오기 도구로 AWS 문서를 볼 수 있습니다. 아래 프롬프트는 그것을 토론으로 바꿉니다. 어느 것도 AWS에서 무언가를 바꾸지 않습니다. 측정 실행에서 각각 25~80초가 걸렸습니다.

트레이스 읽기(호출 1~5회. Kiro는 트레이스를 표로 만드는 짧은 Python 스크립트를 쓰는데, 임시 파일로 만들었다가 뒤에 지우기도 하고, 태스크와 인스턴스를 짝지으려 `aws batch describe-jobs`를 부를 수도 있습니다):

```text
Read trace-sarek.txt (or trace-cold.txt and trace-warm.txt if sarek did not run). For each task, compare duration (submission to completion) with realtime (how long the script ran). Which tasks waited longest, and what does the pattern tell me about how AWS Batch scaled the compute environment during the run?
```

좋은 답은 태스크를 파도(wave)로 묶습니다. 첫 다섯 태스크는 첫 인스턴스를 약 2분 기다렸습니다. 그 인스턴스가 떠 있는 동안 제출된 태스크는 15~45초 만에 시작했습니다. 파이프라인이 실행 중인 용량 이상으로 퍼져 Batch가 인스턴스를 더 띄울 때 2분 대기의 두 번째 파도가 나타났습니다.

HealthOmics와 나란히 비교(승인 5~7회: `aws-mcp` 문서 검색 4~6회에 셸 호출 또는 웹 검색 1회. `aws-mcp`에 allow 규칙을 만들면 1~2회):

```text
Compare what we just did on AWS Batch with running the same main.nf on AWS HealthOmics. List what I had to create here that HealthOmics manages for me, what Batch lets me control that HealthOmics does not, and when I would choose each. Use the AWS documentation through the aws-mcp server and the comparison table in README.md, and say which statements come from which source.
```

좋은 답은 각 문장에 출처를 붙입니다. 이 세션, README 표, AWS 문서 중 어디서 왔는지입니다. 또 README의 요약과 현재 문서가 다른 지점도 짚어 줍니다. 예를 들어 HealthOmics가 받아들이는 컨테이너 레지스트리, 지원하는 Nextflow 버전 같은 것입니다.

비용(도구 없음. Kiro는 대화에 이미 있는 `run-cost.py` 출력으로 답합니다):

```text
Using the run-cost.py output from this session, explain why the attributed cost is so far below the incurred cost. Then estimate the monthly cost of keeping MinvCpus=2 on the compute environment so runs start warm, compared with scaling to zero, using the On-Demand price of the smallest instance Batch used here. Show the arithmetic and the assumptions.
```

좋은 답은 `c6i.large` 온디맨드 단가에 730시간을 곱해(월 약 $62) 실행들의 발생 비용과 대비합니다. 가정도 밝힙니다. `MinvCpus=2`가 `c6i.large` 정확히 한 대를 유지한다는 것, EBS와 S3는 제외했다는 것, 단가는 스크립트의 조회 값이라는 것입니다.

운영 환경 변경(승인 4~6회: `aws-mcp` 검색과, 한 번의 실행에서는 Nextflow 설정 레퍼런스 웹 가져오기):

```text
What would I change in nextflow.config and in cfn/batch-nextflow.yaml to run this on Spot Instances with retries for Spot interruptions? Show the changes as text and do not apply them.
```

이 프롬프트는 steering이 수정을 금지한 파일의 변경 내용을 보여 달라고 요청합니다. Kiro는 diff를 텍스트로 답하고 아무것도 적용하지 않았다고 말해야 합니다. 적용을 제안하면 거절하세요. 좋은 답은 `SPOT_PRICE_CAPACITY_OPTIMIZED`와 함께하는 `Type: SPOT`(또는 큐에서 온디맨드 환경보다 앞에 두는 두 번째 스팟 컴퓨팅 환경), `aws.batch.maxSpotAttempts`, 중단된 태스크를 재시도하는 `errorStrategy`를 다룹니다. README의 운영 환경 메모와 같은 내용입니다. 두 번째 실행에서 Kiro는 CloudFormation 레퍼런스까지 읽고, 기존 환경을 `EC2`에서 `SPOT`으로 바꾸는 것은 교체가 아니라 제자리 업데이트라는 점도 짚었습니다.

## Kiro가 다른 행동을 할 때

Kiro가 설정 스크립트를 다시 쓰거나 CloudFormation을 직접 배포하자고 제안합니다. 명령을 거절하고 이렇게 일깨우세요. "Follow the steering file: run the script as is." 보통 워크스페이스를 신뢰하지 않아 steering 파일이 로드되지 않았을 때 생기는 일입니다. "리포지토리 열기와 워크스페이스 신뢰"의 steering 확인 프롬프트로 점검하세요.

Kiro가 `nohup ... &`로 `nextflow`를 실행합니다. 거절하세요. steering 파일은 실행을 떼어 놓는 유일한 방법으로 `nextflow -bg`를 지정하고 있으니, 그것을 쓰라고 요청하세요.

명령이 실패했는데 Kiro가 고치지 않고 진단만 하고 멈춥니다. steering 파일이 작동하는 것입니다. 이 가이드를 쓰는 동안 콜드 런 하나가 시작 템플릿의 부트스트랩 버그로 실패한 적이 있습니다(이후 수정됨). Kiro는 인스턴스의 콘솔 출력을 읽고, 템플릿의 문제 줄과 README 문제 해결 표의 해당 행을 인용한 뒤 멈췄습니다. 참가자 계정에서 동작하는 에이전트에게 바라는 바로 그 행동입니다. 진단을 읽고 원인을 고치거나 보고한 뒤, 그 단계의 프롬프트를 다시 붙여 넣으세요.

Nextflow가 `Trace file already exists`로 시작을 거부합니다. 같은 단계의 앞선 시도가 트레이스 파일을 남긴 것입니다. Kiro에게 "Delete the old trace file and run the same command again."이라고 말하세요. 테스트 중 이 상황이 생겼을 때 Kiro는 파일을 스스로 지우지 않고 멈춰서 어느 방법을 원하는지 물었습니다.

`nextflow run` 명령이 몇 분째 멈춘 것처럼 보입니다. 콜드 컴퓨팅 환경에서는 2~3분의 침묵이 정상입니다. 10분이 지나면 Kiro에게 `RUNNABLE` 상태의 작업에 `aws batch describe-jobs`를 실행하고 컴퓨팅 환경의 상태 이유를 읽어 달라고 요청하세요. README의 [문제 해결](README.ko.md#문제-해결) 표에 흔한 원인이 정리되어 있습니다.

Kiro가 `.nextflow.log`나 트레이스 파일을 읽을 수 없다고 답합니다. 채팅을 리포지토리 루트에서 시작하지 않은 것입니다. 올바른 폴더에서 새 채팅을 시작하고 진행하던 단계부터 이어 가세요. 파일과 AWS 리소스는 그대로 있습니다.
