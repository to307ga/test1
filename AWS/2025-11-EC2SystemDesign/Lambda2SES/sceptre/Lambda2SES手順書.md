# Lambda→SES メール送信スタック デプロイ手順書

## 概要

このドキュメントは、Lambda関数からAWS SESを経由してメール送信を行うためのインフラストラクチャをSceptreでデプロイする手順を記載しています。

## アーキテクチャ構成

```
┌─────────────────┐
│  S3 Bucket      │  ← Lambdaコード格納
│  poc-lambda-    │
│  code-{Account} │
└─────────────────┘
         ↑
         │
┌─────────────────┐     ┌──────────────┐
│  Lambda Function│────→│  SES Service │
│  poc-ses-send-  │     │              │
│  email          │     └──────────────┘
└─────────────────┘
         ↓
    ┌────────────┐
    │ IAM Role   │
    │ poc-lambda-│
    │ ses-role   │
    └────────────┘
         ↓
    ┌────────────┐
    │ IAM Policy │
    │ poc-ses-   │
    │ send-policy│
    └────────────┘
```

## デプロイするリソース

| スタック名 | リソースタイプ | リソース名 | 説明 |
|-----------|--------------|-----------|------|
| poc/s3-bucket | S3 Bucket | poc-lambda-code-{AccountId} | Lambda関数コードの格納バケット |
| poc/iam-policy | IAM Managed Policy | poc-ses-send-policy | SESメール送信権限ポリシー |
| poc/iam-role | IAM Role | poc-lambda-ses-role | Lambda実行ロール |
| poc/lambda-function | Lambda Function | poc-ses-send-email | メール送信Lambda関数 |

## 依存関係

```
s3-bucket (独立)
    ↓
iam-policy (独立)
    ↓
iam-role (iam-policyに依存)
    ↓
lambda-function (iam-role, s3-bucketに依存)
```

## 前提条件

### 必要なツール
- Python 3.12以上
- uv (Pythonパッケージマネージャー)
- AWS CLI v2
- 適切なAWS認証情報（profile: default）

### AWS権限
以下の操作権限が必要：
- S3: CreateBucket, PutBucketVersioning, PutBucketPublicAccessBlock
- IAM: CreatePolicy, CreateRole, AttachRolePolicy
- Lambda: CreateFunction, UpdateFunctionCode
- SES: SendEmail権限（実行時）

### ディレクトリ構成確認
```bash
cd /home/t-tomonaga/AWS/AWS_POC/poc/temp
tree -L 3
```

期待される構成：
```
temp/
├── config/
│   └── poc/
│       ├── config.yaml
│       ├── s3-bucket.yaml
│       ├── iam-policy.yaml
│       ├── iam-role.yaml
│       └── lambda-function.yaml
└── templates/
    ├── s3-bucket.yaml
    ├── iam-policy.yaml
    ├── iam-role.yaml
    └── lambda-function.yaml
```

## デプロイ手順

### 1. 作業ディレクトリへ移動
```bash
cd /home/t-tomonaga/AWS/AWS_POC/poc/temp
```

### 2. 設定確認
```bash
# config.yamlの確認
cat config/poc/config.yaml

# 期待される内容:
# project_code: poc
# region: ap-northeast-1
# profile: default
```

### 3. テンプレート検証（Dry Run）

#### 3.1 S3バケット（依存なし）
```bash
uv run sceptre validate poc/s3-bucket.yaml
```

#### 3.2 IAMポリシー（依存なし）
```bash
uv run sceptre validate poc/iam-policy.yaml
```

**注意:** IAMロールとLambda関数は依存スタックが未作成のため、この段階では検証エラーになります。S3バケットとIAMポリシーの検証のみ実施してください。

### 4. スタックデプロイ（順序重要）

#### 4.1 S3バケット作成
```bash
uv run sceptre create poc/s3-bucket.yaml --yes
```

**確認コマンド:**
```bash
aws s3 ls | grep poc-lambda-code
```

#### 4.2 IAMポリシー作成
```bash
uv run sceptre create poc/iam-policy.yaml --yes
```

**確認コマンド:**
```bash
uv run sceptre list outputs poc/iam-policy.yaml
```

#### 4.3 IAMロール作成
```bash
uv run sceptre create poc/iam-role.yaml --yes
```

**確認コマンド:**
```bash
uv run sceptre list outputs poc/iam-role.yaml
```

#### 4.4 Lambda関数作成

