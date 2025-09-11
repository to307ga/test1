#!/bin/bash

# Layer作成自動化スクリプト
# Usage: ./scripts/create-layer.sh [environment] [project-name]

set -e

# パラメータ設定
ENVIRONMENT=${1:-prod}
PROJECT_NAME=${2:-aws-byodmim}
REGION=${3:-ap-northeast-1}

echo "=== Layer作成自動化スクリプト ==="
echo "Environment: $ENVIRONMENT"
echo "Project: $PROJECT_NAME"
echo "Region: $REGION"
echo ""

# 1. Layerファイルの準備
echo "1. Layerファイルの準備..."
cd lambda-layer

# cryptographyライブラリのインストール
echo "  - cryptographyライブラリのインストール"
uv pip install cryptography --target python/

# Layerファイルの作成
echo "  - Layerファイルの作成"
if command -v zip &> /dev/null; then
    zip -r cryptography-layer.zip python/
else
    powershell "Compress-Archive -Path python -DestinationPath cryptography-layer.zip -Force"
fi

cd ../sceptre

# 2. Phase 2スタックの更新（S3バケット作成）
echo "2. Phase 2スタックの更新（S3バケット作成）..."
uv run sceptre update $ENVIRONMENT/phase-2-dkim-system.yaml --yes

# 3. S3バケット名の取得
echo "3. S3バケット名の取得..."
BUCKET_NAME=$(aws s3 ls | grep cryptography-layer | awk '{print $3}')
if [ -z "$BUCKET_NAME" ]; then
    echo "エラー: S3バケットが見つかりません"
    exit 1
fi
echo "  - S3バケット: $BUCKET_NAME"

# 4. S3へのLayerファイルアップロード
echo "4. S3へのLayerファイルアップロード..."
aws s3 cp lambda-layer/cryptography-layer.zip s3://$BUCKET_NAME/cryptography-layer.zip

# 5. Phase 2スタックの再更新（Layer作成）
echo "5. Phase 2スタックの再更新（Layer作成）..."
uv run sceptre update $ENVIRONMENT/phase-2-dkim-system.yaml --yes

# 6. 新しいLayerバージョンの取得
echo "6. 新しいLayerバージョンの取得..."
LATEST_VERSION=$(aws lambda list-layers --region $REGION --query "Layers[?contains(LayerName, 'cryptography')].LatestMatchingVersion.Version" --output text)
LAYER_ARN="arn:aws:lambda:$REGION:$(aws sts get-caller-identity --query Account --output text):layer:$PROJECT_NAME-$ENVIRONMENT-cryptography:$LATEST_VERSION"
echo "  - Layer ARN: $LAYER_ARN"

# 7. Lambda関数のLayer更新
echo "7. Lambda関数のLayer更新..."
aws lambda update-function-configuration --function-name $PROJECT_NAME-$ENVIRONMENT-dkim-manager --layers "$LAYER_ARN" --region $REGION

# 8. 動作確認
echo "8. 動作確認..."
# テストペイロードの作成
cat > test-payload.json << EOF
{"phase": "3", "action": "phase_manager", "domain": "goo.ne.jp", "dkimSeparator": "gooid-21-pro", "environment": "$ENVIRONMENT", "projectName": "$PROJECT_NAME"}
EOF

# Lambda関数のテスト
aws lambda invoke --function-name $PROJECT_NAME-$ENVIRONMENT-dkim-manager --payload fileb://test-payload.json --region $REGION response.json

# 結果の確認
echo "  - 実行結果:"
cat response.json
echo ""

echo "=== Layer作成完了 ==="
echo "Layer ARN: $LAYER_ARN"
echo "Lambda関数: $PROJECT_NAME-$ENVIRONMENT-dkim-manager"
