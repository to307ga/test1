# Layer作成自動化スクリプト (PowerShell版)
# Usage: .\scripts\create-layer.ps1 [environment] [project-name]

param(
    [string]$Environment = "prod",
    [string]$ProjectName = "aws-byodmim",
    [string]$Region = "ap-northeast-1"
)

Write-Host "=== Layer作成自動化スクリプト ===" -ForegroundColor Green
Write-Host "Environment: $Environment"
Write-Host "Project: $ProjectName"
Write-Host "Region: $Region"
Write-Host ""

try {
    # 1. Layerファイルの準備
    Write-Host "1. Layerファイルの準備..." -ForegroundColor Yellow
    Set-Location lambda-layer

    # cryptographyライブラリのインストール
    Write-Host "  - cryptographyライブラリのインストール" -ForegroundColor Cyan
    uv pip install cryptography --target python/

    # Layerファイルの作成
    Write-Host "  - Layerファイルの作成" -ForegroundColor Cyan
    Compress-Archive -Path python -DestinationPath cryptography-layer.zip -Force

    Set-Location ../sceptre

    # 2. Phase 2スタックの更新（S3バケット作成）
    Write-Host "2. Phase 2スタックの更新（S3バケット作成）..." -ForegroundColor Yellow
    uv run sceptre update "$Environment/phase-2-dkim-system.yaml" --yes

    # 3. S3バケット名の取得
    Write-Host "3. S3バケット名の取得..." -ForegroundColor Yellow
    $bucketList = aws s3 ls | Select-String "cryptography-layer"
    if (-not $bucketList) {
        throw "エラー: S3バケットが見つかりません"
    }
    $bucketName = ($bucketList.ToString() -split '\s+')[2]
    Write-Host "  - S3バケット: $bucketName" -ForegroundColor Cyan

    # 4. S3へのLayerファイルアップロード
    Write-Host "4. S3へのLayerファイルアップロード..." -ForegroundColor Yellow
    aws s3 cp lambda-layer/cryptography-layer.zip "s3://$bucketName/cryptography-layer.zip"

    # 5. Phase 2スタックの再更新（Layer作成）
    Write-Host "5. Phase 2スタックの再更新（Layer作成）..." -ForegroundColor Yellow
    uv run sceptre update "$Environment/phase-2-dkim-system.yaml" --yes

    # 6. 新しいLayerバージョンの取得
    Write-Host "6. 新しいLayerバージョンの取得..." -ForegroundColor Yellow
    $latestVersion = aws lambda list-layers --region $Region --query "Layers[?contains(LayerName, 'cryptography')].LatestMatchingVersion.Version" --output text
    $accountId = aws sts get-caller-identity --query Account --output text
    $layerArn = "arn:aws:lambda:$Region`:$accountId`:layer:$ProjectName-$Environment-cryptography`:$latestVersion"
    Write-Host "  - Layer ARN: $layerArn" -ForegroundColor Cyan

    # 7. Lambda関数のLayer更新
    Write-Host "7. Lambda関数のLayer更新..." -ForegroundColor Yellow
    aws lambda update-function-configuration --function-name "$ProjectName-$Environment-dkim-manager" --layers "$layerArn" --region $Region

    # 8. 動作確認
    Write-Host "8. 動作確認..." -ForegroundColor Yellow
    # テストペイロードの作成
    $testPayload = @{
        phase = "3"
        action = "phase_manager"
        domain = "goo.ne.jp"
        dkimSeparator = "gooid-21-pro"
        environment = $Environment
        projectName = $ProjectName
    } | ConvertTo-Json -Compress

    $testPayload | Out-File -FilePath test-payload.json -Encoding utf8

    # Lambda関数のテスト
    aws lambda invoke --function-name "$ProjectName-$Environment-dkim-manager" --payload fileb://test-payload.json --region $Region response.json

    # 結果の確認
    Write-Host "  - 実行結果:" -ForegroundColor Cyan
    Get-Content response.json | ConvertFrom-Json | ConvertTo-Json -Depth 10

    Write-Host ""
    Write-Host "=== Layer作成完了 ===" -ForegroundColor Green
    Write-Host "Layer ARN: $layerArn"
    Write-Host "Lambda関数: $ProjectName-$Environment-dkim-manager"

} catch {
    Write-Host "エラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
