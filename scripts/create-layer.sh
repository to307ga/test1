#!/bin/bash
# Cryptography Layer作成スクリプト

set -e

ENVIRONMENT=${1:-prod}
PROJECT_NAME=${2:-aws-ses-migration}
REGION=${3:-ap-northeast-1}

echo "=== Cryptography Layer作成スクリプト ==="
echo "Environment: $ENVIRONMENT"
echo "Project Name: $PROJECT_NAME"
echo "Region: $REGION"
echo ""

# 前提条件チェック
echo "1. 前提条件チェック..."

# sceptreディレクトリに移動（スクリプトが実行される場所から相対的に）
cd sceptre

# Phase 1, 2スタックの確認
if ! uv run sceptre status $ENVIRONMENT/phase-1-infrastructure-foundation.yaml | grep -q "CREATE_COMPLETE"; then
    echo "エラー: Phase 1スタックが完了していません。"
    exit 1
fi

if ! uv run sceptre status $ENVIRONMENT/phase-2-dkim-system.yaml | grep -q "CREATE_COMPLETE"; then
    echo "エラー: Phase 2スタックが完了していません。"
    exit 1
fi

echo "✅ 前提条件確認完了"

# プロジェクトルートに戻る
cd ..

# 2. Layerファイルの準備
echo "2. Layerファイルの準備..."

# lambda-layerディレクトリの削除（既存の場合）
if [ -d "lambda-layer" ]; then
    echo "既存のlambda-layerディレクトリを削除中..."
    rm -rf lambda-layer
fi

# lambda-layerディレクトリの作成
mkdir -p lambda-layer/python

# cryptographyライブラリのインストール
echo "cryptographyライブラリをインストール中..."
cd lambda-layer
uv pip install cryptography --target python/

# Layerファイルの作成
echo "Layerファイルを作成中..."
if command -v zip > /dev/null; then
    zip -r cryptography-layer.zip python/
else
    # PowerShellでzip作成（Windows環境）
    powershell "Compress-Archive -Path python -DestinationPath cryptography-layer.zip -Force"
fi

echo "✅ cryptography-layer.zip 作成完了"
cd ..

# 3. S3バケット名の取得
echo "3. S3バケット情報取得..."

BUCKET_NAME=$(cd sceptre && uv run sceptre describe-stack-outputs $ENVIRONMENT/phase-2-dkim-system --format json | jq -r '.CryptographyLayerBucket' 2>/dev/null || echo "")

if [ -z "$BUCKET_NAME" ]; then
    echo "S3バケット名を直接取得中..."
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    # 正しいプロジェクト名を使用
    BUCKET_NAME="$PROJECT_NAME-$ENVIRONMENT-cryptography-layer-$ACCOUNT_ID"
fi

echo "S3バケット: $BUCKET_NAME"

# 4. S3へのLayerファイルアップロード
echo "4. S3へのLayerファイルアップロード..."

if aws s3 ls "s3://$BUCKET_NAME" > /dev/null 2>&1; then
    aws s3 cp lambda-layer/cryptography-layer.zip "s3://$BUCKET_NAME/cryptography-layer.zip"
    echo "✅ Layerファイルのアップロード完了"
else
    echo "エラー: S3バケット '$BUCKET_NAME' が存在しません。Phase 2スタックを確認してください。"
    exit 1
fi

# 5. スタックの更新（Layer作成）
echo "5. Phase 2スタックの更新（Layer作成）..."
cd sceptre && uv run sceptre update $ENVIRONMENT/phase-2-dkim-system.yaml --yes
cd ..

echo "✅ Layer作成完了"

# 6. 作成されたLayerの確認
echo "6. 作成されたLayerの確認..."
LAYER_ARN=$(aws lambda list-layers --region $REGION --query "Layers[?contains(LayerName, '$PROJECT_NAME-$ENVIRONMENT-cryptography')].LayerArn" --output text)
LATEST_VERSION=$(aws lambda list-layers --region $REGION --query "Layers[?contains(LayerName, '$PROJECT_NAME-$ENVIRONMENT-cryptography')].LatestMatchingVersion.Version" --output text)

if [ -n "$LAYER_ARN" ] && [ -n "$LATEST_VERSION" ]; then
    echo "✅ Layer作成成功"
    echo "Layer ARN: $LAYER_ARN"
    echo "Latest Version: $LATEST_VERSION"
else
    echo "❌ Layer作成に失敗した可能性があります。手動で確認してください。"
    exit 1
fi

# 7. 動作確認テスト
echo "7. Lambda関数の動作確認テスト..."

# テストペイロードの作成
cat > test-payload.json << EOF
{
    "phase": "2",
    "action": "test_layer",
    "domain": "goo.ne.jp",
    "environment": "$ENVIRONMENT",
    "projectName": "$PROJECT_NAME"
}
EOF

# Lambda関数のテスト
FUNCTION_NAME="$PROJECT_NAME-$ENVIRONMENT-dkim-manager"
echo "Lambda関数 '$FUNCTION_NAME' をテスト中..."

if aws lambda invoke --function-name $FUNCTION_NAME --payload fileb://test-payload.json --region $REGION response.json > /dev/null 2>&1; then
    echo "✅ Lambda関数テスト成功"
    if [ -f response.json ]; then
        echo "レスポンス:"
        cat response.json
        echo ""
        rm -f response.json
    fi
else
    echo "❌ Lambda関数テストに失敗しました。"
fi

# クリーンアップ
rm -f test-payload.json

echo "=== Layer作成スクリプト完了 ==="
echo ""
echo "次のステップ:"
echo "1. Phase 3でSES Email Identityを作成"
echo "2. EasyDKIMを無効化: ./scripts/disable-easydkim.sh"
echo "3. Phase 4以降でBYODKIMを設定"
