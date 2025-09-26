# AWS MFA自動ログインスクリプト (PowerShell版)
# 使用方法: .\mfa_login.ps1 [MFAコード]

param(
    [string]$MfaCode
)

# 設定
$MfaDeviceArn = "arn:aws:iam::007773581311:mfa/prod_toshimitsu.tomonaga.zd"
$Duration = 43200  # 12時間

# MFAコードの取得
if (-not $MfaCode) {
    $MfaCode = Read-Host "MFAコードを入力してください (6桁)"
}

# 入力検証
if ($MfaCode -notmatch '^\d{6}$') {
    Write-Error "エラー: MFAコードは6桁の数字である必要があります"
    exit 1
}

Write-Host "MFA認証を実行中..." -ForegroundColor Yellow

# 現在のプロファイル設定
$env:AWS_PROFILE = "prod"

# GetSessionToken実行
Write-Host "AWS STS GetSessionToken を実行中..." -ForegroundColor Yellow
try {
    $result = aws sts get-session-token `
        --duration-seconds $Duration `
        --serial-number $MfaDeviceArn `
        --token-code $MfaCode `
        --no-verify-ssl 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "GetSessionToken failed"
    }

    $credentials = $result | ConvertFrom-Json
} catch {
    Write-Error "エラー: GetSessionToken が失敗しました"
    Write-Error "MFAコードが正しいか確認してください"
    exit 1
}

# 環境変数設定
Write-Host "環境変数を設定中..." -ForegroundColor Yellow
$env:AWS_ACCESS_KEY_ID = $credentials.Credentials.AccessKeyId
$env:AWS_SECRET_ACCESS_KEY = $credentials.Credentials.SecretAccessKey
$env:AWS_SESSION_TOKEN = $credentials.Credentials.SessionToken
$expiration = $credentials.Credentials.Expiration
$env:AWS_PROFILE = $null

# 結果出力
Write-Host "✅ MFA認証成功！" -ForegroundColor Green
Write-Host "有効期限: $expiration"
Write-Host ""
Write-Host "現在のPowerShellセッションで以下の環境変数が設定されました:" -ForegroundColor Cyan
Write-Host "  AWS_ACCESS_KEY_ID=$($env:AWS_ACCESS_KEY_ID)"
Write-Host "  AWS_SECRET_ACCESS_KEY=(設定済み)"
Write-Host "  AWS_SESSION_TOKEN=(設定済み)"
Write-Host ""
Write-Host "認証確認を実行中..." -ForegroundColor Yellow

# 認証確認
aws sts get-caller-identity --no-verify-ssl

Write-Host ""
Write-Host "🎉 AWS CLIが使用可能です（12時間有効）" -ForegroundColor Green
Write-Host ""
Write-Host "使用例:" -ForegroundColor Cyan
Write-Host "  aws cloudwatch list-dashboards --no-verify-ssl"
Write-Host "  cd sceptre; `$env:PYTHONHTTPSVERIFY=0; uv run sceptre status prod"
