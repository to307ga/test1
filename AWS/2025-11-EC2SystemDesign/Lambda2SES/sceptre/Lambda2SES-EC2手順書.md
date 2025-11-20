# Lambda EC2 to Email デプロイ手順

## 概要

**任意のEC2インスタンス**からSSM経由で**任意のファイル内容**を取得し、SES経由でメール送信するLambda関数のデプロイ手順です。

**特徴:**
- 🔄 **汎用性**: 任意のEC2インスタンスID・ファイルパスを指定可能
- 🎯 **デフォルト値**: 環境変数でデフォルトのインスタンスIDとファイルパスを設定
- ⚡ **柔軟性**: Lambda実行時にパラメータで上書き可能
- 🔒 **セキュリティ**: IAMポリシーでアカウント内の全EC2インスタンスにアクセス可能

## アーキテクチャ

```
Lambda Function (Python 3.12)
    ↓ (SSM SendCommand)
Any EC2 Instance (指定されたID or デフォルト: i-0297dec34ad7ea77b)
    ↓ (read file: 指定されたパス or デフォルト: /tmp/aaa)
Lambda Function
    ↓ (SES SendEmail)
Email Recipient
```

**パラメータの優先順位:**
1. Lambda実行時のeventパラメータ（最優先）
2. 環境変数（DEFAULT_INSTANCE_ID, DEFAULT_FILE_PATH）
3. コード内のハードコードされたデフォルト値

## 前提条件

1. **EC2インスタンスがSSM管理下にあること**
   - SSM Agentがインストールされている
   - IAMロールに `AmazonSSMManagedInstanceCore` ポリシーがアタッチされている

2. **SESメールアドレスが検証済みであること**
   - 送信元メールアドレスが検証済み
   - 宛先メールアドレスが検証済み（Sandboxの場合）

## デプロイ手順

### 1. Lambda関数コードのパッケージ化

```bash
cd c:/Temp/aws-templates-idhub/draft/2025-11-EC2SystemDesign/Lambda2SES/sceptre

# Zipファイル作成
zip lambda-ec2-to-email.zip lambda_ec2_to_email.py
```

### 2. S3バケットへアップロード

```bash
# S3バケット名を確認
aws s3 ls | grep poc-lambda-code

# アップロード
aws s3 cp lambda-ec2-to-email.zip s3://poc-lambda-code-bucket-XXXXX/
```

### 3. Sceptreでデプロイ

```bash
cd c:/Temp/aws-templates-idhub/draft/2025-11-EC2SystemDesign/Lambda2SES/sceptre

# IAMポリシーをデプロイ
uv run sceptre launch poc/iam-policy-ec2-ssm.yaml --yes

# IAMロールをデプロイ
uv run sceptre launch poc/iam-role-ec2-ssm.yaml --yes

# Lambda関数をデプロイ
uv run sceptre launch poc/lambda-ec2-to-email.yaml --yes
```

### 4. テストイベント作成

#### パターン1: デフォルト値を使用（環境変数から取得）

`test-event-ec2-default.json`:
```json
{
  "email_source": "sender@example.com",
  "email_destination": "recipient@example.com",
  "email_subject": "デフォルトEC2のファイル内容"
}
```
→ インスタンスID: `i-0297dec34ad7ea77b`（環境変数）、ファイルパス: `/tmp/aaa`（環境変数）

#### パターン2: 特定のファイルを指定

`test-event-ec2.json`:
```json
{
  "instance_id": "i-0297dec34ad7ea77b",
  "file_path": "/var/log/httpd/error_log",
  "email_source": "sender@example.com",
  "email_destination": "recipient@example.com",
  "email_subject": "Apache Error Log from pochub-002"
}
```
→ pochub-002のApache error_logを取得

#### パターン3: 別のインスタンスを指定

`test-event-ec2-multiple.json`:
```json
{
  "instance_id": "i-0134c94a753025b8b",
  "file_path": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log",
  "email_source": "sender@example.com",
  "email_destination": "recipient@example.com",
  "email_subject": "CloudWatch Agent Log from pochub-001"
}
```
→ pochub-001のCloudWatch Agentログを取得

### 5. Lambda関数テスト

#### AWS CLI経由

**デフォルト値を使用:**
```bash
aws lambda invoke \
  --function-name poc-ec2-to-email \
  --payload file://test-event-ec2-default.json \
  --region ap-northeast-1 \
  response-ec2-default.json
```

**特定のファイルを指定:**
```bash
aws lambda invoke \
  --function-name poc-ec2-to-email \
  --payload file://test-event-ec2.json \
  --region ap-northeast-1 \
  response-ec2.json
```

**別のインスタンスを指定:**
```bash
aws lambda invoke \
  --function-name poc-ec2-to-email \
  --payload file://test-event-ec2-multiple.json \
  --region ap-northeast-1 \
  response-ec2-multiple.json

# レスポンス確認
cat response-ec2-default.json
cat response-ec2.json
cat response-ec2-multiple.json
```

#### AWSコンソール経由

1. Lambda > 関数 > `poc-ec2-to-email`
2. 「テスト」タブ
3. 新しいイベントを作成（`test-event-ec2.json`の内容をコピー）
4. 「テスト」ボタンをクリック

## EC2インスタンス上の準備

Lambda関数をテストする前に、EC2インスタンス上でテストファイルを作成してください:

