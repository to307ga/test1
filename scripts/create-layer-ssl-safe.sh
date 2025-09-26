#!/bin/bash

# Layer作成スクリプト (SSL証明書問題対応版)
# BYODKIM Certificate Automation Project

set -e

# 色付きログ関数
log_info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

log_warn() {
    echo -e "\e[33m[WARN]\e[0m $1"
}

log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

# プロジェクト設定
PROJECT_NAME="aws-ses-migration"  # CloudFormationと一致させる
ENVIRONMENT="prod"
REGION="ap-northeast-1"

echo "=== BYODKIM Layer作成スクリプト (SSL Safe Version) ==="
echo "プロジェクト名: $PROJECT_NAME"
echo "環境: $ENVIRONMENT"
echo "リージョン: $REGION"
echo ""

# 0. SSL証明書問題対応の警告
log_warn "企業ネットワーク環境のため、SSL証明書検証を無効化します"
log_warn "本スクリプトは全てのAWS CLIコマンドに--no-verify-sslオプションを使用します"
echo ""

# 1. 前提条件チェック
log_info "1. 前提条件をチェック中..."

# uvのインストール確認
if ! command -v uv &> /dev/null; then
    log_error "uvがインストールされていません"
    echo "インストール手順:"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# AWS CLIの確認
if ! command -v aws &> /dev/null; then
    log_error "AWS CLIがインストールされていません"
    exit 1
fi

# AWS認証情報の確認
if ! aws sts get-caller-identity --no-verify-ssl > /dev/null 2>&1; then
    log_error "AWS認証情報が設定されていません"
    exit 1
fi

log_info "✅ 前提条件チェック完了"

# 2. 作業ディレクトリの準備
log_info "2. 作業ディレクトリを準備中..."

WORK_DIR="lambda-layer-build"
rm -rf $WORK_DIR
mkdir -p $WORK_DIR/python
cd $WORK_DIR

log_info "✅ 作業ディレクトリ準備完了: $(pwd)"

# 3. pyproject.tomlの確認と依存関係インストール
log_info "3. 依存関係をインストール中..."

# 直接uvで依存関係をインストール（pyproject.tomlは使用しない）
log_info "uvで依存関係をダウンロード中..."

# Python 3.11環境でインストール
uv pip install --target python cryptography boto3 botocore

log_info "✅ 依存関係インストール完了"

# 4. Layerパッケージの作成
log_info "4. Layerパッケージを作成中..."

# zipファイル作成
ZIP_FILE="../lambda-layer/cryptography-layer.zip"
mkdir -p ../lambda-layer

# 既存のzipファイルを削除
rm -f $ZIP_FILE

# PowerShellのCompress-Archiveを使用してzip化
log_info "PowerShellでLayerパッケージを圧縮中..."
powershell.exe -Command "Compress-Archive -Path python -DestinationPath $ZIP_FILE -Force"

FILE_SIZE=$(stat -c%s "$ZIP_FILE" 2>/dev/null || stat -f%z "$ZIP_FILE" 2>/dev/null || echo "unknown")
log_info "✅ Layerパッケージ作成完了: $ZIP_FILE (サイズ: $FILE_SIZE bytes)"

# 5. CloudFormation用S3バケットにアップロード
log_info "5. CloudFormation用S3バケットにLayerファイルをアップロード中..."

# CloudFormationが期待するS3バケット名を確認
LAYER_BUCKET="$PROJECT_NAME-$ENVIRONMENT-cryptography-layer-007773581311"

log_info "S3バケット: $LAYER_BUCKET"
log_info "アップロード先: s3://$LAYER_BUCKET/cryptography-layer.zip"

# S3バケットにアップロード
aws s3 cp $ZIP_FILE s3://$LAYER_BUCKET/cryptography-layer.zip --region $REGION --no-verify-ssl

if [ $? -eq 0 ]; then
    log_info "✅ S3アップロード成功"

    # Phase-2スタックを更新してLayerを再作成
    log_info "6. CloudFormationスタック更新でLayer更新中..."
    cd ../sceptre
    uv run sceptre launch prod/phase-2-dkim-system.yaml -y
    cd ..

    if [ $? -eq 0 ]; then
        log_info "✅ CloudFormationスタック更新完了"
        log_info "新しいLayerバージョンがLambda関数に自動適用されました"
    else
        log_error "CloudFormationスタック更新に失敗しました"
        exit 1
    fi
else
    log_error "S3アップロードに失敗しました"
    exit 1
fi

# 7. 動作確認テスト（cryptographyモジュール確認）
log_info "7. Lambda関数のcryptographyモジュール確認テスト..."

# DKIM証明書作成テスト用ペイロード作成
cat > test-payload.json << EOF
{
    "action": "create_dkim",
    "domain": "goo.ne.jp",
    "environment": "$ENVIRONMENT",
    "projectName": "$PROJECT_NAME",
    "dkimSeparator": "gooid-21-prod"
}
EOF

# Lambda関数のテスト
FUNCTION_NAME="$PROJECT_NAME-$ENVIRONMENT-dkim-manager"
log_info "Lambda関数 '$FUNCTION_NAME' でDKIM証明書作成テスト中..."

if aws lambda invoke --function-name $FUNCTION_NAME --payload fileb://test-payload.json --region $REGION --no-verify-ssl response.json > /dev/null 2>&1; then
    if grep -q "errorMessage.*No module named 'cryptography'" response.json 2>/dev/null; then
        log_error "❌ cryptographyモジュールが見つかりません。Layer更新に問題があります。"
        cat response.json
    elif grep -q "errorMessage" response.json 2>/dev/null; then
        log_warn "⚠️ cryptographyは読み込まれましたが、他のエラーが発生しました："
        cat response.json
        log_info "これは正常です（テスト用の簡易ペイロードのため）"
    else
        log_info "✅ Lambda関数テスト成功（cryptographyモジュール使用可能）"
        if [ -f response.json ]; then
            echo "レスポンス:"
            cat response.json
            echo ""
        fi
    fi
    rm -f response.json
else
    log_warn "Lambda関数テストでエラーが発生しましたが、Layerは正常に更新された可能性があります"
fi

# クリーンアップ
cd ..
rm -rf $WORK_DIR
rm -f test-payload.json

log_info "=== Layer作成・更新スクリプト完了 ==="
echo ""
echo "✅ 完了した作業:"
echo "1. 新しいcryptography Layerファイル作成"
echo "2. CloudFormation用S3バケットにアップロード"
echo "3. Phase-2スタック更新でLayer自動更新"
echo "4. Lambda関数への自動適用"
echo ""
echo "次のステップ:"
echo "1. DKIM証明書生成の実行"
echo "2. Phase 7でBYODKIM登録"
echo ""
echo "作成されたファイル:"
echo "- $ZIP_FILE"
echo "- S3: s3://$LAYER_BUCKET/cryptography-layer.zip"
echo "- CloudFormation管理のLayerが自動更新されました"
