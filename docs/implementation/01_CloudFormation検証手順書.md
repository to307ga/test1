# CloudFormation検証手順書

## 1. 概要

AWS SES マイグレーションプロジェクトにおけるCloudFormationテンプレートの検証手順を定義します。

## 2. 検証対象テンプレート（5スタック構成）

### 2.1 Sceptreテンプレート一覧
```
sceptre/templates/
├── base.yaml              # Base Stack：S3バケット・基本インフラ
├── ses.yaml               # SES Stack：本番EmailIdentity（Production-First）
├── ses-dev.yaml           # SES-Dev Stack：開発環境専用（本番依存）
├── enhanced-kinesis.yaml  # Enhanced-Kinesis Stack：データ処理パイプライン
├── monitoring.yaml        # Monitoring Stack：CloudWatch監視
└── security.yaml          # Security Stack：IAM・セキュリティ
```

**更新履歴**:
- v1.0: 初版作成
- v2.0: 5スタック構成対応、Production-First構成対応、文字化け修正

### 3.2 一括検証スクリプト

```bash
#!/bin/bash
# 全テンプレート検証スクリプト

cd sceptre/templates

echo "=== CloudFormation テンプレート検証開始 ==="

templates=("base.yaml" "ses.yaml" "ses-dev.yaml" "enhanced-kinesis.yaml" "monitoring.yaml" "security.yaml")

for template in "${templates[@]}"; do
    echo "検証中: $template"
    if aws cloudformation validate-template --template-body file://$template > /dev/null 2>&1; then
        echo "✅ $template: 構文検証OK"
    else
        echo "❌ $template: 構文エラーあり"
        aws cloudformation validate-template --template-body file://$template
    fi
    echo ""
done

echo "=== CloudFormation テンプレート検証完了 ==="
```

### 3.3 正常な検証結果例

```json
{
    "Parameters": [
        {
            "ParameterKey": "Environment",
            "DefaultValue": "production",
            "NoEcho": false,
            "Description": "Environment name"
        },
        {
            "ParameterKey": "ProjectCode",
            "DefaultValue": "ses-migration",
            "NoEcho": false,
            "Description": "Project code for resource naming"
        }
    ],
    "Description": "SES Configuration with EmailIdentity (Production-First) - Tokyo Region (ap-northeast-1)",
    "Capabilities": [
        "CAPABILITY_IAM"
    ],
    "CapabilitiesReason": "The following resource(s) require capabilities: [AWS::IAM::ManagedPolicy]"
}
```

## 4. Sceptre による統合検証

### 4.1 Sceptre設定検証

```bash
# 開発環境設定検証
uv run sceptre validate dev/base.yaml
uv run sceptre validate dev/ses.yaml
uv run sceptre validate dev/enhanced-kinesis.yaml
uv run sceptre validate dev/monitoring.yaml
uv run sceptre validate dev/security.yaml

# 本番環境設定検証
uv run sceptre validate prod/base.yaml
uv run sceptre validate prod/ses.yaml
uv run sceptre validate prod/enhanced-kinesis.yaml
uv run sceptre validate prod/monitoring.yaml
uv run sceptre validate prod/security.yaml
```

### 4.2 Sceptre設定一覧確認

```bash
# 開発環境スタック一覧
uv run sceptre list stacks dev

# 本番環境スタック一覧
uv run sceptre list stacks prod

# 全環境設定確認
uv run sceptre list config dev
uv run sceptre list config prod
```

### 4.3 依存関係検証

```bash
# スタック依存関係確認
uv run sceptre list dependencies dev/ses.yaml
uv run sceptre list dependencies prod/enhanced-kinesis.yaml
uv run sceptre list dependencies dev/security.yaml
```

## 5. テンプレート個別検証詳細

### 5.1 Base Stack（base.yaml）検証

```bash
# Base Stack検証
aws cloudformation validate-template --template-body file://templates/base.yaml

# 期待される主要リソース
# - AWS::S3::Bucket (raw-logs, masked-logs, error-logs)
# - AWS::S3::BucketPolicy
# - S3暗号化設定 (SSE-S3)
```

### 5.2 SES Stack（ses.yaml / ses-dev.yaml）検証

```bash
# 本番SES Stack検証（Production-First、BYODKIM方式）
aws cloudformation validate-template --template-body file://templates/ses.yaml

# 開発SES Stack検証（本番依存、BYODKIM設定継承）
aws cloudformation validate-template --template-body file://templates/ses-dev.yaml

# 期待される主要リソース
# - AWS::SES::EmailIdentity (goo.ne.jp、BYODKIM方式)
# - AWS::SES::ConfigurationSet
# - AWS::KMS::Key (DKIM自動化用)
# - AWS::Lambda::Function (DKIM自動ローテーション機能)
# - AWS::Events::Rule (EventBridge年次スケジュール)
# - AWS::IAM::ManagedPolicy (IP制限)
# - SES IP制限ポリシー実装確認
```

