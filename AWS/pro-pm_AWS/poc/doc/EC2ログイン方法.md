# EC2ログイン方法

## 📋 概要

このドキュメントでは、POC環境のEC2インスタンスにSSM Session Managerを使用してログインする方法を説明します。

## 🏗️ POC環境のEC2構成

### EC2インスタンス一覧
- **pochub-001** (ap-northeast-1a) - プライベートIP: 10.0.11.x
- **pochub-002** (ap-northeast-1c) - プライベートIP: 10.0.12.x  
- **pochub-003** (ap-northeast-1d) - プライベートIP: 10.0.13.x

### セキュリティ設計
- **SSH直接接続**: 無効（セキュリティグループで22番ポートは内部のみ）
- **アクセス方法**: AWS Systems Manager Session Manager経由のみ
- **配置**: プライベートサブネットのみ（パブリックIPなし）

## 🔧 前提条件

### 1. AWS環境
- 適切なIAM権限を持つAWSアカウント
- AWS CLIの設定完了
- EC2インスタンスへのSSMアクセス権限

### 2. 必要なIAM権限
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
        "ssm:DescribeInstanceInformation",
        "ec2:DescribeInstances"
      ],
      "Resource": "*"
    }
  ]
}
```

## 🚀 SSM Session Manager プラグインのインストール

### Windows

#### 方法1: MSIインストーラー（推奨）
```powershell
# PowerShellを管理者権限で実行
# Session Manager プラグインをダウンロード
Invoke-WebRequest -Uri "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe" -OutFile "$env:TEMP\SessionManagerPluginSetup.exe"

# インストール実行
Start-Process -FilePath "$env:TEMP\SessionManagerPluginSetup.exe" -Wait
```

#### 方法2: 手動ダウンロード
1. [AWS Session Manager Plugin for Windows](https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe) をダウンロード
2. ダウンロードした `SessionManagerPluginSetup.exe` を実行
3. インストールウィザードに従ってインストール

#### インストール確認
```cmd
# コマンドプロンプトまたはPowerShellで確認
session-manager-plugin --version
```

### Linux (Ubuntu/Debian)

#### Ubuntu/Debian系
```bash
# Session Manager プラグインをダウンロード
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"

# インストール実行
sudo dpkg -i session-manager-plugin.deb

# 依存関係の解決（必要に応じて）
sudo apt-get install -f
```

#### Red Hat/CentOS/Amazon Linux系
```bash
# Session Manager プラグインをダウンロード
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"

# インストール実行
sudo yum install -y session-manager-plugin.rpm
# または
sudo rpm -i session-manager-plugin.rpm
```

#### 汎用Linux（バイナリ直接インストール）
```bash
# Session Manager プラグインをダウンロード・展開
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.tar.gz" -o "session-manager-plugin.tar.gz"
tar xzf session-manager-plugin.tar.gz

# インストール
sudo mkdir -p /usr/local/sessionmanagerplugin/bin
sudo mv session-manager-plugin/session-manager-plugin /usr/local/sessionmanagerplugin/bin/
sudo ln -s /usr/local/sessionmanagerplugin/bin/session-manager-plugin /usr/local/bin/session-manager-plugin
```

#### インストール確認
```bash
# バージョン確認
session-manager-plugin --version
```

### macOS

#### Homebrewを使用（推奨）
```bash
# Homebrewでインストール
brew install --cask session-manager-plugin
```

#### 手動インストール
```bash
# Session Manager プラグインをダウンロード・展開
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/sessionmanager-bundle.zip" -o "sessionmanager-bundle.zip"
unzip sessionmanager-bundle.zip

# インストール実行
sudo ./sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
```

## 🔍 EC2インスタンス情報の確認

### ⚠️ コマンドのコピー&ペースト時の注意

**1行版のコマンドを推奨**: バックスラッシュ（\）による行継続は環境によって正しく動作しない場合があります。確実に実行するには **1行版のコマンド** を使用してください。

**エラー例**:
```bash
# このようなエラーが出る場合
Unknown options: 
```
→ 1行版のコマンドを使用するか、手動で1行につなげて実行してください。

### 1. EC2インスタンス一覧取得
```bash
# POC環境のEC2インスタンス一覧（1行版 - コピー&ペーストしやすい）
aws ec2 describe-instances --filters "Name=tag:Environment,Values=poc" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],Tags[?Key==`Hostname`].Value|[0],PrivateIpAddress,AvailabilityZone]' --output table --region ap-northeast-1

# 複数行版（見やすい形式）
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=poc" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],Tags[?Key==`Hostname`].Value|[0],PrivateIpAddress,AvailabilityZone]' \
  --output table \
  --region ap-northeast-1
```

期待される出力例：
```
+----------------------+-------------+-------------+--------------+--------+
|  i-0087ca3577656cc54 |  pochub-001 |  pochub-001 |  10.0.11.7   |  None  |
|  i-0a9bee4001b26d53b |  pochub-002 |  pochub-002 |  10.0.12.23  |  None  |
|  i-088edda230d2b8410 |  pochub-003 |  pochub-003 |  10.0.13.220 |  None  |
+----------------------+-------------+-------------+--------------+--------+
```

### 2. SSM接続可能性確認
```bash
# Session Manager接続可能なインスタンス確認（1行版）
aws ssm describe-instance-information --filters "Key=ResourceType,Values=EC2Instance" --query 'InstanceInformationList[].[InstanceId,PingStatus,PlatformType,PlatformName]' --output table --region ap-northeast-1

