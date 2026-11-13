# 用 Kiro 跟著做這個實作

[README](README.zh-TW.md) 是在終端機裡自己輸入指令來完成這個實作。本指南用 Kiro 完成同一個實作:每一步把一個提示詞貼進 Kiro CLI 或 Kiro IDE 的聊天視窗,Kiro 執行實作的指令碼和指令,你讀它的報告。建立的 AWS 資源、管線和結果完全相同,不同的是誰在打指令、誰在解釋輸出。

[English guide](KIRO.md) · [한국어 가이드](KIRO.ko.md)

下面每一步都有四個部分:要貼上的提示詞、Kiro 依提示詞實際執行的指令、你會看到的核准提示次數,以及成功時的樣子。耗時和核准次數是 2026-11-10 在工作坊 IDE(Amazon Linux 2023、`m8i.large`、Kiro CLI 3.1.0、預設 `auto` 模型)上,從一個完全沒有實作資源的帳戶開始,把本指南從頭到尾跑兩遍量到的。兩次數值不同的地方兩個都寫。你的數字會稍有差異:指令怎麼組合由 Kiro 決定,而當天的第一次執行永遠最慢。目前的工作坊 IDE 完全不會出現核准提示,請見[核准如何運作](#核准如何運作)。

整個實作請在同一個聊天 session 裡進行。後面的提示詞有「run it again」這類以前文為前提的說法,Kiro 需要前面的回合才知道「it」是什麼。

## 開始之前

### 複製儲存庫

```bash
git clone https://github.com/hmkim/nextflow-aws-batch-lab.git
cd nextflow-aws-batch-lab
```

之後的一切都在這個目錄裡發生。Kiro 在這裡讀儲存庫的 steering 檔案,Nextflow 在這裡寫日誌,設定指令碼在這裡產生 `nextflow.config`。

### AWS 憑證

Kiro 在你機器的 shell 裡執行 `aws` 和 `nextflow`,所以那個 shell 需要 AWS 憑證:工作坊 IDE 上是執行個體角色,其他環境則是 AWS CLI 設定檔。打開 Kiro 之前先確認。

```bash
aws sts get-caller-identity --query Arn --output text
```

需要的權限和手動實作相同(見 README 的[事前準備](README.zh-TW.md#事前準備)):建立 IAM 角色的設定步驟需要管理員等級權限,執行步驟需要的權限少得多。

### 登入 Kiro

Kiro CLI:`kiro-cli whoami` 會印出已登入的帳戶。沒有輸出就執行 `kiro-cli login`。工作坊 IDE 的終端機已內建 API 金鑰,沒有登入步驟。

Kiro IDE:Kiro 面板的帳戶選單會顯示已登入的帳戶。工作坊 IDE 上顯示為「Signed in with API Key」。

### AWS MCP 伺服器

實作的指令在 shell 執行,所以步驟本身不需要 MCP 伺服器。最後的「可以問 Kiro 的問題」一節用 [AWS MCP Server](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/getting-started-aws-mcp-server.html)(`aws-mcp`)查 AWS 文件,請先確認它已連線。

Kiro CLI:`kiro-cli mcp list` 會依 agent 列出載入的伺服器,`kiro_default` 下面應該有 `aws-mcp`。在聊天中,`/mcp` 顯示同一份清單並附連線狀態。

Kiro IDE:Kiro 面板的 MCP Servers 區段應顯示 `aws-mcp` 已連線。

工作坊 IDE 已預先設定 `aws-mcp`。個人機器上,以 SigV4 proxy 方式加進 `~/.kiro/settings/mcp.json`;這個 proxy 用 shell 所用的同一組 AWS 憑證替請求簽章。

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

第一次連線要下載 proxy,可能需要 1 分鐘左右。

### 打開儲存庫並信任工作區

這個儲存庫含有一個設為 `inclusion: always` 的 steering 檔案 `.kiro/steering/aws-batch-lab.md`。裡面寫著實作的每個檔案做什麼、堆疊用什麼名稱,以及絕對不能做的事:重寫 CloudFormation 範本、更換 Nextflow 版本、修改指令碼、使用 `nohup`、印出帳戶 ID 或憑證。Kiro 在對話的每一回合都會載入這個檔案,所以不必在每個提示詞重複規則。

Kiro 只在你信任工作區之後才載入這類工作區檔案。

Kiro CLI:在儲存庫根目錄啟動聊天。第一次在某個資料夾執行時,Kiro 會顯示「Trust this workspace?」畫面,並說明該資料夾可能含有的 hook、agent、MCP 伺服器和 steering。選擇 **Trust**。這個決定存放在儲存庫之外,所以每個資料夾只會問一次。

```bash
cd nextflow-aws-batch-lab
kiro-cli chat
```

Kiro IDE:打開 `nextflow-aws-batch-lab` 資料夾(File、Open Folder)。出現工作區信任提示時接受。接著 Kiro 面板的 Steering 區段會出現 `aws-batch-lab`。

要確認檔案已載入,在聊天中貼上:

```text
Which steering rules apply to this lab? List the "never do" rules in one line each, then stop.
```

Kiro 不執行任何東西,幾秒內就以 `aws-batch-lab.md` 的八條規則回答:不在指令碼之外使用 CloudFormation、不手動變更 Batch 設定、不更換 Nextflow 版本、不修改指令碼、用 `nextflow -bg` 取代 `nohup`、輸出中不含帳戶 ID 和憑證、不刪除工作儲存貯體、保持堆疊的區域。如果它回答 steering 沒有載入,表示你沒有信任工作區,或是在儲存庫根目錄之外啟動了 Kiro。

### 核准如何運作

先說例外:工作坊 IDE。Workshop Studio 執行個體(Kiro IDE Browser 範本 1.1.0 以上)含有一個預先核准所有工具的 Kiro 權限檔案 `~/.kiro/settings/permissions.yaml`(`capability: all`)。那台執行個體上的 Kiro CLI 和 Kiro IDE 執行本指南的指令時不會出現任何提示(2026-11-11 以 Kiro CLI 3.2.0 確認)。下面的核准次數在那裡請當作 Kiro 執行的工具呼叫次數來讀。其他內容在工作坊 IDE 上都一樣。本節其餘部分以預設設定的個人電腦為準。

Kiro 在執行 shell 指令、寫入或刪除檔案、抓取網頁或呼叫 MCP 工具之前會要求核准;讀取儲存庫內的檔案不會。要求會顯示確切的指令和四個選項。Kiro CLI 上是 **Allow once**、**Deny once**、**Create allow rule to approve future similar actions**、**Create deny rule to block future similar actions**;IDE 的卡片上同樣四個顯示為 Allow、Deny、Always allow、Always deny。建立 allow 規則時要選模式(確切指令,或像 `nextflow *` 這樣較寬的模式)和範圍。「This session」是在關閉聊天前保留規則的範圍,很適合這個實作。

Kiro 通常會把幾個相關指令合成一次 shell 呼叫執行(`aws batch describe-job-queues ...; aws batch describe-compute-environments ...`)。一次呼叫就是一次提示,所以一個步驟的提示次數少於指令數。本指南的次數是量測執行中 Kiro 執行的 shell 呼叫、檔案寫入、MCP 與網頁呼叫的數量,並假設每次都選 **Allow once**。如果在第一次管線執行時替 `nextflow *`、第一次 AWS CLI 呼叫時替 `aws *` 建立 allow 規則,之後大部分步驟都不會再有提示。

Kiro CLI 在終端機顯示提示,用方向鍵和 Enter 選擇。Kiro IDE 以聊天中的卡片顯示。IDE 的兩種自主模式(Autopilot、Supervised)在預設權限下都會對 shell 指令要求核准;Autopilot 只對已儲存規則允許的動作跳過提示。

CLI 還有一點:前景執行的 shell 指令超過 15 分鐘會被中斷。下面所有步驟都遠在這個上限之內,唯一的例外是選用的 nf-core 執行,因此它用 `nextflow -bg` 啟動。

## 步驟 1:設定環境

提示詞:

```text
Run the lab setup script: `bash scripts/setup-nextflow-batch.sh` from the repository root, and show me its output. Do not modify the script or the CloudFormation template, and do not deploy anything by other means. When it finishes, check with `aws batch describe-job-queues` and `aws batch describe-compute-environments` that the job queue nextflow-batch-queue is ENABLED and VALID and that the compute environment is VALID with 0 desired vCPUs, then tell me the stack is ready.
```

在工作坊帳戶之外,同一個提示詞加上工作儲存貯體名稱:「Run the lab setup script with `WORK_BUCKET=my-nextflow-work-bucket bash scripts/setup-nextflow-batch.sh` ...」

Kiro 執行了什麼:以一次 shell 呼叫執行 `bash scripts/setup-nextflow-batch.sh`,等整個指令碼連 CloudFormation 部署一起結束,再把兩個 `aws batch describe-*` 指令加上自己的 `--query` 過濾器,合成第二次呼叫執行。沒有讀任何檔案,因為指令碼已經印出所需的一切。

核准:2 次。

成功的樣子:指令碼的五個區段以 `Setup complete` 結束,Kiro 報告佇列為 `ENABLED` 和 `VALID`,運算環境 `nextflow-batch-ce-lt1` 為 `VALID`,desired vCPU 為 0(最小 0、最大 16)。指令碼會印一次帳戶 ID,Kiro 依 steering 檔案的要求在摘要中遮掉它。量測值:含 Java 和 Nextflow 安裝與堆疊建立,兩次整回合都是 3 分 34 秒。之後在沒有任何變更的狀態下重跑同一個提示詞是 19 秒。

如果指令碼中途停下(CloudFormation 配額錯誤、沒有預設 VPC 等),Kiro 會顯示錯誤和它指向的那一行,然後停住,因為 steering 檔案禁止修改指令碼。修正原因後再貼一次同一個提示詞;指令碼是冪等的。

## 步驟 2:執行管線

提示詞:

```text
Run the GreetingsNF pipeline on AWS Batch from the repository root: `nextflow run main.nf -profile batch --addressee 'AWS Batch' -with-trace trace-cold.txt`. Run it in the foreground and wait for it to finish; the first run takes 2 to 4 minutes because the compute environment has to start an EC2 instance. Then show me the final Nextflow summary (Duration, Succeeded) and the content of /mnt/workflow/pubdir/output.
```

Kiro 執行了什麼:照寫的 `nextflow run` 指令在前景執行,然後 `cat /mnt/workflow/pubdir/output`。聊天沒有附帶終端機時,Kiro 會加上 `-ansi-log false`;這樣 Nextflow 不會印最後的摘要區塊,Kiro 便改從 `.nextflow.log` 和 `trace-cold.txt` 讀 Duration。執行等待執行個體的大約 2 分鐘裡看起來什麼都沒發生,這就是手動實作描述的、運算環境從 0 開始擴展的等待。這段時間可以在 [AWS Batch 主控台](https://console.aws.amazon.com/batch/home#jobs)看工作從 `RUNNABLE`、`STARTING` 進到 `RUNNING`。

核准:3 次。

成功的樣子:`Greet` 任務以結束碼 0 完成,日誌有 `succeededCount=1`,Duration 2~4 分鐘,輸出檔案內容是 `hello AWS Batch`。量測值:整回合 3 分 00 秒和 2 分 40 秒。任務從提交到完成花了 2 分 29 秒和 1 分 59 秒,其中 140 秒和 112 秒是工作停在 `RUNNABLE` 等執行個體,約 6 秒是容器執行時間。

### 確認結果

提示詞:

```text
Explain the run that just finished, using nextflow.config, .nextflow.log and trace-cold.txt: which job queue and container image the Greet task used, how long the job waited between submission and start, and why that gap exists. Then list the work directory with `aws s3 ls --recursive` on the workDir path from nextflow.config, and run `aws batch describe-job-definitions --status ACTIVE`. Explain what Nextflow registered in AWS Batch on my behalf.
```

Kiro 執行了什麼:用檔案工具讀 `nextflow.config`,然後以一次 shell 呼叫對 `.nextflow.log` 執行 `grep` 和 `cat trace-cold.txt`。接著用 trace 中的工作 ID 執行 `aws batch describe-jobs` 取得精確的 `createdAt` 和 `startedAt` 時間戳,再執行 `aws s3 ls --recursive s3://<work bucket>/nextflow-batch/work` 和 `aws batch describe-job-definitions --status ACTIVE`。

核准:4~5 次。

成功的樣子:Kiro 指出佇列 `nextflow-batch-queue` 和映像 `public.ecr.aws/docker/library/ubuntu:22.04`,並把提交與開始之間的等待(量測執行中為 140 秒和 112 秒)解釋為運算環境從 0 啟動執行個體並拉取映像的時間。S3 清單顯示提交時上傳的 `.command.run` 和 `.command.sh`,以及約 2 分鐘後的 `.command.begin`。工作定義清單只有一項 `nf-public-ecr-aws-docker-library-ubuntu-22-04`,含 1 vCPU 與 1024 MiB 的預留請求、`/opt/aws-cli` 掛載和 `nf-token` 參數。Kiro 解釋 Nextflow 用 profile 的容器映像建立了這個定義,並在每次執行重複使用。量測值:28 秒和 31 秒。

### 再執行一次

步驟 2 的答案一出來,先別往下讀,馬上送出這個提示詞。時機很重要,下面會說明。

提示詞:

```text
Run the same pipeline again with `--addressee 'warm run' -with-trace trace-warm.txt`, in the foreground, and compare its Duration with the first run. Explain where the difference comes from.
```

Kiro 執行了什麼:`nextflow run main.nf -profile batch --addressee 'warm run' -with-trace trace-warm.txt`,然後以一次呼叫讀 `trace-warm.txt` 和輸出檔案,並對兩個工作執行 `aws batch describe-jobs`,把提交到開始的等待時間並排。

核准:2~4 次。

成功的樣子:Duration 遠低於 1 分鐘(前一次是 2~4 分鐘),Kiro 解釋第一次執行的執行個體仍註冊在運算環境中,所以工作在已經有映像的主機上幾秒內就開始。量測值:整回合 51 秒和 64 秒;任務兩次都是 19 秒,等待 6~7 秒。這個結果只在步驟 2 結束後 1 分鐘內送出提示詞時才會出現,因為佇列一空,Batch 大約 2 分鐘後就會終止閒置的執行個體。第三次執行時,提示詞在第一個工作結束 2 分 20 秒後才送出,執行個體已經消失,「暖」執行等了 3 分 11 秒才拿到新執行個體(整回合 3 分 52 秒)。Kiro 注意到了較長的等待並解釋原因,後面的成本步驟也顯示兩次執行跑在不同的執行個體 ID 上。無論哪種結果,學到的東西相同:從 0 擴展要付啟動成本。如果你碰到冷啟動版本,讀完 Kiro 的解釋就往下走。

### 不動管線,改變資源請求

提示詞:

```text
Without editing main.nf or nextflow.config, create a file named resources.config that sets cpus = 4 and memory = '8 GB' for the Greet process only, using process { withName: 'Greet' { ... } }. Then run `nextflow run main.nf -profile batch -c resources.config --addressee 'bigger' -with-trace trace-bigger.txt` in the foreground. When it finishes, find the newest SUCCEEDED job in nextflow-batch-queue with `aws batch list-jobs`, run `aws batch describe-jobs` on it, and tell me the vCPU and memory values Batch received, the job definition revision it used, and the EC2 instance type Batch chose for it.
```

Kiro 執行了什麼:寫出 `resources.config`(檔案寫入,會要求核准),執行管線。接著以建立時間排序執行 `aws batch list-jobs --job-queue nextflow-batch-queue --job-status SUCCEEDED`,對最新的 ID 執行 `aws batch describe-jobs`。為了找出執行個體類型,它用 `aws ecs describe-container-instances` 和 `aws ec2 describe-instances` 從工作的容器執行個體一路追到 EC2。

核准:5~7 次(1 次檔案寫入和 4~6 次 shell 呼叫。較長那次的額外呼叫是確認 trace 檔案還不存在,以及一次格式錯誤後的重試)。

成功的樣子:`describe-jobs` 顯示 `resourceRequirements` 為 `4 VCPU` 和 `8192 MEMORY`,工作定義 revision 和前兩次執行相同(新帳戶上是 revision 1),執行個體類型比第一次執行大。Batch 會挑能容納等待中工作的最便宜執行個體,所以類型會不同:量測執行中是 `r6i.xlarge` 和 `m6i.xlarge`。Kiro 應該指出 `main.nf` 和工作定義都沒有改,尺寸是以每個工作的 override 傳入的。量測值:整回合 3 分 07 秒和 3 分 16 秒。因為 Batch 必須新啟動一台更大的執行個體,任務花了 2 分 19 秒和 2 分 29 秒。

## 量測成本

提示詞:

```text
Estimate what the three runs cost with the lab's script: run `uv run --with boto3 scripts/run-cost.py <trace file>` for trace-cold.txt, trace-warm.txt and trace-bigger.txt. Do not modify the script. Explain the difference between the attributed and incurred totals, and what the utilisation percentage means for a one-task pipeline.
```

Kiro 執行了什麼:一個 shell 迴圈,對三個 trace 檔案各呼叫一次 `uv run --with boto3 scripts/run-cost.py <trace>`。第一次呼叫要把 `boto3` 下載到快取環境,多花幾秒。

核准:1 次。

成功的樣子:三張小表,各顯示一個執行約 6 秒的 `Greet` 任務、不到 1 美分幾分之一的歸屬(attributed)成本、整個執行個體存活期間不到 1 美分的實際發生(incurred)成本,以及最多幾個百分點的使用率。兩次量測中,冷執行和暖執行都共用一台 `c6i.large`(實際發生成本約 $0.0055,因為是同一台執行個體,兩份報告都會出現),bigger 執行則用了自己的一台更大執行個體。使用率一次是 1%、1%、5%,另一次是 1%、1%、12%;後者是 bigger 執行的執行個體還在運作,指令碼在它的 span 標了 `+`。Kiro 解釋歸屬成本是任務在執行的那幾秒內保留的執行個體份額,實際發生成本是 EC2 從執行個體啟動到終止計費的金額,而在縮減到 0 的環境裡,單任務管線幾乎全部的錢都付給了啟動和閒置時間。這一步請在執行後 1 小時內做;之後執行個體從 EC2 和 ECS API 消失,指令碼只能退回使用替代單價,那些列會標上 `*`。量測值:22 秒和 32 秒。

Cost and Usage Report 的精確數字在 README 的[量測成本](README.zh-TW.md#量測成本)有說明;需要你自己帳戶的帳單主控台,而且一天後才到,所以不在這個 session 的範圍內。

## 清理

提示詞:

```text
Clean up the lab: run `aws cloudformation delete-stack --stack-name nextflow-batch`, remove the objects under the nextflow-batch/ prefix of the work bucket named in nextflow.config (only that prefix, not the bucket), then wait with `aws cloudformation wait stack-delete-complete --stack-name nextflow-batch` and confirm the stack is gone. Do not delete anything else.
```

Kiro 執行了什麼:`aws cloudformation delete-stack`、`aws s3 rm --recursive s3://<work bucket>/nextflow-batch/`、`aws cloudformation wait stack-delete-complete`,最後用 `describe-stacks` 和 `describe-job-queues` 證明資源已經不在。刪除運算環境會終止剩餘的執行個體,所以等待要幾分鐘。

核准:4 次。

成功的樣子:前綴清單顯示 0 個物件,等待無錯誤返回,`describe-stacks` 回答堆疊不存在。Nextflow 註冊的工作定義會留下,不收費,README 有取消註冊的方法。如果做過 Mountpoint 一節,儲存貯體裡還會留著 `reference/sample.gff3`;想讓儲存貯體回到原狀,請 Kiro 刪掉它。量測值:2 分 59 秒和 3 分 17 秒。

如果之後還會回來做這個實作,就跳過這一步。運算環境在 0 vCPU 時堆疊不花錢,唯一持續的費用是 S3 工作目錄。

## 選用:用 Mountpoint for Amazon S3 串流參考資料

這一節跟著 README 的 [Mountpoint 一節](README.zh-TW.md#更進一步用-mountpoint-for-amazon-s3-串流參考資料)。帶掛載旗標重新執行設定會替換運算環境,所以請在主要步驟做完、清理之前進行。`<bucket>` 換成放參考資料的儲存貯體;練習時用工作儲存貯體本身也可以。

提示詞:

```text
Switch the lab to the Mountpoint for Amazon S3 mode: re-run the setup script as `DATA_BUCKET=<bucket> MOUNT_DATA_BUCKET=true bash scripts/setup-nextflow-batch.sh` and show me the Mountpoint line it prints. Then create a small GFF3 test file named sample.gff3 with two comment lines and three feature lines, upload it to s3://<bucket>/reference/sample.gff3, and run `nextflow run pipeline/ref-check.nf -profile batch -with-trace trace-mount.txt` in the foreground. Show me what REF_SUMMARY printed, and explain why ref-check.nf passes the mounted directory as a val input instead of a path input.
```

Kiro 執行了什麼:讀 `pipeline/ref-check.nf`,帶著兩個變數執行設定指令碼(CloudFormation 替換運算環境約 2 分鐘),以一次呼叫用 `printf` 寫出 `sample.gff3` 並用 `aws s3 cp` 上傳,然後執行管線。由於 `ref-check.nf` 不會把 process 輸出顯示在主控台,它接著用 `aws s3 cp ... -` 從任務的 S3 工作目錄取回 `.command.out` 和 `summary.txt`。新的運算環境從 0 開始,所以這次執行又是冷啟動。

核准:4 次。

成功的樣子:指令碼印出 `Mountpoint  : s3://<bucket> -> /mnt/s3-ref (on compute instances)`,`nextflow.config` 多了一行 `volumes = '/mnt/s3-ref:/mnt/s3-ref:ro'`,任務輸出出現 `mount: 1 mountpoint-s3 filesystem(s) visible`、`reference/` 的清單和 `features: 3`。Kiro 解釋如果用 `path` 輸入,頭節點會試著暫存只有運算執行個體看得到的檔案。量測值:整回合 5 分 33 秒和 7 分 04 秒,任務 2 分 29 秒和 3 分 29 秒。

## 選用:執行 nf-core/sarek test profile

GreetingsNF 展示運作原理,真正的管線展示排程。README 的 [nf-core 一節](README.zh-TW.md#選用執行真正的-nf-core-管線)用各自的 test profile 執行 nf-core/rnaseq 和 nf-core/sarek。要交給 Kiro 的是 sarek test(23 個任務,在實作的 16 vCPU 運算環境上 10~15 分鐘)。在背景啟動,邊讀邊問進度;前景執行可能撞上 CLI 的 15 分鐘指令上限。

提示詞:

```text
Run the nf-core/sarek test profile on the Batch environment in the background, using the work bucket from nextflow.config: `nextflow -bg run nf-core/sarek -r 3.5.1 -profile test,batch --outdir s3://<work bucket>/nextflow-batch/sarek-test -with-trace trace-sarek.txt -ansi-log false > sarek.log 2>&1`. Do not use nohup. Confirm it started by showing the first lines of sarek.log, then stop; I will ask you for progress myself.
```

Kiro 執行了什麼:以一次 shell 呼叫執行填入 `nextflow.config` 中儲存貯體名稱的 `nextflow -bg run ...` 指令、等 20 秒、`head sarek.log`。

核准:1 次。

之後每當想知道進度:

```text
How is the sarek run going? Count the submitted and completed processes in .nextflow.log, show the last ten lines of sarek.log, and tell me whether it has finished.
```

Kiro 以 1~3 次 shell 呼叫對日誌執行 `grep -c`、對 `sarek.log` 執行 `tail`、對 Nextflow 程序執行 `pgrep`(15~35 秒)。兩個計數都到 23、`.nextflow.log` 出現 `Workflow completed`、`sarek.log` 以 `Pipeline completed successfully` 結尾,就是跑完了。這段時間看 Batch 主控台的 Environments 頁面:運算環境爬到 16 vCPU,最後一個任務之後回到 0。量測執行花了 13 分鐘和 10 分鐘。

結束後:

```text
The sarek run has finished. Run `uv run --with boto3 scripts/run-cost.py trace-sarek.txt` and tell me which processes cost the most, how long the tasks waited in total, and how much of the instance time was idle.
```

核准:1 次。

成功的樣子:一張 23 個任務分布在幾台執行個體上的表,實際發生成本合計 6~7 美分,使用率 20% 左右。一次用了六台執行個體(兩台 `c6i.2xlarge`、一台 `c6i.large`、兩台 `m6i.xlarge`、一台 `r6i.xlarge`),歸屬 $0.0125 對實際發生 $0.0595,使用率 21%;另一次用兩台 `c6i.2xlarge`,$0.0126 對 $0.0675,19%。Batch 啟動幾台執行個體,取決於最初的任務怎麼重疊。Kiro 應該指出等了第一台執行個體 2~3 分鐘的那幾個最早的任務(`FASTQC` 和 interval 準備)。量測值:16 秒和 25 秒。結束後的輸出可以用 `aws s3 rm --recursive s3://<work bucket>/nextflow-batch/sarek-test/` 清掉(請 Kiro 做,核准 1 次),或留給刪除整個 `nextflow-batch/` 前綴的清理步驟處理。

## 可以問 Kiro 的問題

執行結束後留下 `nextflow.config`、`.nextflow.log` 和 trace 檔案,而 Kiro 可以透過 `aws-mcp` 以及(在工作坊 IDE 上)自己的網頁搜尋與抓取工具查 AWS 文件。下面的提示詞把這些變成討論。沒有一個會改動 AWS 上的任何東西。量測執行中各花 25~80 秒。

讀 trace(1~5 次呼叫。Kiro 會寫一個把 trace 做成表格的短 Python 指令碼,有時建成暫存檔再刪掉,也可能呼叫 `aws batch describe-jobs` 把任務和執行個體配對):

```text
Read trace-sarek.txt (or trace-cold.txt and trace-warm.txt if sarek did not run). For each task, compare duration (submission to completion) with realtime (how long the script ran). Which tasks waited longest, and what does the pattern tell me about how AWS Batch scaled the compute environment during the run?
```

好的回答會把任務分成幾波(wave):最早的五個任務等了第一台執行個體約 2 分鐘;那台執行個體還在時提交的任務 15~45 秒就開始;當管線擴散到超過運作中的容量、Batch 再啟動執行個體時,出現第二波 2 分鐘的等待。

和 HealthOmics 並排比較(核准 5~7 次:4~6 次 `aws-mcp` 文件搜尋加 1 次 shell 呼叫或網頁搜尋;替 `aws-mcp` 建立 allow 規則後是 1~2 次):

```text
Compare what we just did on AWS Batch with running the same main.nf on AWS HealthOmics. List what I had to create here that HealthOmics manages for me, what Batch lets me control that HealthOmics does not, and when I would choose each. Use the AWS documentation through the aws-mcp server and the comparison table in README.md, and say which statements come from which source.
```

好的回答會替每句話標出來源:這個 session、README 的表格,還是 AWS 文件。它也會指出 README 的摘要和目前文件不一致的地方,例如 HealthOmics 接受哪些容器登錄、支援哪些 Nextflow 版本。

成本(不用工具。Kiro 用對話中已有的 `run-cost.py` 輸出回答):

```text
Using the run-cost.py output from this session, explain why the attributed cost is so far below the incurred cost. Then estimate the monthly cost of keeping MinvCpus=2 on the compute environment so runs start warm, compared with scaling to zero, using the On-Demand price of the smallest instance Batch used here. Show the arithmetic and the assumptions.
```

好的回答會把 `c6i.large` 的隨需單價乘以 730 小時(每月約 $62),和幾次執行的實際發生成本對比,並說明假設:`MinvCpus=2` 正好維持一台 `c6i.large`,不含 EBS 和 S3,單價是指令碼查到的值。

正式環境的變更(核准 4~6 次:`aws-mcp` 搜尋,其中一次執行還抓了 Nextflow 設定參考文件的網頁):

```text
What would I change in nextflow.config and in cfn/batch-nextflow.yaml to run this on Spot Instances with retries for Spot interruptions? Show the changes as text and do not apply them.
```

這個提示詞要求 Kiro 顯示 steering 禁止它編輯的檔案的變更。Kiro 應該以文字 diff 回答,並說明沒有套用任何東西;如果它提議套用,請拒絕。好的回答涵蓋搭配 `SPOT_PRICE_CAPACITY_OPTIMIZED` 的 `Type: SPOT`(或在佇列中排在隨需環境前面的第二個 Spot 運算環境)、`aws.batch.maxSpotAttempts`,以及重試被中斷任務的 `errorStrategy`,和 README 正式環境備註的內容相同。第二次執行時 Kiro 還讀了 CloudFormation 參考文件,並指出把現有環境從 `EC2` 改成 `SPOT` 是就地更新,不是替換。

## 當 Kiro 做了別的事

Kiro 提議重寫設定指令碼或直接部署 CloudFormation。拒絕該指令並提醒它:「Follow the steering file: run the script as is.」工作坊 IDE 上沒有可拒絕的提示,改為中斷該回合(IDE 聊天的 **Cancel** 按鈕,CLI 用 Ctrl+C)再送出同一句話。這通常是沒有信任工作區、steering 檔案沒載入時發生的;用「打開儲存庫並信任工作區」的 steering 確認提示詞檢查。

Kiro 用 `nohup ... &` 執行 `nextflow`。拒絕,或在工作坊 IDE 上中斷該回合。steering 檔案把 `nextflow -bg` 指定為脫離執行的唯一方法,請它改用那個。

指令失敗,Kiro 只診斷不修復就停下。這是 steering 檔案在發揮作用。寫這份指南期間,有一次冷執行因為啟動範本的 bootstrap bug 失敗(之後已修正)。Kiro 讀了執行個體的主控台輸出,引用範本中有問題的那行和 README 疑難排解表的對應列,然後停住。這正是你希望在參與者帳戶上運作的 agent 有的行為。讀診斷、修正或回報原因,再貼一次該步驟的提示詞。

Nextflow 以 `Trace file already exists` 拒絕啟動。同一步驟先前的嘗試留下了 trace 檔案。告訴 Kiro:「Delete the old trace file and run the same command again.」測試中遇到這個情況時,Kiro 沒有自行刪除檔案,而是停下來問你要哪種做法。

`nextflow run` 指令看起來卡了好幾分鐘。冷的運算環境上,2~3 分鐘的沉默是正常的。超過 10 分鐘,請 Kiro 對 `RUNNABLE` 狀態的工作執行 `aws batch describe-jobs`,並讀運算環境的狀態原因。README 的[疑難排解](README.zh-TW.md#疑難排解)表整理了常見原因。

Kiro 回答讀不到 `.nextflow.log` 或 trace 檔案。聊天不是從儲存庫根目錄啟動的。在正確的資料夾開新聊天,從進行中的步驟接著做;檔案和 AWS 資源都還在。
