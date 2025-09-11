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

    if ($currentStatus -eq "false") {
        Write-Host "EasyDKIMは既に無効化されています。" -ForegroundColor Green
        exit 0
    }

    # 2. EasyDKIM無効化
    Write-Host "2. EasyDKIM無効化..." -ForegroundColor Yellow
    aws sesv2 put-email-identity-dkim-attributes --email-identity $EmailIdentity --no-signing-enabled --region $Region

    # 3. 無効化確認
    Write-Host "3. 無効化確認..." -ForegroundColor Yellow
    $newStatus = aws sesv2 get-email-identity --email-identity $EmailIdentity --region $Region --query "DkimAttributes.SigningEnabled" --output text
    Write-Host "新しいSigningEnabled: $newStatus" -ForegroundColor Cyan

    if ($newStatus -eq "false") {
        Write-Host "=== EasyDKIM無効化完了 ===" -ForegroundColor Green
    } else {
        Write-Host "エラー: EasyDKIMの無効化に失敗しました" -ForegroundColor Red
        exit 1
    }

} catch {
    Write-Host "エラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
