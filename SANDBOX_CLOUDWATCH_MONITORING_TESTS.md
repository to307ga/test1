# CloudWatch監視テスト - サンドボックス環境対応表

## 🎯 **現在のサンドボックス環境で実行可能なテスト**

### ✅ **1. SESメトリクス監視テスト**
- **テスト内## 🎯 **期待される結果**

### **正常な監視システムの指標**:
- SES Send メトリクス: メール送信数と一致（グローバルレベル）
- S3ログファイル: 定期的な作成（2-5分間隔）
- アラーム状態: OK または INSUFFICIENT_DATA（Configuration Set固有メトリクス未記録のため）
- ダッシュボード: 5つのダッシュボードが利用可能

### **実測値（11:13メール通知検証結果）**:
- **SES Send**: UTC 02:10（JST 11:10）に正確に記録 ✅
- **SES Delivery**: UTC 02:10（JST 11:10）に正確に記録 ✅
- **S3配信**: 2-4分後に両方のバケットに配信完了 ✅
- **データマスキング**: 完璧に動作 ✅
- **メール通知**: 11:13に正確なタイミングで送信 ✅

### **制約事項**:
- Configuration Set固有メトリクス: CloudWatch Publishing未有効のため記録されず
- Firehoseメトリクス: メトリクス発行設定の問題で記録されず（実際の配信は正常）

### **異常検出時の確認項目**:
- CloudWatch Logsでのエラー確認
- IAM権限の確認
- S3バケット権限とアクセス状態
- **重要**: メトリクスが空でもS3ファイル作成を直接確認のCloudWatchメトリクス取得
- **対象メトリクス**:
  - `AWS/SES.Send` - 送信成功数
  - `AWS/SES.Delivery` - 配信成功数  
  - `AWS/SES.Bounce` - バウンス数（サンドボックスでは通常0）
  - `AWS/SES.Complaint` - 苦情数（サンドボックスでは通常0）
- **制約**: サンドボックス環境のため外部メール送信不可、内部テストメールのみ

### ✅ **2. Kinesis Firehose監視テスト**
- **テスト内容**: SESイベント→Kinesis Firehose→S3パイプライン監視
- **対象ストリーム**:
  - `aws-ses-migration-prod-raw-logs-stream` - 生ログストリーム
  - `aws-ses-migration-prod-masked-logs-stream` - マスク済みログストリーム
- **監視項目**:
  - `DeliveryToS3.Records` - S3配信レコード数
  - `DeliveryToS3.Success` - S3配信成功数
  - `DeliveryToS3.DataFreshness` - データ配信遅延

### ✅ **3. アラーム状態監視テスト**
- **現在設定済みアラーム**:
  - `aws-ses-migration-prod-ses-bounce-rate-high` (閾値: 5.0%)
  - `aws-ses-migration-prod-ses-complaint-rate-high` (閾値: 0.1%)  
  - `aws-ses-migration-prod-ses-sending-quota-usage-high` (閾値: 1920通)
- **テスト内容**: アラーム状態確認、閾値設定検証

### ✅ **4. CloudWatchダッシュボード確認テスト**
- **利用可能ダッシュボード**:
  - `aws-ses-migration-prod-monitoring` - メイン監視ダッシュボード
  - `aws-ses-migration-prod-security-dashboard` - セキュリティ監視
  - `aws-ses-migration-prod-japanese-security-dashboard` - 日本語セキュリティ監視
  - `aws-ses-migration-prod-tokyo-region-monitoring-dashboard` - 東京リージョン監視
  - `aws-ses-migration-prod-tokyo-region-security-metrics` - 東京リージョンセキュリティメトリクス

### ✅ **5. S3ログ監視テスト**
- **対象バケット**:
  - `aws-ses-migration-prod-raw-logs-007773581311` - 生ログバケット
  - `aws-ses-migration-prod-masked-logs-007773581311` - マスク済みログバケット
- **監視項目**:
  - ログファイル作成頻度
  - ファイルサイズ推移
  - データマスキング動作確認

### ✅ **6. Lambda変換処理監視テスト**
- **対象Lambda**:
  - Raw Logs変換Lambda - 生データ処理
  - Masked Logs変換Lambda - データマスキング処理
- **監視項目**:
  - 実行数、エラー数、実行時間
  - CloudWatch Logsでの処理ログ確認

## 🚫 **サンドボックス環境では制限されるテスト**

### ❌ **1. 外部ドメインへのメール送信テスト**
- **制約**: サンドボックス環境では検証済みメールアドレスのみ送信可能
- **現在の検証済みアドレス**: `goo-idpay-sys@ml.nttdocomo.com`

### ❌ **2. 実際のバウンス・苦情監視テスト**  
- **制約**: 検証済みアドレス間の送信のためバウンス・苦情が発生しない
- **代替**: 人工的なメトリクス投入によるテスト（API経由）

### ❌ **3. 大量送信負荷テスト**
- **制約**: サンドボックス環境の送信制限（24時間で200通）
- **現在の制限**: 24時間あたり最大200通、1秒あたり1通

## 🎯 **推奨テストシナリオ**

### **シナリオ1: クイック監視機能確認（5分）**
```bash
uv run python test_cloudwatch_monitoring.py
# 選択: 1 (クイックテスト)
```
- アラーム状態確認
- Firehoseメトリクス確認
- ダッシュボードリスト確認
- S3バケット最新活動確認

### **シナリオ2: フル監視機能テスト（10分）**
```bash  
uv run python test_cloudwatch_monitoring.py
# 選択: 2 (フルテスト)
```
- テストメール送信
- SESメトリクス更新確認
- Firehose配信確認
- S3ログファイル作成確認
- 全アラーム状態確認

### **シナリオ3: 継続監視テスト（1時間）**
```bash
# 複数回のメール送信による継続的なメトリクス監視
for i in {1..10}; do
  uv run python send_test_email.py
  echo "メール送信 $i/10 完了。5分待機..."
  sleep 300
done
```

## 📊 **期待される結果**

### **正常な監視システムの指標**:
- SES Send メトリクス: メール送信数と一致
- Firehose Records: SESイベント数と一致  
- S3ログファイル: 定期的な作成（5分間隔）
- アラーム状態: すべて OK または INSUFFICIENT_DATA
- ダッシュボード: 5つのダッシュボードが利用可能

### **異常検出時の確認項目**:
- CloudWatch Logsでのエラー確認
- IAM権限の確認
- Kinesis Firehose配信ストリームの状態
- S3バケット権限とアクセス状態

## 🚀 **テスト実行コマンド**

```bash
# サンドボックス環境CloudWatch監視テスト実行
cd C:/Temp/AWS_SES_BYODKIM
uv run python test_cloudwatch_monitoring.py
```
