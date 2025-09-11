# Cryptography Layer作成スクリプト (PowerShell版)

param(
    [string]$Environment = "prod",
    [string]$ProjectName = "aws-ses-migration",
    [string]$Region = "ap-northeast-1"
)

Write-Host "=== Cryptography Layer作成スクリプト ===" -ForegroundColor Green
Write-Host "Environment: $Environment"
Write-Host "Project Name: $ProjectName"
Write-Host "Region: $Region"
Write-Host ""

try {
    # 前提条件チェック
    Write-Host "1. 前提条件チェック..." -ForegroundColor Yellow

    # Phase 1, 2スタックの確認
    try {
        uv run sceptre describe "$Environment/phase-1-infrastructure-foundation.yaml" | Out-Null
    }
    catch {
        Write-Host "エラー: Phase 1スタックが完了していません。" -ForegroundColor Red
        exit 1
    }

    try {
        uv run sceptre describe "$Environment/phase-2-dkim-system.yaml" | Out-Null
    }
    catch {
        Write-Host "エラー: Phase 2スタックが完了していません。" -ForegroundColor Red
        exit 1
    }

    Write-Host "✅ 前提条件確認完了" -ForegroundColor Green

    # 2. Layerファイルの準備
    Write-Host "2. Layerファイルの準備..." -ForegroundColor Yellow

    # lambda-layerディレクトリの作成
    if (!(Test-Path "lambda-layer")) {
        New-Item -ItemType Directory -Path "lambda-layer" | Out-Null
    }
    if (!(Test-Path "lambda-layer/python")) {
        New-Item -ItemType Directory -Path "lambda-layer/python" | Out-Null
    }

    # cryptographyライブラリのインストール
    Write-Host "cryptographyライブラリをインストール中..." -ForegroundColor Cyan
    Set-Location "lambda-layer"
    uv pip install cryptography --target python/ --platform linux_x86_64 --only-binary=:all:

    # Layerファイルの作成
    Write-Host "Layerファイルを作成中..." -ForegroundColor Cyan
    if (Test-Path "cryptography-layer.zip") {
        Remove-Item "cryptography-layer.zip" -Force
    }
    Compress-Archive -Path "python" -DestinationPath "cryptography-layer.zip" -Force

    Write-Host "✅ cryptography-layer.zip 作成完了" -ForegroundColor Green
    Set-Location ".."

    # 3. S3バケット名の取得
    Write-Host "3. S3バケット情報取得..." -ForegroundColor Yellow

    try {
        $bucketOutput = uv run sceptre describe "$Environment/phase-2-dkim-system.yaml" --format json | ConvertFrom-Json
        $bucketName = $bucketOutput.CryptographyLayerBucket
    }
    catch {
        Write-Host "S3バケット名を直接取得中..." -ForegroundColor Cyan
        $accountId = aws sts get-caller-identity --query Account --output text
        $bucketName = "$ProjectName-$Environment-cryptography-layer-$accountId"
    }

    Write-Host "S3バケット: $bucketName" -ForegroundColor Cyan

    # 4. S3へのLayerファイルアップロード
    Write-Host "4. S3へのLayerファイルアップロード..." -ForegroundColor Yellow

    try {
        aws s3 ls "s3://$bucketName" | Out-Null
        aws s3 cp "lambda-layer/cryptography-layer.zip" "s3://$bucketName/cryptography-layer.zip"
        Write-Host "✅ Layerファイルのアップロード完了" -ForegroundColor Green
    }
    catch {
        Write-Host "エラー: S3バケット '$bucketName' が存在しません。Phase 2スタックを確認してください。" -ForegroundColor Red
        exit 1
    }

    # 5. スタックの更新（Layer作成）
    Write-Host "5. Phase 2スタックの更新（Layer作成）..." -ForegroundColor Yellow
    uv run sceptre update "$Environment/phase-2-dkim-system.yaml" --yes

    Write-Host "✅ Layer作成完了" -ForegroundColor Green

    # 6. 作成されたLayerの確認
    Write-Host "6. 作成されたLayerの確認..." -ForegroundColor Yellow
    $layerArn = aws lambda list-layers --region $Region --query "Layers[?contains(LayerName, '$ProjectName-$Environment-cryptography')].LayerArn" --output text
    $latestVersion = aws lambda list-layers --region $Region --query "Layers[?contains(LayerName, '$ProjectName-$Environment-cryptography')].LatestMatchingVersion.Version" --output text

    if ($layerArn -and $latestVersion) {
        Write-Host "✅ Layer作成成功" -ForegroundColor Green
        Write-Host "Layer ARN: $layerArn" -ForegroundColor Cyan
        Write-Host "Latest Version: $latestVersion" -ForegroundColor Cyan
    } else {
        Write-Host "❌ Layer作成に失敗した可能性があります。手動で確認してください。" -ForegroundColor Red
        exit 1
    }

    # 7. 動作確認テスト
    Write-Host "7. Lambda関数の動作確認テスト..." -ForegroundColor Yellow

    # テストペイロードの作成
    $testPayload = @{
        phase = "2"
        action = "test_layer"
        domain = "goo.ne.jp"
        environment = $Environment
        projectName = $ProjectName
    } | ConvertTo-Json

    $testPayload | Out-File -FilePath "test-payload.json" -Encoding utf8

    # Lambda関数のテスト
    $functionName = "$ProjectName-$Environment-dkim-manager"
    Write-Host "Lambda関数 '$functionName' をテスト中..." -ForegroundColor Cyan

    try {
        aws lambda invoke --function-name $functionName --payload fileb://test-payload.json --region $Region response.json | Out-Null
        Write-Host "✅ Lambda関数テスト成功" -ForegroundColor Green

        if (Test-Path "response.json") {
            Write-Host "レスポンス:" -ForegroundColor Cyan
            Get-Content "response.json"
            Write-Host ""
            Remove-Item "response.json" -Force
        }
    }
    catch {
        Write-Host "❌ Lambda関数テストに失敗しました。" -ForegroundColor Red
    }

    # クリーンアップ
    if (Test-Path "test-payload.json") {
        Remove-Item "test-payload.json" -Force
    }

    Write-Host "=== Layer作成スクリプト完了 ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "次のステップ:" -ForegroundColor Yellow
    Write-Host "1. Phase 3でSES Email Identityを作成"
    Write-Host "2. EasyDKIMを無効化: .\scripts\disable-easydkim.ps1"
    Write-Host "3. Phase 4以降でBYODKIMを設定"

} catch {
    Write-Host "エラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
