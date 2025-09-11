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

    try {
        $currentStatus = aws sesv2 get-email-identity --email-identity $EmailIdentity --region $Region --query "DkimAttributes.SigningEnabled" --output text
        Write-Host "現在のSigningEnabled: $currentStatus" -ForegroundColor Cyan
    }
    catch {
        Write-Host "エラー: Email Identity '$EmailIdentity' が見つかりません。Phase 3スタックが完了しているか確認してください。" -ForegroundColor Red
        exit 1
    }

    # 2. 既に無効化されている場合はスキップ
    if ($currentStatus -eq "false") {
        Write-Host "EasyDKIMは既に無効化されています。" -ForegroundColor Green
        exit 0
    }

    # 3. EasyDKIM無効化
    Write-Host "2. EasyDKIM無効化..." -ForegroundColor Yellow
    aws sesv2 put-email-identity-dkim-attributes --email-identity $EmailIdentity --no-signing-enabled --region $Region
    Write-Host "無効化コマンドを実行しました。" -ForegroundColor Green

    # 4. 無効化確認（少し待ってから確認）
    Write-Host "3. 無効化確認（5秒待機後）..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5

    $newStatus = aws sesv2 get-email-identity --email-identity $EmailIdentity --region $Region --query "DkimAttributes.SigningEnabled" --output text
    Write-Host "新しいSigningEnabled: $newStatus" -ForegroundColor Cyan

    if ($newStatus -eq "false") {
        Write-Host "✅ EasyDKIM無効化成功！" -ForegroundColor Green
    } else {
        Write-Host "❌ EasyDKIM無効化に失敗した可能性があります。手動で確認してください。" -ForegroundColor Red
        exit 1
    }

    Write-Host "=== EasyDKIM無効化完了 ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "次のステップ: Phase 4以降でBYODKIMの設定を行ってください。" -ForegroundColor Yellow

} catch {
    Write-Host "エラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
