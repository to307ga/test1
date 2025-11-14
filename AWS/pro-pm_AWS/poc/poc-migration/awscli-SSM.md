# AWS CLI と SSM Session Manager Plugin の関係

このドキュメントでは、AWS CLIとSSM Session Manager Pluginの関係性、動作原理、インストール方法について詳しく解説します。

## 📋 目次

1. [概要](#概要)
2. [アーキテクチャ図](#アーキテクチャ図)
3. [コンポーネントの役割](#コンポーネントの役割)
4. [通信フロー](#通信フロー)
5. [インストール方法](#インストール方法)
6. [動作確認](#動作確認)
7. [通信の詳細](#通信の詳細)
8. [トラブルシューティング](#トラブルシューティング)
9. [セキュリティのベストプラクティス](#セキュリティのベストプラクティス)
10. [まとめ](#まとめ)

---

## 概要

**AWS CLI** と **SSM Session Manager Plugin** は、AWS Systems Manager Session Managerを使用してEC2インスタンスやECSタスクに安全に接続するために必要な2つの独立したコンポーネントです。

### 🎯 わかりやすい例え（重要！）

**従来のSSH接続との比較**で理解すると分かりやすいです：

| 従来のSSH | Session Manager |
|----------|-----------------|
| `ssh` コマンド（クライアント） | **AWS CLI** = "呼び出し役" |
| SSH接続プロトコル | **SSM Plugin** = "実際の通信担当" |
| `~/.ssh/id_rsa` (秘密鍵) | AWS認証情報（IAM） |
| `sshd` (サーバー側) | SSM Agent（EC2/ECS側） |

#### より具体的な例え

```bash
# 従来のSSH
bash$ ssh -i ~/.ssh/id_rsa ec2-user@10.0.1.100
      ↑     ↑                ↑
    シェル  SSH実行バイナリ   接続先

# Session Manager
bash$ aws ssm start-session --target i-xxx
      ↑   ↑                  ↑
    シェル  AWS CLI           SSM Plugin（裏で動く）
           （準備役）         （実際の通信担当）
```

**乱暴に言えば**:
- **AWS CLI = bash的な役割**: 「準備してプラグインを呼び出す」コマンドランナー
- **SSM Plugin = SSH的な役割**: 「実際の暗号化通信を担当する」プロトコル実装

### 重要なポイント

- **AWS CLI**: AWSサービスとの通信を行うコマンドラインツール（準備役）
- **SSM Plugin**: Session Managerの実際のセッション通信を処理するプラグイン（実働部隊）
- **両方必須**: Session Managerを使うには両方のインストールが必要

---

## アーキテクチャ図

### 全体構成

```mermaid
graph TB
    subgraph "ローカル環境"
        User[ユーザー]
        CLI[AWS CLI<br/>aws ssm start-session]
        Plugin[SSM Plugin<br/>session-manager-plugin]
    end
    
    subgraph "AWS"
        SSM[Systems Manager<br/>Session Manager]
        EC2[EC2インスタンス<br/>SSM Agent]
        ECS[ECS Fargate Task<br/>SSM Agent]
    end
    
    User -->|1. コマンド実行| CLI
    CLI -->|2. API呼び出し| SSM
    SSM -->|3. セッション情報返却| CLI
    CLI -->|4. プラグイン起動<br/>セッション情報渡す| Plugin
    Plugin <-->|5. WebSocket通信<br/>暗号化されたデータ| SSM
    SSM <-->|6. SSM Agent経由| EC2
    SSM <-->|6. SSM Agent経由| ECS
    
    style CLI fill:#FF9900
    style Plugin fill:#FF6600
    style SSM fill:#3B48CC
    style EC2 fill:#EC7211
    style ECS fill:#FF9900
```

### コンポーネント関係図

```mermaid
graph LR
    subgraph "AWS CLI (Python製)"
        A[aws コマンド]
        B[認証情報管理]
        C[API リクエスト]
    end
    
    subgraph "SSM Plugin (Go製)"
        D[session-manager-plugin]
        E[WebSocket通信]
        F[暗号化/復号化]
        G[ローカルプロキシ]
    end
    
    A -->|start-session<br/>サブコマンド| C
    C -->|セッション情報JSON| D
    D --> E
    E --> F
    F --> G
    
    style A fill:#FFD700
    style D fill:#FF6347
```

---

## コンポーネントの役割

### 1. AWS CLI の役割

AWS CLIは以下の処理を担当します：

```mermaid
sequenceDiagram
    participant User as ユーザー
    participant CLI as AWS CLI
    participant IAM as AWS IAM
    participant SSM as SSM API
    
    User->>CLI: aws ssm start-session --target i-xxx
    CLI->>IAM: 認証情報確認
    IAM-->>CLI: 認証OK
    CLI->>SSM: StartSession API呼び出し
    SSM-->>CLI: SessionId, TokenValue, StreamUrl 返却
    Note over CLI: この時点でCLIの役割は終了<br/>プラグインに制御を渡す
```

#### AWS CLIの具体的な処理

1. **認証情報の管理**
   - `~/.aws/credentials` または環境変数から認証情報を読み込み
   - IAMロールやMFAトークンの処理

2. **API呼び出し**
   - `StartSession` API をAWS Systems Managerに送信
   - ターゲット（EC2インスタンスIDやECSタスクARN）を指定

3. **レスポンス処理**
   - セッションID、トークン、WebSocket URLを受け取る
   - JSON形式でSession Manager Pluginに渡す

4. **プラグイン起動**
   - `session-manager-plugin` を子プロセスとして起動
   - セッション情報をJSONで標準入力に渡す

#### AWS CLIのコード例

```bash
# AWS CLIが実行する処理（簡略化）
aws ssm start-session \
  --target i-0123456789abcdef0 \
  --region ap-northeast-1 \
  --profile default

# 内部的には以下のようなAPIコール
# POST https://ssm.ap-northeast-1.amazonaws.com/
# {
#   "Target": "i-0123456789abcdef0",
#   "DocumentName": "AWS-StartSSHSession"
# }
```

### 2. SSM Session Manager Plugin の役割

Pluginは実際のセッション通信を担当します：

```mermaid
sequenceDiagram
    participant CLI as AWS CLI
    participant Plugin as SSM Plugin
    participant WS as WebSocket
    participant SSM as SSM Service
    participant Agent as SSM Agent
    participant Target as EC2/ECS
    
    CLI->>Plugin: JSON（SessionId, Token, StreamUrl）
    Plugin->>WS: WebSocket接続確立
    WS->>SSM: セッション開始
    SSM->>Agent: コマンド転送
    Agent->>Target: コマンド実行
    Target-->>Agent: 出力結果
    Agent-->>SSM: 結果返送
    SSM-->>WS: データ返送
    WS-->>Plugin: データ受信
    Plugin-->>CLI: 標準出力/標準エラー
```

#### SSM Pluginの具体的な処理

1. **WebSocket接続の確立**
   - AWS CLIから受け取ったStreamUrlに接続
   - TLS 1.2以上で暗号化された通信

2. **双方向通信**
   - ローカルの標準入力 → WebSocket → SSM Agent
   - SSM Agent → WebSocket → ローカルの標準出力

3. **データの暗号化/復号化**
   - AES-256で通信データを暗号化
   - TokenValueを使った認証

4. **ポートフォワーディング（オプション）**
   - ローカルポート（例: 8080）とリモートポート（例: 3000）をマッピング
   - TCPトラフィックのプロキシとして動作

#### Session Manager Pluginのインストール場所

```bash
# Linuxの場合
/usr/local/bin/session-manager-plugin

# macOSの場合（Homebrew）
/opt/homebrew/bin/session-manager-plugin

# Windowsの場合
C:\Program Files\Amazon\SessionManagerPlugin\bin\session-manager-plugin.exe
```

---

## 通信フロー

### 完全な通信フロー図

```mermaid
sequenceDiagram
    autonumber
    participant User as ユーザー<br/>（ターミナル）
    participant CLI as AWS CLI<br/>（準備役・bash的）
    participant Plugin as SSM Plugin<br/>（通信担当・SSH的）
    participant API as SSM API
    participant Agent as SSM Agent<br/>（EC2/ECS）
    participant Shell as bash/sh
    
    User->>CLI: aws ssm start-session --target i-xxx
    
    Note over CLI: Phase 1: 認証とセッション作成<br/>（AWS CLIの仕事）
    CLI->>API: StartSession API<br/>{Target: "i-xxx", DocumentName: "..."}
    API->>Agent: セッション作成要求
    Agent-->>API: Agent Ready
    API-->>CLI: {SessionId, TokenValue, StreamUrl}
    
    Note over CLI,Plugin: Phase 2: プラグイン起動<br/>（AWS CLIからSSM Pluginにバトンタッチ）
    CLI->>Plugin: session-manager-plugin実行<br/>JSONでセッション情報渡す
    
    Note over Plugin,Agent: Phase 3: WebSocket通信開始<br/>（SSM Pluginの仕事・SSH的な役割）
    Plugin->>API: WebSocket接続<br/>（StreamUrl）
    API->>Agent: WebSocket経由で接続
    Agent->>Shell: シェル起動
    
    Note over User,Shell: Phase 4: インタラクティブセッション<br/>（SSM Pluginが通信を仲介）
    User->>Plugin: コマンド入力（例: ls -la）
    Plugin->>API: 暗号化データ送信
    API->>Agent: データ転送
    Agent->>Shell: コマンド実行
    Shell-->>Agent: 出力結果
    Agent-->>API: 結果返送
    API-->>Plugin: 暗号化データ受信
    Plugin-->>User: 画面に表示
    
    Note over User,Shell: Phase 5: セッション終了
    User->>Plugin: exit または Ctrl+D
    Plugin->>API: セッション終了要求
    API->>Agent: セッションクローズ
    Agent->>Shell: シェル終了
    Plugin-->>CLI: 終了コード返却
    CLI-->>User: プロンプト復帰
```

### ポートフォワーディングの場合

```mermaid
sequenceDiagram
    participant Browser as ブラウザ
    participant Local as localhost:8081
    participant Plugin as SSM Plugin
    participant API as SSM API
    participant Agent as SSM Agent
    participant Jenkins as Jenkins<br/>localhost:8080
    
    Note over Plugin: ポートフォワーディングモード起動
    Plugin->>API: WebSocket接続（port-forwarding）
    API->>Agent: ポートフォワーディング開始
    
    Browser->>Local: http://localhost:8081 アクセス
    Local->>Plugin: TCPパケット受信
    Plugin->>API: 暗号化して送信
    API->>Agent: データ転送
    Agent->>Jenkins: localhost:8080にリクエスト
    Jenkins-->>Agent: レスポンス
    Agent-->>API: データ返送
    API-->>Plugin: 復号化
    Plugin-->>Local: TCPパケット返送
    Local-->>Browser: HTTPレスポンス表示
    
    Note over Browser,Jenkins: WebSocketトンネル経由で<br/>Jenkinsに直接アクセスしているように見える
```

---

## インストール方法

### 1. AWS CLI のインストール

#### Linux (Amazon Linux 2023 / RHEL系)

```bash
# 方法1: パッケージマネージャー（推奨）
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 確認
aws --version
# aws-cli/2.15.0 Python/3.11.6 Linux/6.1.0 exe/x86_64.amzn.2023
```

#### macOS

```bash
# Homebrew（推奨）
brew install awscli

# 公式インストーラー
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# 確認
aws --version
```

#### Windows

```powershell
# MSIインストーラーをダウンロードして実行
# https://awscli.amazonaws.com/AWSCLIV2.msi

# または Chocolatey
choco install awscli

# 確認
aws --version
```

### 2. SSM Session Manager Plugin のインストール

#### Linux (Amazon Linux 2023 / RHEL系)

```bash
# RPMパッケージダウンロード
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"

# インストール
sudo yum install -y session-manager-plugin.rpm

# 確認
session-manager-plugin --version
# 1.2.553.0
```

#### Ubuntu / Debian

```bash
# DEBパッケージダウンロード
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"

# インストール
sudo dpkg -i session-manager-plugin.deb

# 確認
session-manager-plugin --version
```

#### macOS

```bash
# Homebrew（推奨）
brew install --cask session-manager-plugin

# または手動インストール
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac_arm64/sessionmanager-bundle.zip" -o "sessionmanager-bundle.zip"
unzip sessionmanager-bundle.zip
sudo ./sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin

# 確認
session-manager-plugin --version
```

#### Windows

```powershell
# インストーラーをダウンロードして実行
# https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe

# 確認
session-manager-plugin --version
```

### 3. インストール確認

```bash
# AWS CLIの確認
aws --version

# SSM Pluginの確認
session-manager-plugin

# 出力例:
# The Session Manager plugin was installed successfully. Use the AWS CLI to start a session.
```

---

## 動作確認

### 基本的なセッション接続

```bash
# EC2インスタンスに接続
aws ssm start-session \
  --target i-0123456789abcdef0 \
  --region ap-northeast-1

# 成功すると以下のような出力
# Starting session with SessionId: user-0abc123def456789
# sh-5.2$
```

### ポートフォワーディング

```bash
# Jenkinsへのポートフォワーディング（ローカル8081 → リモート8080）
aws ssm start-session \
  --target i-0123456789abcdef0 \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8080"],"localPortNumber":["8081"]}' \
  --region ap-northeast-1

# 成功すると別ターミナルで:
# curl http://localhost:8081
# → Jenkinsの画面が返ってくる
```

### ECS Fargateタスクへの接続

```bash
# ECS Execを使用（SSM Plugin経由）
aws ecs execute-command \
  --cluster poc-poc-ecs-jenkins-cluster \
  --task abc123def456789 \
  --container jenkins \
  --interactive \
  --command "/bin/bash"
```

---

## 通信の詳細

### AWS CLIとPluginの連携プロセス

```mermaid
flowchart TD
    A[aws ssm start-session実行] --> B{AWS CLI}
    B --> C[認証情報確認]
    C --> D[StartSession API呼び出し]
    D --> E{SSM API}
    E --> F[セッション作成]
    F --> G[SessionId生成]
    G --> H[TokenValue生成]
    H --> I[StreamUrl生成]
    I --> J[JSONレスポンス返却]
    J --> K{AWS CLI}
    K --> L[session-manager-plugin起動]
    L --> M{SSM Plugin}
    M --> N[JSONパース]
    N --> O[WebSocket接続]
    O --> P[暗号化トンネル確立]
    P --> Q[インタラクティブセッション開始]
    
    style B fill:#FF9900
    style E fill:#3B48CC
    style M fill:#FF6600
    style Q fill:#00C853
```

### データフロー（コマンド実行時）

```mermaid
flowchart LR
    subgraph Local["ローカル環境"]
        A[キーボード入力]
        B[標準入力]
        C[SSM Plugin]
    end
    
    subgraph Network["ネットワーク（暗号化）"]
        D[WebSocket<br/>TLS 1.2+]
    end
    
    subgraph AWS["AWS Systems Manager"]
        E[SSM Service]
    end
    
    subgraph Remote["リモート環境（EC2/ECS）"]
        F[SSM Agent]
        G[シェル実行]
        H[標準出力]
    end
    
    A --> B
    B --> C
    C -->|暗号化| D
    D --> E
    E --> F
    F --> G
    G --> H
    H -->|結果| F
    F --> E
    E -->|暗号化| D
    D --> C
    C -->|復号化| B
    B --> I[画面表示]
    
    style C fill:#FF6600
    style D fill:#4CAF50
    style E fill:#3B48CC
    style F fill:#FF9900
```

---

## トラブルシューティング

### よくあるエラーと解決方法

#### 1. `SessionManagerPlugin is not found`

**エラー内容**:
```
SessionManagerPlugin is not found. Please refer to SessionManager Documentation here: 
http://docs.aws.amazon.com/console/systems-manager/session-manager-plugin-not-found
```

**原因**: SSM Session Manager Pluginがインストールされていない

**解決方法**:
```bash
# インストール確認
which session-manager-plugin

# 見つからない場合はインストール
# Linux
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
sudo yum install -y session-manager-plugin.rpm

# macOS
brew install --cask session-manager-plugin
```

#### 2. `TargetNotConnected`

**エラー内容**:
```
An error occurred (TargetNotConnected) when calling the StartSession operation: 
i-0123456789abcdef0 is not connected.
```

**原因**: 
- EC2インスタンスにSSM Agentがインストールされていない
- SSM AgentがSystems Managerに登録されていない
- IAMロールが正しく設定されていない

**解決方法**:
```bash
# インスタンスの管理状態確認
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=i-0123456789abcdef0"

# SSM Agentのステータス確認（インスタンス内）
sudo systemctl status amazon-ssm-agent

# SSM Agentの再起動
sudo systemctl restart amazon-ssm-agent
```

#### 3. `AccessDeniedException`

**エラー内容**:
```
An error occurred (AccessDeniedException) when calling the StartSession operation: 
User: arn:aws:iam::123456789012:user/john is not authorized to perform: 
ssm:StartSession on resource: arn:aws:ec2:ap-northeast-1:123456789012:instance/i-xxx
```

**原因**: IAMユーザー/ロールにSSM権限がない

**解決方法**:

IAMポリシーに以下を追加：
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:StartSession",
        "ssm:TerminateSession",
        "ssm:ResumeSession",
        "ssm:DescribeSessions",
        "ssm:GetConnectionStatus"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:DescribeInstanceInformation",
        "ec2:DescribeInstances"
      ],
      "Resource": "*"
    }
  ]
}
```

#### 4. WebSocket接続エラー

**エラー内容**:
```
An error occurred (InternalServerError) when calling the StartSession operation
```

**原因**: 
- プロキシ設定の問題
- ファイアウォールでWebSocket通信がブロックされている
- 古いバージョンのSSM Plugin

**解決方法**:
```bash
# プロキシ設定確認
echo $HTTP_PROXY
echo $HTTPS_PROXY

# プロキシなしで実行
unset HTTP_PROXY
unset HTTPS_PROXY

# SSM Pluginバージョン確認
session-manager-plugin --version

# 最新版に更新
# Linux
sudo yum update -y session-manager-plugin

# macOS
brew upgrade --cask session-manager-plugin
```

---

## セキュリティのベストプラクティス

### 1. 最小権限の原則

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ssm:StartSession",
      "Resource": "arn:aws:ec2:ap-northeast-1:123456789012:instance/i-0123456789abcdef0",
      "Condition": {
        "StringLike": {
          "ssm:resourceTag/Environment": "poc"
        }
      }
    }
  ]
}
```

### 2. セッションログの有効化

```bash
# S3バケットまたはCloudWatch Logsへのログ記録
aws ssm update-document \
  --name "SSM-SessionManagerRunShell" \
  --content file://session-preferences.json
```

### 3. MFA必須化

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ssm:StartSession",
      "Resource": "*",
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    }
  ]
}
```

---

## まとめ

### AWS CLIとSSM Pluginの関係性

```mermaid
mindmap
  root((Session Manager))
    AWS CLI
      "準備役（bash的）"
      認証情報管理
      API呼び出し
      プラグイン起動
      Python製
    SSM Plugin
      "実働部隊（SSH的）"
      WebSocket通信
      データ暗号化
      ポートフォワーディング
      Go製
    両方必須
      CLIがAPI呼び出し
      Pluginが通信処理
      連携して動作
    メリット
      SSH鍵不要
      踏み台不要
      監査ログ記録
      セキュア
```

### 🎯 簡単なまとめ（例え話）

**従来のSSH接続**:
```
あなた → ssh コマンド → SSH通信 → sshd → サーバー
         （準備）      （実際の通信）
```

**Session Manager接続**:
```
あなた → AWS CLI → SSM Plugin → SSM Service → SSM Agent → EC2/ECS
         （準備役）  （実働部隊）   （中継）
         ↑          ↑
       bash的    SSH的な役割
```

**つまり**:
- **AWS CLI**: 「誰がどこに接続したいか」をAWSに伝える（bash的な準備役）
- **SSM Plugin**: 実際に暗号化通信を確立して、キーボード入力を送り、画面出力を受け取る（SSH的な実働部隊）

### チェックリスト

- [ ] AWS CLI v2 インストール済み
- [ ] SSM Session Manager Plugin インストール済み
- [ ] AWS認証情報設定済み（`aws configure`）
- [ ] EC2/ECSにSSM Agentインストール済み
- [ ] IAMロールでSSM権限付与済み
- [ ] ポートフォワーディングテスト成功

### 参考リンク

- [AWS CLI公式ドキュメント](https://docs.aws.amazon.com/cli/)
- [Session Manager公式ドキュメント](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [SSM Plugin GitHubリポジトリ](https://github.com/aws/session-manager-plugin)
