# NTT DOCOMO SES Migration 2テナント構成

## 構成方針
- **開発テナント**: 専用アカウントで開発・テスト・検証
- **本番テナント**: 専用アカウントで本番サービス運用
- アカウント完全分離によるセキュリティ・コスト管理

## 現在の構成
- マスターアカウント: 362791529013 (Organizations)
- 現在のアカウント: 007773581311 (開発テナント or 本番テナント?)

## 推奨アカウント構成
```
NTT DOCOMO AWS Organization
├── 管理アカウント: 362791529013 (Organizations Master)
├── 開発テナント: XXXXXXXXXXXX (Development Account)
└── 本番テナント: YYYYYYYYYYYY (Production Account)
```

## 推奨プロファイル設定

### ~/.aws/config
```ini
[default]
region = ap-northeast-1

# 中央管理アカウント (デプロイ実行元)
[profile central-management]
region = ap-northeast-1
# 現在のIAMユーザー: nttdocomo-iam-tomonaga

# 開発テナント (専用アカウント)
[profile development-tenant]
role_arn = arn:aws:iam::DEVELOPMENT_ACCOUNT_ID:role/SES-Migration-DeploymentRole
source_profile = central-management
region = ap-northeast-1

# 本番テナント (専用アカウント)
[profile production-tenant]
role_arn = arn:aws:iam::PRODUCTION_ACCOUNT_ID:role/SES-Migration-DeploymentRole
source_profile = central-management
region = ap-northeast-1
```

### ~/.aws/credentials (既存の認証情報)
```ini
[central-management]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

## Cross-Account Role設定例

### 1. 各テナント用のデプロイメントロール作成
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::362791529013:user/nttdocomo-iam-tomonaga"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "SES-Migration-Deploy-2025"
        }
      }
    }
  ]
}
```

### 2. 各テナントで作成するロール
- **開発テナント**: `SES-Migration-DeploymentRole`
- **本番テナント**: `SES-Migration-DeploymentRole`

### 3. ロールにアタッチするポリシー
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "s3:*",
        "ses:*",
        "iam:*",
        "cloudwatch:*",
        "kinesisfirehose:*",
        "lambda:*",
        "logs:*",
        "kms:*",
        "sns:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Sceptreコマンド例

```bash
# 開発テナントに切り替え
export AWS_PROFILE=development-tenant

# 開発テナントのインフラをデプロイ
sceptre create config/development/base.yaml
sceptre create config/development/ses.yaml
sceptre create config/development/enhanced-kinesis.yaml
sceptre create config/development/monitoring.yaml
sceptre create config/development/security.yaml

# 本番テナントに切り替え
export AWS_PROFILE=production-tenant

# 本番テナントのインフラをデプロイ
sceptre create config/production/base.yaml
sceptre create config/production/ses.yaml
sceptre create config/production/enhanced-kinesis.yaml
sceptre create config/production/monitoring.yaml
sceptre create config/production/security.yaml

# 現在のテナントを確認
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}'

# 全スタックの一括デプロイ (開発テナント)
AWS_PROFILE=development-tenant sceptre create config/development/

# 全スタックの一括デプロイ (本番テナント)
AWS_PROFILE=production-tenant sceptre create config/production/
```

## 現在の環境からの移行手順

### 現在の状況
```
現在のディレクトリ構造:
sceptre/config/
├── dev/     # 現在の開発環境設定
└── prod/    # 現在の本番環境設定
```

### Step 1: ディレクトリ再構成
```bash
cd sceptre/config/

# 新しいテナント用ディレクトリを作成
mkdir development production shared

# 現在の設定を新しい構造に移動
cp -r dev/* development/
cp -r prod/* production/

# 共通設定の作成
cp prod/config.yaml shared/config.yaml
```

### Step 2: 設定ファイルの修正
```bash
# development/config.yaml の修正
sed -i 's/environment: dev/environment: development/' development/config.yaml

# production/config.yaml の修正
sed -i 's/environment: prod/environment: production/' production/config.yaml
```

### Step 3: AWS Profile設定
```bash
# ~/.aws/config に追加
cat >> ~/.aws/config << EOF

[profile development-tenant]
role_arn = arn:aws:iam::007773581311:role/SES-Migration-DeploymentRole
source_profile = central-management
region = ap-northeast-1

[profile production-tenant]
role_arn = arn:aws:iam::007773581311:role/SES-Migration-DeploymentRole
source_profile = central-management
region = ap-northeast-1
EOF
```

### Step 4: 動作確認
```bash
# 開発テナント
export AWS_PROFILE=development-tenant
sceptre list stacks config/development/

# 本番テナント
export AWS_PROFILE=production-tenant
sceptre list stacks config/production/
```

## 運用フロー

### 1. 開発フェーズ
```bash
# 開発テナントでの作業
export AWS_PROFILE=development-tenant
sceptre create config/development/
# テスト・検証実行
```

### 2. 本番デプロイフェーズ
```bash
# 本番テナントでのデプロイ
export AWS_PROFILE=production-tenant
sceptre create config/production/
# 本番サービス開始
```

### 3. 日常運用
```bash
# 開発テナント: 新機能開発・検証
AWS_PROFILE=development-tenant sceptre update config/development/

# 本番テナント: 安定運用・必要時のみ更新
AWS_PROFILE=production-tenant sceptre update config/production/
```