**注意:** Lambda関数をデプロイする前に、関数コードをS3にアップロードする必要があります。

```bash
# サンプルLambda関数コードを作成
cat > lambda_function.py << 'EOF'
import json
import boto3

ses_client = boto3.client('ses', region_name='ap-northeast-1')

def lambda_handler(event, context):
    """
    SES経由でメール送信を行うLambda関数
    
    event形式:
    {
        "source": "sender@example.com",
        "destination": "recipient@example.com",
        "subject": "Lambdaからの送信テスト",
        "body": "届いていればテスト成功"
    }
    """
    try:
        response = ses_client.send_email(
            Source=event['source'],
            Destination={
                'ToAddresses': [event['destination']]
            },
            Message={
                'Subject': {
                    'Data': event['subject'],
                    'Charset': 'UTF-8'
                },
                'Body': {
                    'Text': {
                        'Data': event['body'],
                        'Charset': 'UTF-8'
                    }
                }
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Email sent successfully',
                'messageId': response['MessageId']
            })
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Failed to send email',
                'error': str(e)
            })
        }
EOF

# Lambda関数コードをZIP化
zip lambda-function.zip lambda_function.py

# S3にアップロード
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 cp lambda-function.zip s3://poc-lambda-code-${ACCOUNT_ID}/lambda-function.zip
```

**Lambda関数デプロイ:**
```bash
uv run sceptre create poc/lambda-function.yaml --yes
```

**確認コマンド:**
```bash
uv run sceptre list outputs poc/lambda-function.yaml
```

### 5. 一括デプロイ（全スタック順次作成）

全スタックを順次デプロイする場合（Lambdaコードを事前にS3にアップロード後）：

```bash
uv run sceptre create poc/s3-bucket.yaml --yes && \
uv run sceptre create poc/iam-policy.yaml --yes && \
uv run sceptre create poc/iam-role.yaml --yes && \
uv run sceptre create poc/lambda-function.yaml --yes
```

## デプロイ後の確認

### スタック一覧表示
```bash
uv run sceptre list outputs poc/s3-bucket.yaml
uv run sceptre list outputs poc/iam-policy.yaml
uv run sceptre list outputs poc/iam-role.yaml
uv run sceptre list outputs poc/lambda-function.yaml
```

### エクスポート値確認
```bash
aws cloudformation list-exports | jq -r '.Exports[] | select(.Name | startswith("poc-")) | {Name, Value}'
```

期待されるエクスポート：
- `poc-lambda-code-bucket`: S3バケット名
- `poc-ses-policy-arn`: IAMポリシーARN
- `poc-lambda-role-arn`: IAMロールARN
- `poc-lambda-function-arn`: Lambda関数ARN
- `poc-lambda-function-name`: Lambda関数名

## Lambda関数のテスト

### 前提: SES検証済みドメイン/メールアドレス

本番環境では検証済みドメイン（例: goo.ne.jp）から任意のメールアドレスへ送信可能です。

```bash
# 検証済みID一覧の確認
aws sesv2 list-email-identities

# 特定IDの詳細確認
aws sesv2 get-email-identity --email-identity goo.ne.jp
```

### Lambda関数の手動テスト

```bash
# テストイベント作成
cat > test-event.json << 'EOF'
{
  "source": "noreply@goo.ne.jp",
  "destination": "toshimitsu.tomonaga.zd@s1.nttdocomo.com",
  "subject": "Lambda-SES テストメール",
  "body": "これはLambda関数からSES経由で送信されたテストメールです。\n\n送信日時: 2025年11月17日\n環境: POC\nドメイン: goo.ne.jp (検証済み)"
}
EOF

# Lambda関数実行
aws lambda invoke \
  --function-name poc-ses-send-email \
  --payload file://test-event.json \
  --cli-binary-format raw-in-base64-out \
  response.json

# 実行結果確認
echo "=== Lambda Response ===" && cat response.json | jq .
```

**期待される成功レスポンス:**
```json
{
  "StatusCode": 200,
  "ExecutedVersion": "$LATEST"
}
{
  "statusCode": 200,
  "body": "{\"message\": \"Email sent successfully\", \"messageId\": \"0106019a8f896cad-...-000000\"}"
}
```

### Lambda実行ログ確認

