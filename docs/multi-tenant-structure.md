# NTT DOCOMO SES Migration マルチテナント構成

## 実装方針
- **開発用アカウント**: 開発・テスト・検証用
- **本番用アカウント**: 本番運用専用
- 各アカウントで完全に分離されたインフラを構築

## 推奨ディレクトリ構造

```
sceptre/
├── config/
│   ├── shared/                    # 両テナント共通設定
│   │   ├── config.yaml
│   │   └── security.yaml
│   │
│   ├── development/               # 開発用テナント（専用アカウント）
│   │   ├── config.yaml           # 開発アカウント設定
│   │   ├── base.yaml
│   │   ├── ses.yaml
│   │   ├── enhanced-kinesis.yaml
│   │   ├── monitoring.yaml
│   │   └── security.yaml
│   │
│   ├── production/                # 本番用テナント（専用アカウント）
│   │   ├── config.yaml           # 本番アカウント設定
│   │   ├── base.yaml
│   │   ├── ses.yaml
│   │   ├── enhanced-kinesis.yaml
│   │   ├── monitoring.yaml
│   │   └── security.yaml
│   │
│   └── management/                # 管理・監査（必要に応じて）
│       ├── security-hub.yaml
│       └── cloudtrail.yaml
│
├── templates/
│   ├── base.yaml                 # 基盤インフラテンプレート
│   ├── ses.yaml                  # SES設定テンプレート
│   ├── enhanced-kinesis.yaml     # データパイプライン
│   ├── monitoring.yaml           # 監視設定
│   └── security.yaml             # セキュリティ設定
│
└── scripts/
    ├── switch-tenant.sh          # テナント切り替えスクリプト
    ├── deploy-development.sh     # 開発環境デプロイ
    └── deploy-production.sh      # 本番環境デプロイ
```

## アカウント切り替え方法

### 1. AWS CLI Profile 設定
```bash
# ~/.aws/config
[profile development-tenant]
role_arn = arn:aws:iam::DEVELOPMENT_ACCOUNT_ID:role/SES-Migration-DeploymentRole
source_profile = central-management
region = ap-northeast-1

[profile production-tenant]
role_arn = arn:aws:iam::PRODUCTION_ACCOUNT_ID:role/SES-Migration-DeploymentRole
source_profile = central-management
region = ap-northeast-1

[profile central-management]
region = ap-northeast-1
# 現在のIAMユーザー認証情報を使用
```

### 2. Sceptre設定ファイル例
```yaml
# config/development/config.yaml
project_code: ses-migration
region: ap-northeast-1
template_handler: file

# 開発テナント設定
tenant_name: development
environment: development
account_id: "DEVELOPMENT_ACCOUNT_ID"

# 共通設定の継承
parent: ../shared/config.yaml

# 開発テナント固有タグ
tags:
  Tenant: development
  Environment: development
  Purpose: testing-validation
  CostCenter: DEV-SES-001
```

```yaml
# config/production/config.yaml
project_code: ses-migration
region: ap-northeast-1
template_handler: file

# 本番テナント設定
tenant_name: production
environment: production
account_id: "PRODUCTION_ACCOUNT_ID"

# 共通設定の継承
parent: ../shared/config.yaml

# 本番テナント固有タグ
tags:
  Tenant: production
  Environment: production
  Purpose: live-service
  CostCenter: PROD-SES-001
```

### 3. 切り替えスクリプト例
```bash
#!/bin/bash
# switch-tenant.sh

TENANT=$1

if [ -z "$TENANT" ]; then
    echo "Usage: $0 <tenant>"
    echo "Available tenants: development, production"
    echo "Example: $0 development"
    exit 1
fi

if [ "$TENANT" != "development" ] && [ "$TENANT" != "production" ]; then
    echo "❌ Invalid tenant. Use 'development' or 'production'"
    exit 1
fi

export AWS_PROFILE="${TENANT}-tenant"
export SCEPTRE_DIR="config/${TENANT}"

echo "🔄 Switched to ${TENANT} tenant:"
echo "  AWS Profile: $AWS_PROFILE"
echo "  Sceptre Dir: $SCEPTRE_DIR"
echo "  Account: $(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'Profile not configured')"
```
