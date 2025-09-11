# BYODKIM完全デプロイ手順書

## 概要
AWS SES BYODKIM実装の完全デプロイ手順（Layer作成とEasyDKIM無効化を含む）

## 前提条件
- AWS CLI設定済み（適切な権限）
- Sceptre環境構築済み
- Python環境（uv使用）
- 作業ディレクトリ: `AWS_SES_BYODKIM`

## Phase 1: インフラ基盤構築
```bash
# Production基盤インフラ作成
uv run sceptre launch prod/base.yaml

# Phase 1: インフラ基盤（S3, KMS, IAM, Secrets Manager）
uv run sceptre launch prod/phase-1-infrastructure-foundation.yaml
```

## Phase 2: DKIM管理システム + Layer作成
```bash
# Step 1: Layer作成スクリプト実行（重要！）
./scripts/create-layer.sh prod aws-ses-migration

# または PowerShell版
# .\scripts\create-layer.ps1 -Environment prod -ProjectName aws-ses-migration

# Step 2: Layer作成確認
aws lambda list-layers --region ap-northeast-1 --query "Layers[?contains(LayerName, 'aws-ses-migration-prod-cryptography')]"
```

**Layer作成スクリプトが実行する内容:**
1. 前提条件チェック（Phase 1完了確認）
2. cryptographyライブラリのインストール
3. Layerファイル（.zip）作成
4. S3バケットへのアップロード
5. Phase 2スタック更新（Layer作成）
6. Lambda関数テスト

## Phase 3: SES設定 + EasyDKIM無効化
```bash
# Step 1: SES Email Identity作成
uv run sceptre launch prod/phase-3-ses-byodkim.yaml

# Step 2: EasyDKIM無効化（重要！）
./scripts/disable-easydkim.sh goo.ne.jp ap-northeast-1

# または PowerShell版
# .\scripts\disable-easydkim.ps1 -EmailIdentity goo.ne.jp -Region ap-northeast-1

# Step 3: 無効化確認
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1 --query "DkimAttributes.SigningEnabled"
# 期待値: false
```

**EasyDKIM無効化が必要な理由:**
- CloudFormationでEmailIdentity作成時、自動的にEasyDKIMが有効化される
- BYODKIMを使用するには、EasyDKIMを無効化する必要がある
- CloudFormationでは無効化できないため、AWS CLIで手動実行が必要

## Phase 4-8: BYODKIM設定
```bash
# Phase 4: DNS準備
uv run sceptre launch prod/phase-4-dns-preparation.yaml

# Phase 5: DNSチーム連携
uv run sceptre launch prod/phase-5-dns-team-collaboration.yaml

# Phase 6: スキップ（DNS検証は手動）
# DNSチームによるCNAMEレコード設定を待機

# Phase 7: DNS検証とDKIM有効化
uv run sceptre launch prod/phase-7-dns-validation-dkim-activation.yaml

# Phase 8: 監視システム
uv run sceptre launch prod/phase-8-monitoring-system.yaml
```

## 開発環境デプロイ（オプション）
```bash
# 開発環境基盤
uv run sceptre launch dev/base.yaml

# 開発環境SES（Production EmailIdentityを共有）
uv run sceptre launch dev/ses.yaml
```

## 重要な手動ステップ

### ✅ 必須手動ステップ
1. **Layer作成**: `./scripts/create-layer.sh` 実行
2. **EasyDKIM無効化**: `./scripts/disable-easydkim.sh` 実行
3. **DNS設定**: DNSチームによるCNAMEレコード追加

### 🔍 確認ポイント
```bash
# Layer確認
aws lambda list-layers --region ap-northeast-1

# EasyDKIM確認
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1

# DNS確認
nslookup gooid-21-pro._domainkey.goo.ne.jp
```

## トラブルシューティング

### Layer作成エラー
```bash
# S3バケット確認
aws s3 ls | grep cryptography-layer

# Layer手動作成
cd lambda-layer
pip install cryptography --target python/ --platform linux_x86_64
zip -r cryptography-layer.zip python/
aws s3 cp cryptography-layer.zip s3://BUCKET_NAME/
```

### EasyDKIM無効化エラー
```bash
# Email Identity存在確認
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1

# 手動無効化
aws sesv2 put-email-identity-dkim-attributes --email-identity goo.ne.jp --no-signing-enabled --region ap-northeast-1
```

## デプロイ完了確認
```bash
# 全スタック確認
uv run sceptre list prod/

# SES設定確認
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1

# Lambda関数確認
aws lambda get-function --function-name aws-ses-migration-prod-dkim-manager --region ap-northeast-1
```

## 次のステップ
1. DNS検証待機（DNSチーム作業）
2. Phase 7でDKIM有効化
3. 監視システム稼働
4. 本番運用開始