```bash
# 直近5分のログを表示（推奨）
aws logs tail /aws/lambda/poc-ses-send-email --since 5m --format short

# または最新のログストリーム取得
LOG_STREAM=$(aws logs describe-log-streams \
  --log-group-name /aws/lambda/poc-ses-send-email \
  --order-by LastEventTime \
  --descending \
  --max-items 1 \
  --query 'logStreams[0].logStreamName' \
  --output text)

# ログ表示
aws logs get-log-events \
  --log-group-name /aws/lambda/poc-ses-send-email \
  --log-stream-name "${LOG_STREAM}" \
  --limit 50 | jq -r '.events[].message'
```

## トラブルシューティング

### エラー: スタック作成失敗

#### 1. Export名の重複エラー
```
Export poc-lambda-code-bucket already exists
```

**原因:** 同じExport名のスタックが既に存在  
**対処:** 既存スタックを削除するか、ProjectNameパラメータを変更

```bash
# 既存スタック確認
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE | jq -r '.StackSummaries[].StackName'

# スタック削除
uv run sceptre delete poc/lambda-function.yaml --yes
uv run sceptre delete poc/iam-role.yaml --yes
uv run sceptre delete poc/iam-policy.yaml --yes
uv run sceptre delete poc/s3-bucket.yaml --yes
```

#### 2. Lambda関数コードが見つからない
```
Error: Could not find S3 object
```

**原因:** lambda-function.zipがS3にアップロードされていない  
**対処:** 手順4.4のLambdaコードアップロードを実行

#### 3. IAMポリシーのインポートエラー
```
Error: No export named poc-ses-policy-arn found
```

**原因:** iam-policyスタックがデプロイされていない  
**対処:** 依存関係の順序でデプロイ

```bash
uv run sceptre create poc/iam-policy.yaml --yes
uv run sceptre create poc/iam-role.yaml --yes
```

### エラー: SES送信失敗

#### 1. メールアドレス/ドメイン未検証
```
Error: Email address is not verified
```

**対処:** 送信元ドメインまたはメールアドレスがSESで検証されているか確認
```bash
# 検証済みID一覧
aws sesv2 list-email-identities

# ドメイン検証の詳細
aws sesv2 get-email-identity --email-identity your-domain.com
```

#### 2. サンドボックス制限
```
Error: Daily sending quota exceeded
```

**対処:** 本番環境への移行申請、またはクォータ増加リクエスト

#### 3. IAM権限不足
```
Error: User is not authorized to perform: ses:SendEmail
```

**対処:** IAMポリシーの権限確認とロールの再デプロイ

## スタック削除手順

**重要:** 依存関係の逆順で削除すること

```bash
# 1. Lambda関数削除
uv run sceptre delete poc/lambda-function.yaml --yes

# 2. IAMロール削除
uv run sceptre delete poc/iam-role.yaml --yes

# 3. IAMポリシー削除
uv run sceptre delete poc/iam-policy.yaml --yes

# 4. S3バケット削除（注意: バケット内のオブジェクトを先に削除）
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 rm s3://poc-lambda-code-${ACCOUNT_ID} --recursive
uv run sceptre delete poc/s3-bucket.yaml --yes
```

## 参考情報

### Sceptreコマンド一覧

| コマンド | 説明 |
|---------|------|
| `sceptre validate` | テンプレート検証 |
| `sceptre create` | スタック作成 |
| `sceptre update` | スタック更新 |
| `sceptre delete` | スタック削除 |
| `sceptre list outputs` | スタック出力表示 |
| `sceptre describe` | スタック詳細表示 |
| `sceptre status` | スタックステータス確認 |

### AWS CLIコマンド参考

```bash
# CloudFormationスタック一覧
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE

# Export一覧
aws cloudformation list-exports

# Lambda関数一覧
aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `poc-`)].FunctionName'

# S3バケット一覧
aws s3 ls | grep poc-lambda-code

# IAMロール詳細
aws iam get-role --role-name poc-lambda-ses-role

# IAMポリシー詳細
aws iam get-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/poc-ses-send-policy
```

## 次のステップ

1. **SES本番環境への移行**: サンドボックスを解除し、任意のメールアドレスへの送信を有効化
2. **Lambda関数の改善**: エラーハンドリング、リトライロジック、テンプレート機能の追加
3. **モニタリング**: CloudWatch Alarms設定、SESバウンス/苦情通知の設定
4. **セキュリティ**: Lambda関数の環境変数暗号化、VPC内配置の検討
5. **sceptreディレクトリへの統合**: 本番運用時は temp/ から sceptre/ へ移動

---

**作成日**: 2025年11月17日  
**更新日**: 2025年11月17日  
**バージョン**: 1.0