### 5.3 Enhanced-Kinesis Stack（enhanced-kinesis.yaml）検証

```bash
# Enhanced-Kinesis Stack検証
aws cloudformation validate-template --template-body file://templates/enhanced-kinesis.yaml

# 期待される主要リソース
# - AWS::KinesisFirehose::DeliveryStream (Raw Stream)
# - AWS::KinesisFirehose::DeliveryStream (Masked Stream)
# - AWS::Lambda::Function (データマスキング)
# - バッファ設定: 300秒, 128MB
```

### 5.4 Monitoring Stack（monitoring.yaml）検証

```bash
# Monitoring Stack検証
aws cloudformation validate-template --template-body file://templates/monitoring.yaml

# 期待される主要リソース
# - AWS::CloudWatch::Alarm
# - AWS::CloudWatch::Dashboard
# - AWS::SNS::Topic
# - AWS::Logs::LogGroup
```

### 5.5 Security Stack（security.yaml）検証

```bash
# Security Stack検証（DKIM自動化機能含む）
aws cloudformation validate-template --template-body file://templates/security.yaml

# 期待される主要リソース
# - AWS::IAM::Group (Admin/ReadOnly/Monitoring)
# - AWS::IAM::User
# - AWS::IAM::Policy (IP制限、個人情報保護)
# - AWS::Lambda::Function (DKIM自動化Lambda群)
#   - DKIMRotationOrchestrator
#   - DKIMKeyGenerator
#   - SESConfigUpdater
#   - NotificationManager
#   - ValidationMonitor
# - AWS::Events::Rule (EventBridge DKIM年次ローテーション)
# - AWS::SNS::Topic (DKIM通知用)
# - 日本コンプライアンス設定
```

## 6. パラメータ検証

### 6.1 必須パラメータ確認

各テンプレートの必須パラメータを確認します：

```bash
# パラメータ一覧表示
aws cloudformation validate-template \
  --template-body file://templates/ses.yaml \
  --query 'Parameters[*].[ParameterKey,DefaultValue,Description]' \
  --output table
```

### 6.2 環境別パラメータ値検証

```yaml
# 本番環境パラメータ例 (prod/ses.yaml)
parameters:
  Environment: production
  SESIPAllowedRanges:
    - 202.217.75.98/32
    - 202.217.75.91/32
  EnableSESIPFiltering: "true"
  DomainName: goo.ne.jp
  DKIMMode: "BYODKIM"
  DKIMRotationEnabled: "true"
  DKIMRotationSchedule: "cron(0 0 1 * ? *)"  # 月次チェック

# 開発環境パラメータ例 (dev/ses.yaml)
parameters:
  Environment: dev
  SESIPAllowedRanges:
    - 202.217.75.88/32
    - 202.217.75.81/32
  EnableSESIPFiltering: "true"
  DomainName: goo.ne.jp
  DKIMMode: "BYODKIM"
  DKIMRotationEnabled: "true"
```

## 7. エラー対応・トラブルシューティング

### 7.1 一般的なエラー

#### 7.1.1 構文エラー
```
Template format error: YAML not well-formed
```
**対処法**: YAML構文を確認、インデント・文字エンコーディング確認

#### 7.1.2 パラメータエラー
```
Template validation error: Template parameter [parameter-name] must have a value
```
**対処法**: 必須パラメータの設定確認、デフォルト値確認

#### 7.1.3 リソースエラー
```
Template validation error: Template contains errors in Resources block
```
**対処法**: リソース定義の構文確認、プロパティ名確認

### 7.2 IP制限固有エラー

#### 7.2.1 IP形式エラー
```
Invalid IP address format in Condition
```
**対処法**: IP制限設定のCIDR形式確認（例：202.217.75.98/32）

#### 7.2.2 IAM権限エラー
```
Insufficient privileges to validate template
```
**対処法**: CloudFormation、IAM操作権限の確認

### 7.3 文字エンコーディング問題

#### 7.3.1 文字化け対応
```bash
# UTF-8エンコーディング確認・修正
file templates/base.yaml
iconv -f UTF-8 -t UTF-8 templates/base.yaml > templates/base_fixed.yaml
mv templates/base_fixed.yaml templates/base.yaml
```