```bash
# EC2インスタンスにSSM Session Manager経由で接続
aws ssm start-session --target i-0297dec34ad7ea77b --region ap-northeast-1

# テストファイル作成
sudo sh -c 'echo "This is a test file from EC2 instance" > /tmp/aaa'
sudo sh -c 'echo "Instance ID: i-0297dec34ad7ea77b" >> /tmp/aaa'
sudo sh -c 'echo "Timestamp: $(date)" >> /tmp/aaa'
sudo sh -c 'echo "CloudWatch Logs Agent Status:" >> /tmp/aaa'
sudo systemctl status amazon-cloudwatch-agent --no-pager >> /tmp/aaa 2>&1

# ファイル確認
cat /tmp/aaa

# パーミッション設定
sudo chmod 644 /tmp/aaa
```

## IAMポリシー詳細

`poc-lambda-ec2-ssm-policy` には以下の権限が含まれます:

- **SSM権限（任意のEC2インスタンスにアクセス）**:
  - `ssm:SendCommand` - 任意のEC2インスタンスへコマンド送信
  - `ssm:GetCommandInvocation` - コマンド実行結果取得
  - `ssm:ListCommandInvocations` - コマンド実行履歴取得
  - `ssm:DescribeInstanceInformation` - インスタンス情報取得
  - **対象**: `arn:aws:ec2:region:account:instance/*` (全インスタンス)

- **EC2権限**:
  - `ec2:DescribeInstances` - インスタンス情報取得
  - `ec2:DescribeInstanceStatus` - インスタンスステータス取得

- **SES権限**:
  - `ses:SendEmail` - メール送信
  - `ses:SendRawEmail` - RAWメール送信

- **CloudWatch Logs権限**:
  - `logs:CreateLogGroup` - ロググループ作成
  - `logs:CreateLogStream` - ログストリーム作成
  - `logs:PutLogEvents` - ログイベント送信

## トラブルシューティング

### 1. SSM Command Failed

**エラー**: `Command Failed: /bin/bash: line 1: /tmp/aaa: Permission denied`

**対処**:
```bash
# EC2インスタンス上でファイルパーミッション確認
ls -la /tmp/aaa

# 読み取り権限付与
sudo chmod 644 /tmp/aaa
```

### 2. SSM Command Timed Out

**エラー**: `Command timed out after 10 attempts`

**対処**:
- EC2インスタンスのSSM Agent状態確認:
  ```bash
  sudo systemctl status amazon-ssm-agent
  ```
- IAMロールに `AmazonSSMManagedInstanceCore` がアタッチされているか確認

### 3. SES Email Sending Failed

**エラー**: `MessageRejected: Email address is not verified`

**対処**:
- SESコンソールで送信元メールアドレスを検証
- Sandbox環境の場合は宛先メールアドレスも検証

### 4. Lambda Timeout

**エラー**: `Task timed out after 60.00 seconds`

**対処**:
- Lambda関数のタイムアウト設定を延長（60秒 → 120秒）
- SSMコマンドのタイムアウト設定を調整

## コスト試算

| サービス | 使用量 | 単価 | 月額コスト |
|---------|--------|------|-----------|
| Lambda実行 | 100回/月 × 60秒 | $0.0000166667/GB-秒 | $0.025 |
| Lambda リクエスト | 100回/月 | $0.20/100万リクエスト | $0.00002 |
| SSM SendCommand | 100回/月 | 無料 | $0.00 |
| SES送信 | 100通/月 | $0.10/1000通 | $0.01 |
| **合計** | - | - | **$0.035/月** |

## セキュリティ考慮事項

1. **最小権限の原則**:
   - IAMポリシーでEC2インスタンスIDを特定
   - 必要最小限の権限のみ付与

2. **機密情報の保護**:
   - `/tmp/aaa`に機密情報を含めない
   - 必要に応じてファイル内容を暗号化

3. **監査ログ**:
   - CloudWatch Logsで全Lambda実行を記録
   - SSMコマンド履歴をCloudTrailで追跡

4. **メール通知の制限**:
   - SES Sandboxから本番環境への移行を検討
   - SPF/DKIM/DMARC設定でなりすまし防止

## 次のステップ

### 1. 複数インスタンスの一括処理

現在は1インスタンス1ファイルですが、以下のように拡張可能:

```json
{
  "instances": [
    {
      "instance_id": "i-0134c94a753025b8b",
      "file_path": "/var/log/httpd/error_log"
    },
    {
      "instance_id": "i-0297dec34ad7ea77b",
      "file_path": "/var/log/httpd/error_log"
    },
    {
      "instance_id": "i-0f464ba83118e3114",
      "file_path": "/var/log/httpd/error_log"
    }
  ],
  "email_source": "sender@example.com",
  "email_destination": "recipient@example.com",
  "email_subject": "All Apache Error Logs"
}
```

### 2. RDS接続対応
   - Lambda関数をVPC内に配置
   - RDSセキュリティグループ設定
   - クエリ結果をメール送信

2. **定期実行**:
   - EventBridge Ruleで定期実行
   - 日次レポート自動送信

3. **複数インスタンス対応**:
   - インスタンスIDリストをパラメータ化
   - 並行実行でパフォーマンス向上

4. **エラー通知の強化**:
   - SNS Topicへエラー通知
   - Slackへアラート送信
