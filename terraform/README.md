# AWS SES Infrastructure with Terraform

## 概要

このプロジェクトは、AWS SES（Simple Email Service）のインフラストラクチャをTerraformで構築し、個人情報保護機能を含む包括的な監視・セキュリティシステムを提供します。

## 主要機能

### 1. 個人情報保護・マスキング機能
- **メールアドレスマスキング**: `u***@***.***` 形式
- **IPアドレスマスキング**: `192.*.*.*` 形式
- **ユーザー権限による制御**:
  - Admin: 完全な情報表示
  - ReadOnly/Monitoring: マスクされた情報表示

### 2. セキュリティ機能
- IPアドレス制限によるアクセス制御
- IAMユーザー・グループによる権限管理
- CloudTrailによる監査ログ
- AWS Configによるコンプライアンス監視

### 3. 監視・アラート機能
- CloudWatchアラーム
- カスタムメトリクス
- ログ分析・クエリ

## アーキテクチャ

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   AWS SES       │    │  CloudWatch     │    │   Lambda        │
│   Domain        │    │  Logs/Insights  │    │   Functions     │
│   Configuration │◄──►│  Alarms         │◄──►│   - Data Masking│
│   Receipt Rules │    │  Metrics        │    │   - Custom      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   S3 Bucket     │    │   IAM Groups    │    │   CloudTrail    │
│   - Logs        │    │   - Admin       │    │   - Audit Logs  │
│   - Bounces     │    │   - ReadOnly    │    │                 │
│   - Complaints  │    │   - Monitoring  │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## モジュール構成

### Base Infrastructure (`modules/base/`)
- S3バケット（ログ・バウンス・苦情）
- SNSトピック（通知）
- CloudTrail（監査）
- AWS Config（コンプライアンス）

### SES Configuration (`modules/ses/`)
- SESドメイン設定
- DKIM設定
- 受信ルール
- CloudWatch統合

### Monitoring (`modules/monitoring/`)
- CloudWatchアラーム
- Insightsクエリ（Admin用・マスク用）
- Lambda関数（データマスキング・カスタムメトリクス）

### Security (`modules/security/`)
- IAMグループ・ユーザー
- アクセス制御ポリシー
- IP制限

## セットアップ

### 前提条件
- Terraform >= 1.6.0
- AWS CLI設定済み
- 適切なAWS権限

### 1. 初期化
```bash
cd templates/terraform
terraform init
```

### 2. 変数設定
```bash
# test.tfvarsを編集して環境に合わせる
cp test.tfvars production.tfvars
# 本番環境用の値を設定
```

### 3. デプロイ
```bash
terraform plan -var-file="production.tfvars"
terraform apply -var-file="production.tfvars"
```

## テスト実行

### Terraform TestによるUNITテスト・Integrationテスト

#### 1. 全テスト実行
```bash
make test
```

#### 2. UNITテストのみ実行
```bash
make test-unit
```

#### 3. Integrationテストのみ実行
```bash
make test-integration
```

#### 4. 特定モジュールのテスト
```bash
make test-module-base      # baseモジュール
make test-module-ses       # sesモジュール
make test-module-monitoring # monitoringモジュール
make test-module-security  # securityモジュール
```

#### 5. その他の便利なコマンド
```bash
make help          # 利用可能なコマンド一覧
make validate      # 設定ファイルの検証
make plan          # 実行計画の作成
make fmt           # コードフォーマット
make lint          # リンター実行
make security      # セキュリティスキャン
make clean         # 一時ファイルのクリーンアップ
```

### テスト内容

#### UNITテスト
- **base**: S3、SNS、CloudTrail、AWS Configの設定
- **ses**: SES設定、DKIM、受信ルール
- **monitoring**: CloudWatch、Lambda、Insightsクエリ
- **security**: IAM、アクセス制御、PII保護

#### Integrationテスト
- モジュール間の連携
- エンドツーエンドの機能確認
- PII保護機能の統合テスト

## CI/CDワークフロー

### GitHub Actions
`.github/workflows/terraform-test.yml` で以下のワークフローを自動実行：

1. **Test Job**
   - Terraform初期化・検証
   - UNITテスト実行
   - Integrationテスト実行
   - 実行計画作成

2. **Security Job**
   - Trivyによる脆弱性スキャン
   - セキュリティ結果のGitHub Securityタブへのアップロード

3. **Compliance Job**
   - Checkovによるコンプライアンスチェック
   - 結果のGitHub Securityタブへのアップロード

4. **Deploy Job** (mainブランチのみ)
   - テスト環境への自動デプロイ
   - デプロイ後テスト

### トリガー条件
- `main`、`develop`ブランチへのプッシュ
- `main`、`develop`ブランチへのプルリクエスト
- `templates/terraform/**` パスの変更時

## 個人情報保護の詳細

### マスキングレベル
- **メールアドレス**: `u***@***.***`
- **IPアドレス**: `192.*.*.*`

### アクセス制御
| ユーザー権限 | メールアドレス | IPアドレス | アクセス可能IP |
|-------------|---------------|------------|----------------|
| Admin      | 完全表示      | 完全表示   | 制限なし       |
| ReadOnly   | マスク表示    | マスク表示 | 許可されたIPのみ |
| Monitoring | マスク表示    | マスク表示 | 許可されたIPのみ |

### 実装方法
1. **CloudWatch Insights**: 2つのクエリ定義（Admin用・マスク用）
2. **Lambda関数**: リアルタイムデータマスキング
3. **IAMポリシー**: ユーザー権限とIP制限の組み合わせ

## 運用・監視

### ログ分析
```bash
# Admin用クエリ（完全表示）
aws logs start-query \
  --log-group-name "ses-migration-production-ses" \
  --query-string "fields @timestamp, eventType, destination, sourceIp | filter eventType = 'bounce'"

# マスク用クエリ（個人情報保護）
aws logs start-query \
  --log-group-name "ses-migration-production-ses" \
  --query-string "fields @timestamp, eventType, maskedDestination, maskedSourceIp | filter eventType = 'bounce'"
```

### アラート設定
- バウンス率 > 5%
- 苦情率 > 0.1%
- 送信成功率 < 95%

### メトリクス
- 送信成功率
- バウンス率
- 苦情率

## トラブルシューティング

### よくある問題
1. **Lambda関数の実行エラー**
   - IAM権限の確認
   - ログの確認

2. **CloudWatch Insightsクエリエラー**
   - ロググループ名の確認
   - クエリ構文の確認

3. **アクセス拒否エラー**
   - IAMポリシーの確認
   - IP制限の確認

### ログ確認
```bash
# CloudWatch Logs
aws logs describe-log-groups --log-group-name-prefix "ses-migration"

# Lambda関数ログ
aws logs describe-log-streams --log-group-name "/aws/lambda/ses-migration-production-data-masking"
```

## セキュリティ考慮事項

### データ保護
- 個人情報の自動マスキング
- アクセスログの記録
- 暗号化の適用

### アクセス制御
- 最小権限の原則
- IPアドレス制限
- 多要素認証の推奨

### 監査・コンプライアンス
- CloudTrailによるAPI呼び出しログ
- AWS Configによるリソース設定監視
- 定期的なセキュリティレビュー

## ライセンス

このプロジェクトは社内利用を目的としています。

## サポート

技術的な質問や問題がある場合は、開発チームまでお問い合わせください。