#### 7.3.2 VSCode設定
```json
// .vscode/settings.json
{
  "files.encoding": "utf8",
  "files.eol": "\n",
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "[yaml]": {
    "files.encoding": "utf8"
  }
}
```

## 8. 検証チェックリスト

### 8.1 テンプレート検証チェックリスト

- [ ] 全6テンプレートの構文検証完了
- [ ] Sceptre設定検証完了（dev/prod）
- [ ] 必須パラメータ確認完了
- [ ] IP制限設定確認完了（4IP設定）
- [ ] 依存関係検証完了
- [ ] 文字エンコーディング確認完了

### 8.2 機能検証チェックリスト

- [ ] Production-First構成確認
- [ ] SES EmailIdentity依存関係確認（BYODKIM方式）
- [ ] DKIM自動化Lambda関数デプロイ確認
- [ ] EventBridge年次ローテーション設定確認
- [ ] KMS Asymmetric Keys設定確認
- [ ] Kinesis Firehose設定確認（300秒バッファ）
- [ ] IAM 3段階権限確認
- [ ] 日本コンプライアンス設定確認
- [ ] 東京リージョン設定確認（ap-northeast-1）

### 8.3 セキュリティ検証チェックリスト

- [ ] SES IP制限ポリシー確認
- [ ] BYODKIM鍵管理セキュリティ確認
- [ ] DKIM自動化Lambda権限確認
- [ ] IAM最小権限原則確認
- [ ] S3暗号化設定確認（SSE-S3）
- [ ] CloudWatch監視設定確認
- [ ] セキュリティログ設定確認

## 9. 実行例・検証結果

### 9.1 成功例

```bash
$ uv run sceptre validate prod/ses.yaml
[INFO] Validating template: templates/ses.yaml
✅ Template validation successful
[INFO] Stack parameters validated
[INFO] Dependencies resolved
```

### 9.2 警告例

```bash
$ aws cloudformation validate-template --template-body file://templates/security.yaml
{
    "Parameters": [...],
    "Description": "Security and IAM for AWS SES Migration - Tokyo Region",
    "Capabilities": [
        "CAPABILITY_IAM",
        "CAPABILITY_NAMED_IAM"
    ],
    "CapabilitiesReason": "The following resource(s) require capabilities: [AWS::IAM::User, AWS::IAM::Group, AWS::IAM::Policy]"
}
```

## 10. 自動化・CI/CD統合

### 10.1 GitHub Actions検証ワークフロー

```yaml
name: CloudFormation Template Validation

on:
  push:
    paths:
      - 'sceptre/templates/**'
      - 'sceptre/config/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-1

      - name: Validate CloudFormation templates
        run: |
          cd sceptre/templates
          for template in *.yaml; do
            echo "Validating $template"
            aws cloudformation validate-template --template-body file://$template
          done

      - name: Validate Sceptre configs
        run: |
          pip install sceptre
          cd sceptre
          sceptre validate dev/base.yaml
          sceptre validate prod/base.yaml
```

### 10.2 pre-commit検証フック

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: cloudformation-validate
        name: Validate CloudFormation templates
        entry: bash -c 'cd sceptre/templates && for f in *.yaml; do aws cloudformation validate-template --template-body file://$f; done'
        language: system
        files: sceptre/templates/.*\.yaml$
```

## 11. 関連資料

### 11.1 プロジェクト関連文書
- [システム設計書](../design/01_システム設計書.md)
- [セキュリティ設計書](../design/03_セキュリティ設計書.md)
- [ディレクトリ構造説明書](../design/04_ディレクトリ構造説明書.md)
- [移行手順書](../migration/01_移行手順書.md)

### 11.2 AWS公式ドキュメント
- [AWS CloudFormation テンプレート検証](https://docs.aws.amazon.com/cloudformation/latest/userguide/using-cfn-validate-template.html)
- [AWS CLI CloudFormation コマンド](https://docs.aws.amazon.com/cli/latest/reference/cloudformation/)
- [Sceptre ドキュメント](https://docs.sceptre-project.org/)

---

**文書作成日**: 2024年12月
**最終更新**: 2025年9月4日（BYODKIM + Lambda自動化対応、5スタック実装完了、文字化け修正）
**作成者**: インフラ実装チーム
**承認者**: システム運用チーム
**版数**: 2.1 (BYODKIM自動化対応版)

**更新履歴**:
- v1.0: 初版作成
- v2.0: 5スタック構成対応、Production-First構成対応、文字化け修正
- v2.1: BYODKIM + AWS KMS + Lambda + EventBridge自動化対応
