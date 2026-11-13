# 用 Kiro 跟著進行現場實作

[English guide](KIRO.md) · [한국어 가이드](KIRO.ko.md)

本指南從活動前環境設定完成後開始。請依照[參與者頁面](https://aws-sa.notion.site/Taiwan-Bioinformatics-Workflow-Workshop-AWS-Hands-on-Guide-14-November-2026-41455978597981039feac5474c869e6d)加入 Workshop Studio、開啟 Kiro IDE、複製儲存庫，並在 10:25 前準備好 AWS Batch 環境。

現場實作期間請保持本指南開啟，並將每個提示詞貼到同一個 Kiro 聊天中。這樣 Kiro 才能沿用前一步的檔案和執行結果。

> 只使用實作提供的範例資料。請勿將患者資料、可識別個人身分的資料、專有資料或尚未公開的研究資料上傳到臨時工作坊帳戶。

## 開始前確認

符合下列條件即可開始現場實作：

- `nextflow-aws-batch-lab` 資料夾已在 Kiro 中開啟並設為信任。
- `nextflow-batch-queue` 為 `ENABLED` 和 `VALID`。
- 運算環境為 `VALID`，desired vCPU 為 0。

如果任何一項不符合，請在開始第一次執行前舉手。個人環境的設定說明收在[本指南最後](#self-paced-setup)的摺疊區段中。

## 1. 執行冷啟動與暖啟動管線

這個提示詞會連續執行 GreetingsNF 兩次。第一個工作會從 0 啟動運算環境。第二個工作會在第一個工作完成後立即提交，以便重複使用仍在運作的執行個體。

貼到 Kiro：

```text
Run the GreetingsNF pipeline on AWS Batch twice from the repository root.

First run:
nextflow run main.nf -profile batch --addressee 'AWS Batch' -with-trace trace-cold.txt

As soon as it finishes, immediately run:
nextflow run main.nf -profile batch --addressee 'warm run' -with-trace trace-warm.txt

Do not pause between the two runs. When both are complete, show the Duration and Succeeded count for each run, show the content of /mnt/workflow/pubdir/output, and compare how long the two Batch jobs waited between submission and start.
```

Kiro 執行時，開啟 [AWS Batch 工作頁面](https://console.aws.amazon.com/batch/home#jobs)。選擇 `nextflow-batch-queue`，按一下 **Search**，觀察工作依序進入 `RUNNABLE`、`STARTING` 和 `RUNNING`。

![AWS Batch 工作](images/jobs-list.png)

第一次執行通常需要 2 至 4 分鐘，因為 AWS Batch 必須啟動 Amazon EC2 執行個體並拉取容器映像。如果第一台執行個體仍可用，第二次執行通常會在幾秒內開始。

> 檢查點：兩次執行都成功，最後的輸出為 `hello warm run`。如果第二次執行再次發生冷啟動，這仍是有效的縮減至 0 結果，不代表實作失敗。

## 2. 查看 Nextflow 如何對應到 AWS Batch

Kiro 會讀取兩次執行的設定、trace 檔案和 Batch 工作 metadata。

貼到 Kiro：

```text
Using nextflow.config, trace-cold.txt, trace-warm.txt and AWS Batch job metadata, explain:

1. Which job queue and container image were used.
2. How one invocation of the Greet process became one Batch job.
3. What Nextflow registered as the job definition.
4. Compare how long the two jobs waited and explain why they did or did not differ.

Keep the explanation under 200 words.
```

Job definition 是 AWS Batch 執行容器時使用的範本。Nextflow 會為容器映像建立或重複使用 job definition，並在提交工作時傳入該 task 的資源請求。

> 檢查點：`Greet` process 的一次執行對應到一個 Batch 工作。Kiro 找到 `nextflow-batch-queue` 和 `ubuntu:22.04` 容器映像。

## 3. 變更資源請求

這個步驟不修改管線。第二個設定檔只會變更 `Greet` process 的 CPU 和記憶體請求。

貼到 Kiro：

```text
Without editing main.nf or nextflow.config, create resources.config that sets cpus = 4 and memory = '8 GB' for the Greet process only, using process { withName: 'Greet' { ... } }.

Run:
nextflow run main.nf -profile batch -c resources.config --addressee 'bigger' -with-trace trace-bigger.txt

When the run finishes, read the `native_id` from trace-bigger.txt and inspect that exact AWS Batch job. Report the VCPU and MEMORY values that Batch received, and confirm whether the existing job definition was reused. Report the EC2 instance type if it is still available, but explain that the exact type can vary.
```

> 檢查點：AWS Batch 收到 `4 VCPU` 和 `8192 MEMORY`。EC2 執行個體類型會依執行時可用的容量而不同，因此不是通過條件。

## 4. 啟動 nf-core/sarek

最後一個現場步驟會啟動一個實際的、由多個 process 組成的 bioinformatics workflow。Test profile 使用小型公開資料集，並在背景執行。

貼到 Kiro：

```text
Start the nf-core/sarek test profile on the Batch environment in the background. Read the work bucket from nextflow.config and run:

nextflow -bg run nf-core/sarek -r 3.5.1 -profile test,batch --outdir s3://<work-bucket>/nextflow-batch/sarek-test -with-trace trace-sarek.txt -ansi-log false > sarek.log 2>&1

Replace <work-bucket> with the bucket from nextflow.config. Do not use nohup. Do not wait for completion. Confirm that the run started, show the first lines of sarek.log, and return control to me.
```

參與者的執行持續進行時，講師會展示已完成的 reference run。Reference run 在約 10 至 15 分鐘內完成 23 個 task。輸出包含 VCF 檔案（variant call 結果檔案）和 MultiQC report（彙整品質控制結果的報告）。

稍後可用下列提示詞查看進度：

```text
Check the nf-core/sarek run. Show the last ten lines of sarek.log. Count submitted tasks from .nextflow.log and completed tasks from trace-sarek.txt, excluding the header. Tell me whether the workflow is still running or has completed.
```

> 檢查點：nf-core/sarek 已在背景啟動。Q&A 開始前不必等待它執行完成。

## 現場實作完成

你已將 Nextflow process 當作 AWS Batch 工作執行，並觀察 AWS Batch 如何啟動或重複使用運算容量。你也在不修改管線的情況下變更 task 資源，並啟動 nf-core/sarek workflow。

Q&A 於 11:20 開始。工作坊帳戶不需要自行清理，環境可使用到台北時間 18:00。

> Kiro 會執行並解釋準備好的實作。它不會驗證科學或臨床結果、核准敏感資料的使用，也不保證確切的執行時間、執行個體類型或成本。

手動指令、疑難排解、成本量測、Mountpoint for Amazon S3 和 AWS HealthOmics 比較，請參考[參與者附錄](https://aws-sa.notion.site/Appendix-References-Troubleshooting-and-Self-Paced-Exercises-41755978597981a6adebc897ae969f67)或 [README](README.zh-TW.md)。

---

<a id="self-paced-setup"></a>

<details>
<summary><b>在現場工作坊以外自行設定</b></summary>

現場工作坊會在第一次執行前，透過參與者頁面完成下列步驟。若要在其他環境重新執行實作，請使用本區段。

### 需求

你需要一個 AWS 帳戶、可以使用 `sudo` 的 Linux shell，以及一個作為 Nextflow 工作目錄的 S3 儲存貯體。設定會建立 IAM 角色和 AWS Batch 資源，因此需要管理員等級的權限。完整權限說明請參考 [README 的事前準備](README.zh-TW.md#事前準備)。

確認 shell 可以使用 AWS 憑證：

```bash
aws sts get-caller-identity --query Arn --output text
```

Kiro CLI 使用者可確認登入狀態：

```bash
kiro-cli whoami
```

如果沒有傳回 identity，請執行 `kiro-cli login`。Kiro IDE 使用者可查看帳戶選單。Workshop Studio IDE 已透過 API key 登入。

### 複製並信任儲存庫

```bash
git clone https://github.com/hmkim/nextflow-aws-batch-lab.git
cd nextflow-aws-batch-lab
```

在 Kiro IDE 中開啟此資料夾，或從儲存庫根目錄啟動 Kiro CLI：

```bash
kiro-cli chat
```

如果 Kiro 詢問是否信任 workspace，請選擇 **Trust**。Kiro 隨後會載入 `.kiro/steering/aws-batch-lab.md`，並依照實作允許的範圍執行工作。

### 設定環境

貼到 Kiro：

```text
Run the lab setup script: bash scripts/setup-nextflow-batch.sh from the repository root, and show me its output. Do not modify the script or the CloudFormation template, and do not deploy anything by other means. When it finishes, check with aws batch describe-job-queues and aws batch describe-compute-environments that the job queue nextflow-batch-queue is ENABLED and VALID and that the compute environment is VALID with 0 desired vCPUs, then tell me the stack is ready.
```

在工作坊帳戶以外，將 `<your-work-bucket>` 換成自己的儲存貯體名稱，再貼上下列提示詞：

```text
Run the lab setup script with WORK_BUCKET=<your-work-bucket> bash scripts/setup-nextflow-batch.sh from the repository root, and show me its output. Do not modify the script or the CloudFormation template, and do not deploy anything by other means. When it finishes, check with aws batch describe-job-queues and aws batch describe-compute-environments that the job queue nextflow-batch-queue is ENABLED and VALID and that the compute environment is VALID with 0 desired vCPUs, then tell me the stack is ready.
```

當工作佇列為 `ENABLED` 和 `VALID`，且運算環境為 `VALID`、desired vCPU 為 0 時，設定即完成。

</details>

<details>
<summary><b>在個人環境使用 Kiro：權限與核准</b></summary>

Workshop Studio 會預先核准本實作使用的工具。個人 Kiro 環境可能會在執行 shell 指令、寫入檔案、抓取網頁或呼叫 MCP 工具前要求核准。

允許前請檢查要求的動作。為 `nextflow *` 和唯讀 AWS 指令建立 session 範圍的規則，可以減少重複提示。不要核准會重寫設定指令碼、CloudFormation 範本、`main.nf` 或 `nextflow.config` 的指令。

Kiro CLI 的前景指令可能在 15 分鐘後停止。nf-core/sarek 步驟因此使用 `nextflow -bg`。請勿改用 `nohup`。

</details>

<details>
<summary><b>選用：使用 AWS MCP server 搜尋文件</b></summary>

現場 AWS Batch 實作不需要 MCP server。只有在實作後想讓 Kiro 搜尋 AWS 文件時，才需要設定 `aws-mcp`。

Workshop Studio IDE 已預先設定。其他環境可將 SigV4 proxy 加到 `~/.kiro/settings/mcp.json`：

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

連線方式請參考 [AWS MCP Server guide](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/getting-started-aws-mcp-server.html)。

</details>

<details>
<summary><b>選用：估算執行成本</b></summary>

請在管線完成後約一小時內執行估算工具，此時執行個體 metadata 通常仍可取得。

```text
Run these commands one at a time and do not modify the script:

uv run --with boto3 scripts/run-cost.py trace-cold.txt
uv run --with boto3 scripts/run-cost.py trace-warm.txt
uv run --with boto3 scripts/run-cost.py trace-bigger.txt

Explain the difference between attributed and incurred cost.
```

Attributed cost 是 task 所使用份額的估算值。Incurred cost 是 EC2 執行個體從啟動到終止的成本估算值。這些數字不是最終 AWS 帳單。使用 billing data 的方法請參考[量測成本](README.zh-TW.md#量測成本)。

</details>

<details>
<summary><b>疑難排解</b></summary>

| 狀況 | 下一步 |
|---|---|
| `Trace file already exists` | 請 Kiro 只刪除該舊 trace 檔案，然後重複此步驟。 |
| 冷啟動在 2 至 3 分鐘內沒有輸出 | 請等待。AWS Batch 正在啟動運算容量。 |
| 工作維持 `RUNNABLE` 達 10 分鐘 | 請舉手，並請 Kiro 讀取運算環境的 status reason。 |
| Kiro 無法讀取 `.nextflow.log` | 從儲存庫根目錄重新開始聊天。 |
| Kiro 建議其他設定或修改受保護的實作檔案 | 停止該回合，並告訴 Kiro 遵循儲存庫的 steering 檔案。 |

其他原因和診斷指令請參考 [README 疑難排解表](README.zh-TW.md#疑難排解)。

</details>
