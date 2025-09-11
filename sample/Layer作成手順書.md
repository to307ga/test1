# Layer作成手順書

## 概要
DKIM Manager Lambda用のCryptography LayerをCloudFormationで自動化する手順

## 前提条件

### 必要な環境・ツール
- AWS CLI設定済み（適切な権限を持つ）
- Sceptre環境構築済み
- Python環境（uv使用）
- PowerShell（Windows環境の場合）

### 必要なスタックの完了状況
- **Phase 1**: `prod/phase-1-infrastructure-foundation.yaml` が完了していること
  - DKIM Manager Lambda実行ロール
  - DKIM設定用Secrets Manager
  - DKIM証明書用S3バケット
  - DKIM暗号化用KMSキー
- **Phase 2**: `prod/phase-2-dkim-system.yaml` が完了していること（Layer作成機能追加済み）
  - DKIM Manager Lambda関数
  - Cryptography Layer用S3バケット
  - Cryptography LayerVersionリソース
  - 関連するIAMロールとポリシー

### ファイル・ディレクトリ構造
```
AWS_BYODMIM/
├── lambda-layer/
│   └── cryptography-layer.zip  # このファイルが存在すること
├── sceptre/
│   ├── config/prod/
│   │   ├── phase-1-infrastructure-foundation.yaml
│   │   └── phase-2-dkim-system.yaml
│   └── templates/
│       └── dkim-manager-lambda.yaml
└── scripts/
    ├── create-layer.sh
    └── create-layer.ps1
```

### 確認方法
```bash
# Phase 1の完了確認
uv run sceptre describe prod/phase-1-infrastructure-foundation.yaml

# Phase 2の完了確認
uv run sceptre describe prod/phase-2-dkim-system.yaml

# Layerファイルの存在確認
ls lambda-layer/cryptography-layer.zip
```

## 手順

### 自動化スクリプトを使用する場合（推奨）

```bash
# Bash版スクリプト
./scripts/create-layer.sh prod aws-byodmim

# PowerShell版スクリプト
.\scripts\create-layer.ps1 -Environment prod -ProjectName aws-byodmim
```

**スクリプトを使用すると以下の手順が自動化されます：**
- Layerファイルの準備
- S3バケット作成
- S3へのLayerファイルアップロード
- Layer作成
- Lambda関数のLayer更新
- 動作確認テスト

---

### 手動で実行する場合

### 1. Layerファイルの準備
```bash
# lambda-layerディレクトリに移動
cd lambda-layer

# cryptographyライブラリのインストール
uv pip install cryptography --target python/

# Layerファイルの作成
powershell "Compress-Archive -Path python -DestinationPath cryptography-layer.zip -Force"
```

### 2. S3へのLayerファイルアップロード
```bash
# S3バケット名を確認
BUCKET_NAME=$(aws s3 ls | grep cryptography-layer | awk '{print $3}')
echo "S3バケット: $BUCKET_NAME"

# Layerファイルをアップロード
aws s3 cp lambda-layer/cryptography-layer.zip s3://$BUCKET_NAME/cryptography-layer.zip
```

### 3. Phase 2スタックの更新（Layer作成）
```bash
cd ../sceptre
# S3にアップロードしたLayerファイルを使用してLayerVersionリソースを作成
uv run sceptre update prod/phase-2-dkim-system.yaml --yes
```

### 4. Lambda関数のLayer更新
```bash
# 新しいLayerバージョンを確認
aws lambda list-layers --region ap-northeast-1 --query "Layers[?contains(LayerName, 'cryptography')]"

# 最新のLayerバージョンを取得
LATEST_VERSION=$(aws lambda list-layers --region ap-northeast-1 --query "Layers[?contains(LayerName, 'cryptography')].LatestMatchingVersion.Version" --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAYER_ARN="arn:aws:lambda:ap-northeast-1:$ACCOUNT_ID:layer:aws-byodmim-prod-cryptography:$LATEST_VERSION"

# Lambda関数を新しいLayerに更新
aws lambda update-function-configuration --function-name aws-byodmim-prod-dkim-manager --layers "$LAYER_ARN" --region ap-northeast-1
```

### 5. 動作確認
```bash
# テストペイロードの作成
powershell "echo '{\"phase\": \"3\", \"action\": \"phase_manager\", \"domain\": \"goo.ne.jp\", \"dkimSeparator\": \"gooid-21-pro\", \"environment\": \"prod\", \"projectName\": \"aws-byodmim\"}' | Out-File -FilePath test-payload.json -Encoding utf8"

# Lambda関数のテスト
aws lambda invoke --function-name aws-byodmim-prod-dkim-manager --payload fileb://test-payload.json --region ap-northeast-1 response.json

# 結果の確認
cat response.json
```

## 注意事項
- **推奨**: 自動化スクリプト（`create-layer.sh` または `create-layer.ps1`）を使用
- Layerファイルは手動でS3にアップロードする必要がある（スクリプトで自動化）
- CloudFormationではS3オブジェクトの作成を自動化できない
- 新しいLayerバージョンが作成されたら、Lambda関数の設定も手動で更新する必要がある（スクリプトで自動化）

## トラブルシューティング
- S3バケットが存在しない場合：Phase 2スタックを先に更新
- Layerアップロードエラー：ファイルパスとバケット名を確認
- Lambda関数エラー：LayerバージョンとLambda関数の設定を確認
