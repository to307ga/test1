# EasyDKIM無効化手順書

## 概要
AWS SESのEmail Identityで自動的に有効化されるEasyDKIMを無効化する手順

## 背景
CloudFormationの`AWS::SES::EmailIdentity`リソースでは、DKIM設定を明示的に無効化することができません。そのため、スタック作成後にAWS CLIを使用して手動で無効化する必要があります。

## 前提条件

### 必要な環境・ツール
- AWS CLI設定済み（適切な権限を持つ）
- SES Email Identityが作成済み

### 必要なスタックの完了状況
- **Phase 3**: `prod/phase-3-ses-byodkim.yaml` が完了していること
  - SES Email Identity（goo.ne.jp）
  - 関連するIAMロールとポリシー
  - **注意**: この時点でEasyDKIMが自動的に有効化されている

### 確認方法
```bash
# Phase 3の完了確認
uv run sceptre describe prod/phase-3-ses-byodkim.yaml

# SES Email Identityの存在確認
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1

# 現在のDKIM設定確認
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1 --query "DkimAttributes.SigningEnabled"
```

## 手順

### 1. 現在のDKIM設定確認
```bash
# SES Email Identityの詳細情報を確認
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1 --query "DkimAttributes"
```

**期待される出力（無効化前）:**
```json
{
    "SigningEnabled": true,
    "Status": "SUCCESS",
    "Tokens": [
        "6ow2eacfnkpfj2r7lb5kkjwgcashonnz",
        "qjgvlmxb6bewmarawxvgb33rsnqmbdc6",
        "qkwr4koa3ji2lapyksfoxzfftjxbpalf"
    ],
    "SigningAttributesOrigin": "AWS_SES"
}
```

### 2. EasyDKIMの無効化
```bash
# EasyDKIMを無効化
aws sesv2 put-email-identity-dkim-attributes \
    --email-identity goo.ne.jp \
    --no-signing-enabled \
    --region ap-northeast-1
```

### 3. 無効化の確認
```bash
# DKIM設定が無効化されたことを確認
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1 --query "DkimAttributes.SigningEnabled"
```

**期待される出力（無効化後）:**
```json
false
```

### 4. 詳細確認
```bash
# 完全なDKIM設定を確認
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1 --query "DkimAttributes"
```

**期待される出力:**
```json
{
    "SigningEnabled": false,
    "Status": "PENDING",
    "Tokens": [
        "6ow2eacfnkpfj2r7lb5kkjwgcashonnz",
        "qjgvlmxb6bewmarawxvgb33rsnqmbdc6",
        "qkwr4koa3ji2lapyksfoxzfftjxbpalf"
    ],
    "SigningAttributesOrigin": "AWS_SES",
    "NextSigningKeyLength": "RSA_2048_BIT",
    "CurrentSigningKeyLength": "RSA_2048_BIT"
}
```

## 自動化スクリプト

### Bash版スクリプト
```bash
#!/bin/bash
# EasyDKIM無効化スクリプト

set -e

EMAIL_IDENTITY=${1:-goo.ne.jp}
REGION=${2:-ap-northeast-1}

echo "=== EasyDKIM無効化スクリプト ==="
echo "Email Identity: $EMAIL_IDENTITY"
echo "Region: $REGION"
echo ""

# 1. 現在の設定確認
echo "1. 現在のDKIM設定確認..."
aws sesv2 get-email-identity --email-identity $EMAIL_IDENTITY --region $REGION --query "DkimAttributes.SigningEnabled"

# 2. EasyDKIM無効化
echo "2. EasyDKIM無効化..."
aws sesv2 put-email-identity-dkim-attributes \
    --email-identity $EMAIL_IDENTITY \
    --no-signing-enabled \
    --region $REGION

# 3. 無効化確認
echo "3. 無効化確認..."
aws sesv2 get-email-identity --email-identity $EMAIL_IDENTITY --region $REGION --query "DkimAttributes.SigningEnabled"

echo "=== EasyDKIM無効化完了 ==="
```

### PowerShell版スクリプト
```powershell
# EasyDKIM無効化スクリプト (PowerShell版)

param(
    [string]$EmailIdentity = "goo.ne.jp",
    [string]$Region = "ap-northeast-1"
)

Write-Host "=== EasyDKIM無効化スクリプト ===" -ForegroundColor Green
Write-Host "Email Identity: $EmailIdentity"
Write-Host "Region: $Region"
Write-Host ""

try {
    # 1. 現在の設定確認
    Write-Host "1. 現在のDKIM設定確認..." -ForegroundColor Yellow
    $currentStatus = aws sesv2 get-email-identity --email-identity $EmailIdentity --region $Region --query "DkimAttributes.SigningEnabled" --output text
    Write-Host "現在のSigningEnabled: $currentStatus" -ForegroundColor Cyan

    # 2. EasyDKIM無効化
    Write-Host "2. EasyDKIM無効化..." -ForegroundColor Yellow
    aws sesv2 put-email-identity-dkim-attributes --email-identity $EmailIdentity --no-signing-enabled --region $Region

    # 3. 無効化確認
    Write-Host "3. 無効化確認..." -ForegroundColor Yellow
    $newStatus = aws sesv2 get-email-identity --email-identity $EmailIdentity --region $Region --query "DkimAttributes.SigningEnabled" --output text
    Write-Host "新しいSigningEnabled: $newStatus" -ForegroundColor Cyan

    Write-Host "=== EasyDKIM無効化完了 ===" -ForegroundColor Green

} catch {
    Write-Host "エラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
```

## 注意事項
- **実行タイミング**: Phase 3スタック作成直後に実行
- **権限**: SESの`PutEmailIdentityDkimAttributes`権限が必要
- **影響**: EasyDKIMが無効化され、BYODKIMの設定準備が完了
- **再現性**: この手順は手動実行が必要（CloudFormationでは自動化不可）

## トラブルシューティング
- **権限エラー**: IAMロールにSES権限が不足している
- **Email Identity未作成**: Phase 3スタックが完了していない
- **リージョンエラー**: 正しいリージョンを指定しているか確認

## 次のステップ
EasyDKIM無効化完了後、Phase 4以降でBYODKIMの設定を行います。