# 複数行版（見やすい形式）
aws ssm describe-instance-information \
  --filters "Key=ResourceType,Values=EC2Instance" \
  --query 'InstanceInformationList[].[InstanceId,PingStatus,PlatformType,PlatformName]' \
  --output table \
  --region ap-northeast-1
```

期待される出力例：
```
+----------------------+---------+--------+----------------+
|  i-088edda230d2b8410 |  Online |  Linux |  Amazon Linux  |
|  i-0a9bee4001b26d53b |  Online |  Linux |  Amazon Linux  |
|  i-0087ca3577656cc54 |  Online |  Linux |  Amazon Linux  |
+----------------------+---------+--------+----------------+
```

## 💻 EC2インスタンスへの接続

### 基本的な接続方法

#### 特定のインスタンスに接続
```bash
# pochub-001 に接続する場合
aws ssm start-session \
  --target i-0087ca3577656cc54 \
  --region ap-northeast-1

# pochub-002 に接続する場合
aws ssm start-session \
  --target i-0a9bee4001b26d53b \
  --region ap-northeast-1

# pochub-003 に接続する場合  
aws ssm start-session \
  --target i-088edda230d2b8410 \
  --region ap-northeast-1
```

#### 動的にインスタンスIDを取得して接続
```bash
# pochub-001 のインスタンスIDを動的取得して接続（1行版）
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Hostname,Values=pochub-001" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].InstanceId' --output text --region ap-northeast-1) && aws ssm start-session --target $INSTANCE_ID --region ap-northeast-1

# 複数行版（見やすい形式）
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Hostname,Values=pochub-001" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text \
  --region ap-northeast-1)

aws ssm start-session --target $INSTANCE_ID --region ap-northeast-1
```

### セッション中の操作

#### 基本的な情報確認
```bash
# ホスト名確認
hostname

# システム情報確認
uname -a

# ディスク使用量確認
df -h

# メモリ使用量確認
free -h

# CPU情報確認
cat /proc/cpuinfo | head -20
```

#### ログファイルの確認
```bash
# システムログ確認
sudo journalctl -f

# ホスト名設定ログ確認
sudo cat /var/log/hostname-setup.log

# CloudWatch Agent ログ確認
sudo cat /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

#### SSM関連の確認
```bash
# SSM Agent ステータス確認
sudo systemctl status amazon-ssm-agent

# SSM Agent ログ確認
sudo journalctl -u amazon-ssm-agent -f
```

### セッションの終了
```bash
# セッション終了
exit
# または Ctrl+D
```

## 🛠️ トラブルシューティング

### 1. 接続できない場合

#### Session Manager プラグインが見つからない
```bash
# エラー例
SessionManagerPlugin is not found. Please refer to SessionManager Documentation here: http://docs.aws.amazon.com/console/systems-manager/session-manager-plugin-not-found
```

**解決策**: 
- Session Manager プラグインを正しくインストールする
- PATHが正しく設定されているか確認

#### インスタンスがオフライン状態
```bash
# SSM Agent ステータス確認
aws ssm describe-instance-information \
  --instance-information-filter-list "key=InstanceIds,valueSet=i-xxxxxxxxxxxxxxxxx" \
  --region ap-northeast-1
```

**解決策**:
- EC2インスタンスが起動しているか確認
- SSM Agent が正常に動作しているか確認
- IAMロールが正しく設定されているか確認

#### 権限不足エラー
```bash
# エラー例
An error occurred (AccessDeniedException) when calling the StartSession operation: User: arn:aws:iam::xxxxxxxxxxxx:user/username is not authorized to perform: ssm:StartSession on resource: arn:aws:ec2:region:xxxxxxxxxxxx:instance/i-xxxxxxxxxxxxxxxxx
```

**解決策**:
- IAM権限を確認し、必要な権限を付与
- Session Manager に必要な権限を参照

### 2. セッション中の問題

#### 応答が遅い場合
- ネットワーク接続を確認
- EC2インスタンスのCPU/メモリ使用率を確認

#### セッションが切断される場合
- 一定時間操作しない場合の自動切断は正常動作
- 必要に応じて再接続

## 📚 関連リソース

### AWS公式ドキュメント
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [Session Manager プラグインのインストール](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
- [Session Manager の前提条件](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-prerequisites.html)

### セキュリティ
- **Session Manager の利点**: 
  - SSHキーの管理不要
  - 踏み台サーバー不要
  - 全てのセッションがCloudTrailでログ記録
  - IAMによる詳細なアクセス制御

### コスト
- **Session Manager 使用料**: 無料
- **データ転送料**: 通常のAWSデータ転送料金が適用

---

**作成日**: 2025年10月14日  
**対象環境**: POC環境  
**対象リージョン**: ap-northeast-1  
**対象OS**: Windows, Linux, macOS
