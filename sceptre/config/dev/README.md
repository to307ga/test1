# 開発環境デプロイ手順書

## 重要な修正事項（2025年9月11日）- dev環境用

### ❌ dev環境での注意すべき点
**dev環境はEmailIdentity共有方式のため、以下が異なります**：
- ❌ **EasyDKIM無効化は不要**: prod環境で既に実行済み
- ❌ **EmailIdentity作成は不要**: prod環境のものを共有
- ✅ **BYODKIM登録はPhase 7で実行**: dev専用セレクタ`gooid-21-dev`

### ✅ dev環境での正しい手順
**dev環境特有のBYODKIM登録方法**：
- dev専用セレクタ: `gooid-21-dev`
- `phase_manager` の `phase=7` でdev用BYODKIM登録
- prod環境への影響なし（異なるセレクタ使用）

---

## 概要
AWS SES BYODKIMシステムの開発環境です。EmailIdentity共有構成を使用します。

**重要**: dev環境はproduction環境の `goo.ne.jp` EmailIdentityを共有使用します。
production環境が先に構築済みであることを確認してください。

## 環境設定
- **環境**: dev
- **ドメイン**: goo.ne.jp (本番環境と共有)
- **DKIMセレクタ**: gooid-21-dev
- **EmailIdentity**: 本番環境と共有 (依存: production環境)

## 前提条件
1. Production環境が完全にデプロイ済み
2. Python環境とuvがインストール済み
3. AWS CLIが設定済み
4. 適切なAWS権限

## 開発環境セットアップ

### 1. 仮想環境セットアップ
```bash
uv sync
```

### 2. 基盤インフラストラクチャ
```bash
uv run sceptre launch dev/base.yaml -y
```

### 3. フェーズ 1: インフラ基盤
```bash
uv run sceptre launch dev/phase-1-infrastructure-foundation.yaml -y
```

### 4. フェーズ 2: DKIMシステム
```bash
uv run sceptre launch dev/phase-2-dkim-system.yaml -y
```
- Dev用のDKIMマネージャLambda関数とLayerを作成
- Prodとは独立したDKIM処理システムが必要

#### 4.1 Layer作成（Phase 2後に必須）
```bash
# Dev環境用cryptographyライブラリのLayer作成
cd ..
./scripts/create-layer.sh dev aws-ses-migration
cd sceptre
```
**重要**: この手順はdev環境でも必須です。prod環境とは独立したLayerが作成されます。

### 5. フェーズ 3: SES BYODKIM設定（修正済み）
```bash
uv run sceptre launch dev/phase-3-ses-byodkim.yaml -y
```
- Dev用のConfigurationSetとEventDestinationを作成
- **注意**: EmailIdentityは作成せず、prodの `goo.ne.jp` を共有
- 新しいBYODKIMセレクタ `gooid-21-dev` を使用

**重要修正**: フェーズ 3では以下は**不要**です：
- ❌ **EasyDKIM無効化**: prodで既に実行済みのため不要
- ❌ **EmailIdentity作成**: prodのものを共有するため不要
- ❌ **以下のコマンドは実行しない**:
```bash
# ❌ 実行禁止: dev環境では不要
# ./scripts/disable-easydkim.sh goo.ne.jp dev
```

**理由**: dev環境はprod環境のEmailIdentityを共有するため、prodで既にEasyDKIMが無効化されています。

### 6. フェーズ 4: DNS準備
```bash
uv run sceptre launch dev/phase-4-dns-preparation.yaml -y
```
- Dev用BYODKIMキーペア（`gooid-21-dev`）の準備
- Prodとは異なるセレクタを使用

### 7. フェーズ 5: DNSチーム連携
```bash
uv run sceptre launch dev/phase-5-dns-team-collaboration.yaml -y
```
- DNS担当チームとの調整（dev専用レコード追加依頼）

#### 7.1 DNSチームへのSNSサブスクリプション設定
```bash
# Dev環境用SNSサブスクリプション作成
aws sns subscribe --topic-arn "arn:aws:sns:ap-northeast-1:007773581311:aws-ses-migration-dev-dns-team-notifications" --protocol email --notification-endpoint "goo-idpay-sys@ml.nttdocomo.com" --region ap-northeast-1

# 📧 確認メールが goo-idpay-sys@ml.nttdocomo.com に送信されます
# ✅ メール内の "Confirm subscription" リンクをクリック
# ❌ "Unsubscribe" リンクは絶対にクリックしない！
```

#### 7.2 DKIM証明書生成（dev用）
```bash
# dev環境用DKIM証明書生成ペイロード作成
cat > create-dkim-dev-payload.json << EOF
{
  "action": "create_dkim",
  "domain": "goo.ne.jp",
  "environment": "dev",
  "projectName": "aws-ses-migration",
  "dkimSeparator": "gooid-21-dev"
}
EOF

# DKIM証明書生成実行
aws lambda invoke --function-name aws-ses-migration-dev-dkim-manager --payload fileb://create-dkim-dev-payload.json response-create-dkim-dev.json

# 生成結果確認
cat response-create-dkim-dev.json
```

#### 7.3 DNSチームへの通知送信
```bash
# Phase-5 DNS通知用ペイロード作成（dev環境用）
cat > phase5-dev-manager-payload.json << EOF
{
  "action": "phase_manager",
  "phase": "5",
  "domain": "goo.ne.jp",
  "environment": "dev",
  "projectName": "aws-ses-migration",
  "dkimSeparator": "gooid-21-dev"
}
EOF

# DNSチームへの通知実行（開発環境用）
aws lambda invoke --function-name aws-ses-migration-dev-dkim-manager --payload fileb://phase5-dev-manager-payload.json response-phase5-dev-manager.json

# 通知送信結果確認
cat response-phase5-dev-manager.json
```

#### 7.4 dev環境用BYODKIM登録（重要な追加ステップ）
```bash
# ⚠️ 重要: dev環境でもPhase 7実行によるBYODKIM登録が必要
# dev環境用Phase 7実行ペイロード作成
cat > phase7-dev-byodkim-payload.json << EOF
{
  "action": "phase_manager",
  "phase": "7",
  "domain": "goo.ne.jp",
  "environment": "dev",
  "projectName": "aws-ses-migration",
  "dkimSeparator": "gooid-21-dev"
}
EOF

# dev環境用Phase 7実行（put_email_identity_dkim_signing_attributes API でdev用BYODKIM登録）
aws lambda invoke --function-name aws-ses-migration-dev-dkim-manager --payload fileb://phase7-dev-byodkim-payload.json response-phase7-dev-byodkim.json

# dev環境登録結果確認
cat response-phase7-dev-byodkim.json

# SES設定の確認（dev用セレクタが登録されることを確認）
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1 --query 'DkimAttributes'
# 期待値: {"SigningAttributesOrigin": "EXTERNAL", "SigningEnabled": true, "Status": "PENDING", "Tokens": ["gooid-21-dev-20250911-1"]}

# 📋 重要: dev環境も Phase 7実行により put_email_identity_dkim_signing_attributes API が呼び出され、dev専用BYODKIMが登録されます
# 📋 注意: prod環境とは異なるセレクタ（gooid-21-dev）を使用するため、prod環境への影響はありません
```

#### 7.5 SNSサブスクリプション状態確認
```bash
# ⚠️ 重要: DNS通知が届かない場合の対処
# SNSサブスクリプション状態確認
aws sns list-subscriptions-by-topic --topic-arn "arn:aws:sns:ap-northeast-1:007773581311:aws-ses-migration-dev-dns-team-notifications" --region ap-northeast-1

# この場合は 7.1 でサブスクリプションを再作成する
```

### 8. フェーズ 6: DNS設定
```bash
uv run sceptre launch dev/phase-6-dns-setup.yaml -y
```
- **新規追加**: `gooid-21-dev._domainkey.goo.ne.jp` TXTレコード
- **注意**: 既存のprodレコードには影響なし（異なるセレクタ）

### 9. フェーズ 7: DNS検証・DKIM有効化（修正済み手順）
```bash
# ⚠️ 重要修正: Phase 7は 7.4で実行済み（BYODKIM登録）
# ここでは DNS設定完了後にCloudFormationスタックをデプロイ

# DNS設定完了確認（dev専用セレクタ）
dig TXT gooid-21-dev-20250911-1._domainkey.goo.ne.jp
dig TXT gooid-21-dev-20250911-2._domainkey.goo.ne.jp
dig TXT gooid-21-dev-20250911-3._domainkey.goo.ne.jp

# DNS設定完了後、CloudFormationスタックをデプロイ
uv run sceptre launch dev/phase-7-dns-validation-dkim-activation.yaml -y
```
**作成されるリソース:**
- Dev用DNS検証Lambda
- Dev用DKIM検証処理
- Dev用検証結果通知

**📋 注意**: 
- 7.4でdev用BYODKIMは既にSESに登録済み
- ここではDNS検証とCloudFormationリソースの作成のみ

### 10. フェーズ 8: 監視システム
```bash
uv run sceptre launch dev/phase-8-monitoring-system.yaml -y
```
- Dev用の監視設定（より緩和された閾値）
- コスト削減のため一部機能を無効化

### 11. Enhanced Kinesis データ処理
```bash
uv run sceptre launch dev/enhanced-kinesis.yaml -y
```
- Dev用のKinesis Data Firehoseとデータ変換Lambda
- ログデータの処理とS3への配信
- 開発環境用の軽量設定（バッファサイズ: 64MB、保持期間: 90日）

### 12. 監視・マスキング機能
```bash
uv run sceptre launch dev/monitoring.yaml -y
```
- 包括的なCloudWatchダッシュボードとアラーム
- 個人情報マスキング機能
- BYODKIM監視とログ分析
- 開発環境用の緩和されたアラート閾値

### 13. セキュリティ・アクセス制御
```bash
uv run sceptre launch dev/security.yaml -y
```
- 開発環境用IAMグループとユーザー
  - dev-admin: フル管理権限
  - dev-readonly: 読み取り専用権限
  - dev-monitoring: 監視権限
- セキュリティポリシーとアクセス制御
- 日本の法令準拠設定

## 状態確認

### スタック状態確認
```bash
uv run sceptre list dev
```

### 詳細状態確認
```bash
uv run sceptre status dev
```

### 特定スタックの確認
```bash
uv run sceptre describe dev/phase-3-ses-byodkim.yaml
```

## テストと検証

### 1. DKIM設定確認（Dev専用）
```bash
uv run sceptre outputs dev/phase-2-dkim-system.yaml
```

### 2. SES設定確認（共有EmailIdentity確認）
```bash
# Dev用ConfigurationSet確認
aws ses get-configuration-set --configuration-set-name aws-ses-migration-dev-config-set

# 共有EmailIdentity確認（prod作成済み）
aws sesv2 get-email-identity --email-identity goo.ne.jp
```

### 3. DNS レコード確認（Dev専用セレクタ）- 修正済み
```bash
# Dev専用BYODKIMセレクタ確認（修正済みセレクタ名）
dig TXT gooid-21-dev-20250911-1._domainkey.goo.ne.jp
dig TXT gooid-21-dev-20250911-2._domainkey.goo.ne.jp
dig TXT gooid-21-dev-20250911-3._domainkey.goo.ne.jp

# Prod BYODKIMセレクタも共存確認（prod環境のセレクタ）
dig TXT gooid-21-prod-20250911-1._domainkey.goo.ne.jp

# EmailIdentity全体のDKIM状態確認（共有リソース）
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1 --query 'DkimAttributes'
# 期待値: {"SigningAttributesOrigin": "EXTERNAL", "SigningEnabled": true, "Tokens": ["gooid-21-dev-20250911-1"]}
```

### 4. 監視アラーム確認（Dev用）
```bash
aws cloudwatch describe-alarms --alarm-names "*dev*"
```

## 重要事項

### EmailIdentity共有について（修正済み情報）
- **共有リソース**: `goo.ne.jp` EmailIdentity（prodで作成済み）
- **Dev独自**: `gooid-21-dev` BYODKIMセレクタ（dev専用）
- **同時利用**: Prod（`gooid-21-prod`）とDev（`gooid-21-dev`）のBYODKIMが同一ドメインで共存
- **❌ EasyDKIM無効化**: dev環境では不要（prodで実行済み）
- **✅ BYODKIM登録**: dev環境でもPhase 7実行が必要（dev専用セレクタ）

### DNS レコード構成（修正済み）
- Prod: `gooid-21-prod-YYYYMMDD-N._domainkey.goo.ne.jp`
- Dev: `gooid-21-dev-YYYYMMDD-N._domainkey.goo.ne.jp`
- **両方とも**同じドメインに存在
- **セレクタ異なり**: prod/dev で異なるため競合なし

### dev環境でのBYODKIM実装（重要）
1. **Step 7.2**: DKIM証明書生成（dev専用）
2. **Step 7.4**: Phase 7実行によるdev用BYODKIM登録
3. **Step 7.3**: DNS通知送信（dev用レコード）
4. **Step 8**: DNS設定（dev専用TXTレコード追加）
5. **Step 9**: DNS検証とCloudFormationデプロイ

## クリーンアップ (開発環境)

### 全スタック削除（逆順）
```bash
uv run sceptre delete dev/phase-8-monitoring-system.yaml -y
uv run sceptre delete dev/phase-7-dns-validation-dkim-activation.yaml -y
uv run sceptre delete dev/phase-6-dns-setup.yaml -y
uv run sceptre delete dev/phase-5-dns-team-collaboration.yaml -y
uv run sceptre delete dev/phase-4-dns-preparation.yaml -y
uv run sceptre delete dev/phase-3-ses-byodkim.yaml -y
uv run sceptre delete dev/phase-2-dkim-system.yaml -y
uv run sceptre delete dev/phase-1-infrastructure-foundation.yaml -y
uv run sceptre delete dev/base.yaml -y
```

## 開発環境固有の機能

### EmailIdentity共有
- Production環境の `goo.ne.jp` EmailIdentityを共有使用
- dev環境専用のDKIMセレクタ: `gooid-21-dev`
- Production環境への影響なし

### 開発用パラメータ
- CloudWatch LogRetention: 30日（本番: 365日）
- Lambda Memory: 256MB（本番: 512MB）
- Alert Thresholds: より緩和された設定
- Cost Optimization: 開発用の設定

### DNS設定
- TTL: 300秒（高速テスト用）
- Priority: low（非本番環境）
- Contact: dev-team@goo.ne.jp

## 本番環境との主な違い（修正済み）
| 項目 | Development | Production |
|------|-------------|------------|
| EmailIdentity | **共有使用（prod作成）** | **Primary Owner** |
| BYODKIM Selector | gooid-21-dev-YYYYMMDD-N | gooid-21-prod-YYYYMMDD-N |
| EasyDKIM無効化 | **不要（prodで実行済み）** | **必須手動ステップ** |
| BYODKIM登録 | **Phase 7実行（dev用）** | **Phase 7実行（prod用）** |
| CloudWatch保持期間 | 30日 | 2555日 |
| S3ログ保持期間 | 90日 | 2555日 |
| Lambda Memory | 256MB | 512MB |
| Lambda Timeout | 60秒 | 300秒 |
| アラート閾値 | 緩い設定 | 厳格設定 |
| IP制限 | VDI/大手町のみ | より厳格 |

## 注意事項（修正済み）
- **EmailIdentity共有**: 本番と同じgoo.ne.jpドメインを使用（共有リソース）
- **Production依存**: prod/ses.yamlが先にデプロイされている必要あり
- **❌ EasyDKIM無効化**: dev環境では不要（prodで実行済み）
- **✅ BYODKIM登録**: dev環境でもPhase 7実行が必要（dev専用セレクタ）
- **セレクタ分離**: dev用（gooid-21-dev）とprod用（gooid-21-prod）で完全分離
- **DNS設定**: dev専用TXTレコードの追加が必要
- **コスト最適化**: 開発環境は軽量・短期保持設定
- **セキュリティ**: 本番同等のIP制限を維持
- **テスト影響**: dev環境のテストはprod環境に影響しない

## トラブルシューティング

### よくある問題と解決方法

1. **EmailIdentity共有エラー**
   - Production環境が正常稼働していることを確認
   - IAM権限でCrossAccount参照権限があることを確認

2. **DNS設定エラー**
   - DNS担当チームとの調整状況を確認
   - 開発用のTXTレコードが正しく設定されているか確認

3. **監視アラーム作成失敗**
   - SESメトリクスが利用可能になるまで待機
   - SNSトピックが正常に作成されているか確認

## サポート
- 開発チーム: dev-team@goo.ne.jp
- DNSチーム: goo-idpay-sys@ml.nttdocomo.com
- 技術的問題: GitHub issueを作成

## 関連ドキュメント
- [本番環境デプロイガイド](../prod/README.md)
- [BYODKIM完全デプロイ手順書](../../BYODKIM完全デプロイ手順書.md)
- [システム設計書](../../sample/システム設計書.md)

### base.yaml（基本インフラ）

#### 基本設定
- **ProjectCode**: `ses-migration`
  - **パラメータの説明**: プロジェクト全体を識別するコード。すべてのリソース名のプレフィックスとして使用
  - **代入可能な値**: 英数字、ハイフン（-）、アンダースコア（_）、3-20文字
  - **デフォルト値**: ses-migration
  - **現在設定値**: ses-migration
  - **効果**: CloudFormation スタック、S3バケット、IAMロール等のリソース名に使用

- **Environment**: `development`
  - **パラメータの説明**: デプロイ環境を識別する文字列。リソース名や設定値の決定に使用
  - **代入可能な値**: development, dev, staging, production, prod
  - **デフォルト値**: production
  - **現在設定値**: development
  - **効果**: 環境別のリソース分離、設定値の自動調整（ログ保持期間等）

- **RetentionDays**: `90`
  - **パラメータの説明**: S3バケットでのログファイル保持期間（日数）
  - **代入可能な値**: 1〜2555の整数
  - **デフォルト値**: 2555（本番環境標準）
  - **現在設定値**: 90（開発環境用に短縮）
  - **効果**: ストレージコスト削減、コンプライアンス要件への対応

- **NotificationEmail**: `dev@goo.ne.jp`
  - **パラメータの説明**: アラートや通知を受信するメールアドレス
  - **代入可能な値**: 有効なメールアドレス形式
  - **デフォルト値**: admin@goo.ne.jp
  - **現在設定値**: dev@goo.ne.jp
  - **効果**: 障害通知、アラート受信、システム状況の把握

#### ネットワーク・セキュリティ設定
- **AllowedSourceIPs**:
  - **パラメータの説明**: SESリソースへのアクセスを許可するIPアドレス範囲のリスト
  - **代入可能な値**: CIDR表記のIPアドレス範囲（例: 10.0.0.0/8, 192.168.1.0/24）
  - **デフォルト値**: ["10.0.0.0/8"]
  - **現在設定値**: 
    ```yaml
    - "10.99.0.0/16"      # VDI/Ootemachi network
    - "10.88.80.0/20"     # VDI/Ootemachi network  
    - "10.80.11.0/28"     # VDI/Ootemachi network
    - "10.80.0.0/24"      # VDI/Ootemachi network
    - "10.99.0.0/24"      # VDI/Ootemachi network
    - "202.217.0.0/16"    # SplashTop network
    ```
  - **効果**: 不正アクセス防止、NTT DOCOMOネットワークからのアクセスのみ許可

#### S3設定
- **AccessLogDestinationBucket**: `service-logs-gooid-idhub`
  - **パラメータの説明**: S3アクセスログの保存先バケット名
  - **代入可能な値**: 既存のS3バケット名（小文字、数字、ハイフンのみ）
  - **デフォルト値**: なし（必須パラメータ）
  - **現在設定値**: service-logs-gooid-idhub
  - **効果**: S3アクセス履歴の監査、セキュリティ分析

- **S3AllowedActions**: 
  - **パラメータの説明**: サービスプリンシパルに許可するS3操作のリスト
  - **代入可能な値**: AWS S3 APIアクション名のリスト
  - **デフォルト値**: 基本的なS3操作セット
  - **現在設定値**: 
    ```yaml
    - "s3:AbortMultipartUpload"
    - "s3:DeleteObject"
    - "s3:GetBucketLocation"
    - "s3:GetObject"
    - "s3:ListBucket"
    - "s3:ListBucketMultipartUploads"
    - "s3:ListMultipartUploadParts"
    - "s3:PutObject"
    ```
  - **効果**: 最小権限の原則に基づくセキュリティ強化

### ses.yaml（SES設定）

#### SES基本設定
- **ProjectCode**: `ses-migration`
  - **パラメータの説明**: プロジェクト識別コード（base.yamlと同一値必須）
  - **代入可能な値**: 英数字、ハイフン、アンダースコア
  - **デフォルト値**: ses-migration
  - **現在設定値**: ses-migration
  - **効果**: SESリソース名の統一、他スタックとの連携

- **Environment**: `development`
  - **パラメータの説明**: デプロイ環境識別子（base.yamlと同一値必須）
  - **代入可能な値**: development, dev, staging, production, prod
  - **デフォルト値**: production
  - **現在設定値**: development
  - **効果**: 環境別のSES設定、Configuration Set名の決定

- **DomainName**: `goo.ne.jp`
  - **パラメータの説明**: SESで使用するドメイン名（本番環境と共有）
  - **代入可能な値**: 有効なドメイン名
  - **デフォルト値**: example.com
  - **現在設定値**: goo.ne.jp
  - **効果**: EmailIdentity設定、DKIM設定、DNS設定

- **CloudWatchLogRetentionDays**: `30`
  - **パラメータの説明**: SES関連のCloudWatch Logsログ保持期間
  - **代入可能な値**: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2555
  - **デフォルト値**: 2555（本番環境標準）
  - **現在設定値**: 30（開発環境用に短縮）
  - **効果**: ログストレージコスト削減、デバッグ期間の確保

#### IP制限設定
- **SESAllowedIPs**:
  - **パラメータの説明**: SES送信を許可するIPアドレスのリスト（CIDR表記）
  - **代入可能な値**: IPv4 CIDR表記のリスト（例: 192.168.1.100/32）
  - **デフォルト値**: ["0.0.0.0/0"]（制限なし）
  - **現在設定値**: 
    ```yaml
    - 202.217.75.88/32
    - 202.217.75.81/32
    ```
  - **効果**: 不正送信防止、特定IPからの送信のみ許可

- **EnableSESIPFiltering**: `"true"`
  - **パラメータの説明**: SESのIP制限機能の有効/無効設定
  - **代入可能な値**: "true", "false"（文字列形式）
  - **デフォルト値**: "false"
  - **現在設定値**: "true"
  - **効果**: IP制限ポリシーの適用/非適用

#### アラート閾値設定
- **BounceRateThreshold**: `10.0`
  - **パラメータの説明**: バウンス率アラートの閾値（パーセンテージ）
  - **代入可能な値**: 0.1〜100.0の数値
  - **デフォルト値**: 5.0（本番環境標準）
  - **現在設定値**: 10.0（開発環境用に緩和）
  - **効果**: バウンス率監視、送信品質管理

- **ComplaintRateThreshold**: `0.5`
  - **パラメータの説明**: 苦情率アラートの閾値（パーセンテージ）
  - **代入可能な値**: 0.01〜100.0の数値
  - **デフォルト値**: 0.1（本番環境標準）
  - **現在設定値**: 0.5（開発環境用に緩和）
  - **効果**: スパム判定回避、送信レピュテーション保護

- **SuccessRateThreshold**: `90.0`
  - **パラメータの説明**: 送信成功率アラートの閾値（パーセンテージ）
  - **代入可能な値**: 0.1〜100.0の数値
  - **デフォルト値**: 95.0（本番環境標準）
  - **現在設定値**: 90.0（開発環境用に緩和）
  - **効果**: 配信問題の早期発見、サービス品質維持

#### 依存関係
- **prod/ses.yaml**: EmailIdentity共有のため必須
  - **パラメータの説明**: 本番環境のSESスタックに依存（goo.ne.jpドメイン共有）
  - **効果**: ドメイン設定の重複回避、DNS設定の一元管理

- **dev/base.yaml**: S3バケット・SNSトピック参照
  - **パラメータの説明**: 基本インフラからリソース参照
  - **効果**: リソース間の連携、設定の一貫性確保

##### アラート閾値（開発環境用緩和設定）
- **BounceRateThreshold**: `10.0`
  - **パラメータの説明**: SESメール送信時のバウンス率がこの閾値を超えた場合にCloudWatchアラームが発火します
  - **代入可能な値**: 0.1〜100.0の数値（パーセンテージ）
  - **デフォルト値**: 5.0（本番環境標準値）
  - **現在設定値**: 10.0（開発環境用に緩和）
  - **効果**: バウンス率が10%を超えるとアラート通知が送信され、送信停止等の対応が可能

- **ComplaintRateThreshold**: `0.5`
  - **パラメータの説明**: SESメール送信時の苦情率がこの閾値を超えた場合にCloudWatchアラームが発火します
  - **代入可能な値**: 0.01〜100.0の数値（パーセンテージ）
  - **デフォルト値**: 0.1（本番環境標準値）
  - **現在設定値**: 0.5（開発環境用に緩和）
  - **効果**: 苦情率が0.5%を超えるとアラート通知が送信され、送信品質の改善が可能

- **SuccessRateThreshold**: `90.0`
  - **パラメータの説明**: SESメール送信成功率がこの閾値を下回った場合にCloudWatchアラームが発火します
  - **代入可能な値**: 0.1〜100.0の数値（パーセンテージ）
  - **デフォルト値**: 95.0（本番環境標準値）
  - **現在設定値**: 90.0（開発環境用に緩和）
  - **効果**: 送信成功率が90%を下回るとアラート通知が送信され、配信問題の早期発見が可能

### enhanced-kinesis.yaml（データ処理パイプライン）

#### Kinesis設定
- **BufferSize**: `64`
  - **パラメータの説明**: Kinesis Data Firehoseのバッファサイズ（MB）
  - **代入可能な値**: 1〜128の整数
  - **デフォルト値**: 128（本番環境標準）
  - **現在設定値**: 64（開発環境用に軽量化）
  - **効果**: S3への配信頻度調整、コスト最適化

- **BufferInterval**: `300`
  - **パラメータの説明**: Kinesis Data Firehoseのバッファ間隔（秒）
  - **代入可能な値**: 60〜900の整数
  - **デフォルト値**: 300
  - **現在設定値**: 300
  - **効果**: データ配信のリアルタイム性とコストのバランス調整

- **CompressionFormat**: `GZIP`
  - **パラメータの説明**: S3に保存するデータの圧縮形式
  - **代入可能な値**: UNCOMPRESSED, GZIP, ZIP, Snappy
  - **デフォルト値**: GZIP
  - **現在設定値**: GZIP
  - **効果**: ストレージコスト削減、転送効率化

- **RetentionDays**: `90`
  - **パラメータの説明**: Kinesisデータの保持期間（日数）
  - **代入可能な値**: 1〜2555の整数
  - **デフォルト値**: 2555（本番環境標準）
  - **現在設定値**: 90（開発環境用に短縮）
  - **効果**: ストレージコスト削減、データライフサイクル管理

#### アクセス制御
- **AdminIPRange**: `"10.0.0.0/8"`
  - **パラメータの説明**: 管理者アクセスを許可するIPアドレス範囲
  - **代入可能な値**: CIDR表記のIPアドレス範囲
  - **デフォルト値**: "10.0.0.0/8"
  - **現在設定値**: "10.0.0.0/8"
  - **効果**: 管理機能への不正アクセス防止

- **OperatorIPRange**: `"192.168.1.0/24"`
  - **パラメータの説明**: オペレータアクセスを許可するIPアドレス範囲
  - **代入可能な値**: CIDR表記のIPアドレス範囲
  - **デフォルト値**: "192.168.1.0/24"
  - **現在設定値**: "192.168.1.0/24"
  - **効果**: 運用機能への適切なアクセス制御

### monitoring.yaml（監視・マスキング機能）

#### アラート閾値
- **SendSuccessRateThreshold**: `95.0`
  - **パラメータの説明**: 送信成功率の監視閾値（パーセンテージ）
  - **代入可能な値**: 0.1〜100.0の数値
  - **デフォルト値**: 95.0
  - **現在設定値**: 95.0
  - **効果**: 送信品質の監視、配信問題の早期発見

- **BounceRateThreshold**: `5.0`
  - **パラメータの説明**: バウンス率の監視閾値（パーセンテージ）
  - **代入可能な値**: 0.1〜100.0の数値
  - **デフォルト値**: 5.0
  - **現在設定値**: 5.0
  - **効果**: 配信品質監視、送信レピュテーション保護

- **ComplaintRateThreshold**: `0.1`
  - **パラメータの説明**: 苦情率の監視閾値（パーセンテージ）
  - **代入可能な値**: 0.01〜100.0の数値
  - **デフォルト値**: 0.1
  - **現在設定値**: 0.1
  - **効果**: スパム判定回避、送信レピュテーション維持

#### Lambda設定
- **LambdaMemorySize**: `256`
  - **パラメータの説明**: Lambda関数に割り当てるメモリサイズ（MB）
  - **代入可能な値**: 128, 256, 512, 1024, 1536, 2048, 3008
  - **デフォルト値**: 512（本番環境標準）
  - **現在設定値**: 256（開発環境用に軽量化）
  - **効果**: コスト最適化、実行性能調整

- **LambdaTimeout**: `60`
  - **パラメータの説明**: Lambda関数の最大実行時間（秒）
  - **代入可能な値**: 1〜900の整数
  - **デフォルト値**: 300（本番環境標準）
  - **現在設定値**: 60（開発環境用に短縮）
  - **効果**: コスト削減、タイムアウトエラー防止

- **LambdaRuntime**: `python3.9`
  - **パラメータの説明**: Lambda関数の実行環境
  - **代入可能な値**: python3.7, python3.8, python3.9, python3.10, python3.11
  - **デフォルト値**: python3.9
  - **現在設定値**: python3.9
  - **効果**: 実行環境の統一、セキュリティアップデート対応

#### 機能フラグ
- **EnableCustomMetrics**: `"false"`
  - **パラメータの説明**: カスタムCloudWatchメトリクスの有効/無効
  - **代入可能な値**: "true", "false"（文字列形式）
  - **デフォルト値**: "true"（本番環境標準）
  - **現在設定値**: "false"（開発環境でコスト削減）
  - **効果**: 詳細監視とコストのバランス調整

- **EnableDataMasking**: `"true"`
  - **パラメータの説明**: 個人情報マスキング機能の有効/無効
  - **代入可能な値**: "true", "false"（文字列形式）
  - **デフォルト値**: "true"
  - **現在設定値**: "true"
  - **効果**: 個人情報保護、コンプライアンス対応

- **EnableBYODKIMMonitoring**: `"true"`
  - **パラメータの説明**: BYODKIM関連の監視機能の有効/無効
  - **代入可能な値**: "true", "false"（文字列形式）
  - **デフォルト値**: "true"
  - **現在設定値**: "true"
  - **効果**: DKIM署名の監視、認証問題の早期発見

#### BYODKIM設定
- **BYODKIMSelector**: `"gooid-21-dev"`
  - **パラメータの説明**: 開発環境用のDKIMセレクタ名
  - **代入可能な値**: 英数字とハイフン（1-63文字）
  - **デフォルト値**: "default"
  - **現在設定値**: "gooid-21-dev"（開発環境専用）
  - **効果**: 開発/本番環境のDKIM設定分離、テスト時の本番影響回避

### security.yaml（セキュリティ・アクセス制御）

#### ユーザー設定
- **AdminUsername**: `dev-admin`
  - **パラメータの説明**: 管理者権限を持つIAMユーザー名
  - **代入可能な値**: 英数字、ハイフン、アンダースコア（1-64文字）
  - **デフォルト値**: production-admin
  - **現在設定値**: dev-admin
  - **効果**: フル管理権限でのリソース操作、システム設定変更

- **ReadonlyUsername**: `dev-readonly`
  - **パラメータの説明**: 読み取り専用権限を持つIAMユーザー名
  - **代入可能な値**: 英数字、ハイフン、アンダースコア（1-64文字）
  - **デフォルト値**: production-readonly
  - **現在設定値**: dev-readonly
  - **効果**: システム状況確認、ログ閲覧（変更権限なし）

- **MonitoringUsername**: `dev-monitoring`
  - **パラメータの説明**: 監視専用権限を持つIAMユーザー名
  - **代入可能な値**: 英数字、ハイフン、アンダースコア（1-64文字）
  - **デフォルト値**: production-monitoring
  - **現在設定値**: dev-monitoring
  - **効果**: CloudWatch、ログ、メトリクスへの監視アクセス

#### 連絡先設定
- **AdminEmail**: `dev-admin@goo.ne.jp`
  - **パラメータの説明**: 管理者の連絡先メールアドレス
  - **代入可能な値**: 有効なメールアドレス形式
  - **デフォルト値**: admin@goo.ne.jp
  - **現在設定値**: dev-admin@goo.ne.jp
  - **効果**: 重要なアラート通知、セキュリティ通知の受信

- **ReadonlyEmail**: `dev-readonly@goo.ne.jp`
  - **パラメータの説明**: 読み取り専用ユーザーの連絡先メールアドレス
  - **代入可能な値**: 有効なメールアドレス形式
  - **デフォルト値**: readonly@goo.ne.jp
  - **現在設定値**: dev-readonly@goo.ne.jp
  - **効果**: レポート通知、システム状況通知の受信

- **MonitoringEmail**: `dev-monitoring@goo.ne.jp`
  - **パラメータの説明**: 監視ユーザーの連絡先メールアドレス
  - **代入可能な値**: 有効なメールアドレス形式
  - **デフォルト値**: monitoring@goo.ne.jp
  - **現在設定値**: dev-monitoring@goo.ne.jp
  - **効果**: 監視アラート、パフォーマンス通知の受信

#### 機能フラグ
- **EnableIPRestriction**: `"false"`
  - **パラメータの説明**: IP制限機能の有効/無効設定
  - **代入可能な値**: "true", "false"（文字列形式）
  - **デフォルト値**: "true"（本番環境標準）
  - **現在設定値**: "false"（開発環境で緩和）
  - **効果**: アクセス制限の厳格さ調整、開発時の利便性向上

- **EnablePersonalInformationProtection**: `"true"`
  - **パラメータの説明**: 個人情報保護機能の有効/無効設定
  - **代入可能な値**: "true", "false"（文字列形式）
  - **デフォルト値**: "true"
  - **現在設定値**: "true"
  - **効果**: 個人情報マスキング、コンプライアンス対応

- **EnableJapaneseSecurity**: `"true"`
  - **パラメータの説明**: 日本の法令に準拠したセキュリティ機能の有効/無効
  - **代入可能な値**: "true", "false"（文字列形式）
  - **デフォルト値**: "true"
  - **現在設定値**: "true"
  - **効果**: 個人情報保護法対応、日本のサイバーセキュリティ基準適用

## トラブルシューティング

### よくある問題

#### 1. Production依存エラー
```bash
# エラー例: EmailIdentity not found
# 解決法: Production SESスタックを先にデプロイ
sceptre launch prod/ses
```

#### 2. IP制限エラー
```bash
# エラー例: Access denied from current IP
# 解決法: AllowedSourceIPsに現在のIPを追加
# または VDI/大手町ネットワークから実行
```

#### 3. Lambda関数エラー
```bash
# Lambda関数のログ確認
aws logs tail /aws/lambda/ses-migration-development-data-masking --follow

# Lambda関数の設定確認
aws lambda get-function --function-name ses-migration-development-data-masking
```

#### 4. S3アクセスエラー
```bash
# S3バケットポリシー確認
aws s3api get-bucket-policy --bucket ses-migration-development-raw-logs

# S3バケットの存在確認
aws s3 ls | grep ses-migration-development
```

### デバッグ手順
```bash
# スタック作成の詳細ログ確認
sceptre launch dev/[stack-name] --debug

# CloudFormationイベント確認
aws cloudformation describe-stack-events \
  --stack-name ses-migration-development-[stack-name]

# リソース作成状況確認
aws cloudformation list-stack-resources \
  --stack-name ses-migration-development-[stack-name]
```

### ロールバック手順
```bash
# 問題のあるスタックの削除（依存関係逆順）
sceptre delete dev/security
sceptre delete dev/monitoring
sceptre delete dev/ses
sceptre delete dev/enhanced-kinesis
sceptre delete dev/base

# 再デプロイ
sceptre launch dev/base
sceptre launch dev/enhanced-kinesis
sceptre launch dev/ses
sceptre launch dev/monitoring
sceptre launch dev/security
```

## 性能監視とアラート

### CloudWatchダッシュボード
- **ダッシュボード名**: `ses-migration-development-dashboard`
- **監視項目**:
  - SES送信メトリクス
  - バウンス・苦情率
  - Kinesis処理状況
  - Lambda実行状況

### アラート設定
- **SNSトピック**: dev/base.yamlから自動設定
- **通知先**: dev@goo.ne.jp
- **アラート条件**: 開発環境用に緩和された閾値

## セキュリティ設定

### IAMユーザー権限
- **dev-admin**: フル管理権限
- **dev-readonly**: 読み取り専用権限
- **dev-monitoring**: 監視・ログ権限

### データ保護
- **S3暗号化**: KMS暗号化有効
- **個人情報マスキング**: Lambda関数による自動マスキング
- **ログ保持**: 開発環境用短期保持（90日）

## クリーンアップ

### 開発環境の削除
```bash
# 全スタックの削除（依存関係を考慮して逆順）
sceptre delete dev/security
sceptre delete dev/monitoring
sceptre delete dev/ses
sceptre delete dev/enhanced-kinesis
sceptre delete dev/base
```

### 削除前確認事項
- 重要なテストデータのバックアップ
- S3バケット内のデータ確認
- CloudWatchログの必要な情報の保存

### 注意事項
- **Production影響なし**: dev環境削除してもprod環境は影響なし
- **EmailIdentity共有**: goo.ne.jpドメイン設定は本番と共有のため削除されない
- **手動リソース**: 手動で作成したリソースは個別削除が必要

## 追加情報

### TRUE BYODKIM設定
開発環境では `gooid-21-dev` セレクタを使用してBYODKIMをテストします：

```bash
# DNS設定確認（開発用）
dig TXT gooid-21-dev._domainkey.goo.ne.jp

# BYODKIM検証
aws sesv2 get-email-identity-dkim-attributes \
  --email-identity goo.ne.jp \
  --region ap-northeast-1
```

### ログ分析
```bash
# CloudWatch Insightsクエリ実行例
aws logs start-query \
  --log-group-name "/aws/lambda/ses-migration-development-data-masking" \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/'
```

## 環境固有の設定

### 開発環境の特徴
- **ログ保持期間**: 30日（短縮版）
- **Lambda設定**: 軽量設定（128MB、30秒）
- **パスワードポリシー**: 緩い設定
- **通知先**: 開発用メールアドレス（dev@goo.ne.jp）
- **ドメイン**: goo.ne.jp（本番と同じドメイン）

### 注意事項
- 開発環境は本番データを含まない
- コストを最小限に抑える設定
- セキュリティは本番環境と同等レベルを維持
- 本番と同じドメイン（goo.ne.jp）を使用するため、DNS設定は慎重に行う

## パラメータ設定の詳細

### base.yaml（基本インフラ）

#### 基本設定
- **ProjectCode**: `ses-migration`
  - **意味**: プロジェクトを識別するコード
  - **代入可能な値**: 英数字、ハイフン、アンダースコア
  - **デフォルト値**: `ses-migration`
  - **現在設定値**: `ses-migration`

- **Environment**: `development`
  - **意味**: 環境識別子
  - **代入可能な値**: `dev`, `staging`, `prod`, `production`
  - **デフォルト値**: `production`
  - **現在設定値**: `development`

- **DomainName**: `goo.ne.jp`
  - **意味**: SESで使用するドメイン名
  - **代入可能な値**: 有効なドメイン名
  - **デフォルト値**: `goo.ne.jp`
  - **現在設定値**: `goo.ne.jp`

#### ネットワーク・セキュリティ
- **AllowedIPRanges**: `["10.0.0.0/8", "192.168.1.0/24"]`
  - **意味**: アクセスを許可するIPアドレス範囲
  - **代入可能な値**: CIDR表記のIPアドレス範囲のリスト
  - **デフォルト値**: `["10.0.0.0/8", "192.168.1.0/24"]`
  - **現在設定値**: `["10.0.0.0/8", "192.168.1.0/24"]`

#### ログ・保持設定
- **RetentionDays**: `90`
  - **意味**: S3バケットでのログ保持期間（日数）
  - **代入可能な値**: 1〜2555の整数
  - **デフォルト値**: `2555`
  - **現在設定値**: `90`（開発環境用に短縮）

- **CloudWatchLogRetentionDays**: `90`
  - **意味**: CloudWatch Logsでのログ保持期間（日数）
  - **代入可能な値**: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2555
  - **デフォルト値**: `2555`
  - **現在設定値**: `90`（開発環境用に短縮）

#### 通知設定
- **NotificationEmail**: `dev@goo.ne.jp`
  - **意味**: 通知を受け取るメールアドレス
  - **代入可能な値**: 有効なメールアドレス
  - **デフォルト値**: `admin@goo.ne.jp`
  - **現在設定値**: `dev@goo.ne.jp`

- **NotificationPhone**: `+81901234567`
  - **意味**: 通知を受け取る電話番号（SMS）
  - **代入可能な値**: E.164形式（+国コード-電話番号）
  - **デフォルト値**: `+81901234567`
  - **現在設定値**: `+81901234567`

#### Lambda設定
- **LambdaRuntime**: `python3.9`
  - **意味**: Lambda関数の実行環境
  - **代入可能な値**: `python3.7`, `python3.8`, `python3.9`, `python3.10`, `python3.11`
  - **デフォルト値**: `python3.9`
  - **現在設定値**: `python3.9`

- **LambdaTimeout**: `30`
  - **意味**: Lambda関数の最大実行時間（秒）
  - **代入可能な値**: 1〜900の整数
  - **デフォルト値**: `60`
  - **現在設定値**: `30`（開発環境用に短縮）

- **LambdaMemorySize**: `128`
  - **意味**: Lambda関数に割り当てるメモリ（MB）
  - **代入可能な値**: 128, 256, 512, 1024, 2048, 3008
  - **デフォルト値**: `256`
  - **現在設定値**: `128`（開発環境用に軽量化）

#### IAMパスワードポリシー
- **IAMPasswordPolicyMinimumLength**: `8`
  - **意味**: パスワードの最小文字数
  - **代入可能な値**: 6〜128の整数
  - **デフォルト値**: `12`
  - **現在設定値**: `8`（開発環境用に緩和）

- **IAMPasswordPolicyRequireSymbols**: `false`
  - **意味**: パスワードに記号を必須とするか
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `false`（開発環境用に緩和）

- **IAMPasswordPolicyRequireNumbers**: `true`
  - **意味**: パスワードに数字を必須とするか
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

- **IAMPasswordPolicyRequireUppercase**: `false`
  - **意味**: パスワードに大文字を必須とするか
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `false`（開発環境用に緩和）

- **IAMPasswordPolicyRequireLowercase**: `true`
  - **意味**: パスワードに小文字を必須とするか
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

#### 機能設定
- **EnableCustomMetrics**: `false`
  - **意味**: カスタムメトリクスの有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `false`（開発環境用に無効化）

- **EnableDataMasking**: `true`
  - **意味**: 個人情報マスキング機能の有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

- **EnableCloudWatchAlarms**: `false`
  - **意味**: CloudWatchアラームの有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `false`（開発環境用に無効化）

- **EnableInsightsQueries**: `true`
  - **意味**: CloudWatch Insightsクエリの有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

#### アラート閾値設定
- **BounceRateThreshold**: `10.0`
  - **意味**: バウンス率アラートの閾値（%）
  - **代入可能な値**: 0.1〜100.0の数値
  - **デフォルト値**: `5.0`
  - **現在設定値**: `10.0`（開発環境用に緩和）

- **ComplaintRateThreshold**: `1.0`
  - **意味**: 苦情率アラートの閾値（%）
  - **代入可能な値**: 0.01〜100.0の数値
  - **デフォルト値**: `0.1`
  - **現在設定値**: `1.0`（開発環境用に緩和）

- **SendSuccessRateThreshold**: `90.0`
  - **意味**: 送信成功率アラートの閾値（%）
  - **代入可能な値**: 0.1〜100.0の数値
  - **デフォルト値**: `95.0`
  - **現在設定値**: `90.0`（開発環境用に緩和）

#### SES機能設定
- **EnableBounceComplaintHandling**: `true`
  - **意味**: バウンス・苦情処理の有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

- **EnableDKIM**: `true`
  - **意味**: DKIM署名の有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

- **EnableDomainVerification**: `true`
  - **意味**: ドメイン検証の有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

#### IAM・セキュリティ設定
- **EnableIAMGroups**: `true`
  - **意味**: IAMグループの作成有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

- **EnableIAMUsers**: `true`
  - **意味**: IAMユーザーの作成有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

- **EnableIAMPolicies**: `true`
  - **意味**: IAMポリシーの作成有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

- **EnableAccessControl**: `true`
  - **意味**: アクセス制御の有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

- **EnableIPRestriction**: `false`
  - **意味**: IP制限の有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `false`（開発環境用に無効化）

- **EnablePersonalInformationProtection**: `true`
  - **意味**: 個人情報保護・マスキング機能の有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

#### ユーザー設定
- **AdminEmail**: `dev-admin@goo.ne.jp`
  - **意味**: Adminユーザーのメールアドレス
  - **代入可能な値**: 有効なメールアドレス
  - **デフォルト値**: `admin@goo.ne.jp`
  - **現在設定値**: `dev-admin@goo.ne.jp`

- **ReadonlyEmail**: `dev-readonly@goo.ne.jp`
  - **意味**: ReadOnlyユーザーのメールアドレス
  - **代入可能な値**: 有効なメールアドレス
  - **デフォルト値**: `readonly@goo.ne.jp`
  - **現在設定値**: `dev-readonly@goo.ne.jp`

- **MonitoringEmail**: `dev-monitoring@goo.ne.jp`
  - **意味**: Monitoringユーザーのメールアドレス
  - **代入可能な値**: 有効なメールアドレス
  - **デフォルト値**: `monitoring@goo.ne.jp`
  - **現在設定値**: `dev-monitoring@goo.ne.jp`

#### テスト用ユーザー名
- **TestAdminUsername**: `dev-admin`
  - **意味**: テスト用Adminユーザーのユーザー名
  - **代入可能な値**: 英数字、ハイフン、アンダースコア
  - **デフォルト値**: `production-admin`
  - **現在設定値**: `dev-admin`

- **TestReadonlyUsername**: `dev-readonly`
  - **意味**: テスト用ReadOnlyユーザーのユーザー名
  - **代入可能な値**: 英数字、ハイフン、アンダースコア
  - **デフォルト値**: `production-readonly`
  - **現在設定値**: `dev-readonly`

- **TestMonitoringUsername**: `dev-monitoring`
  - **意味**: テスト用Monitoringユーザーのユーザー名
  - **代入可能な値**: 英数字、ハイフン、アンダースコア
  - **デフォルト値**: `production-monitoring`
  - **現在設定値**: `dev-monitoring`

#### その他の設定
- **EnableLogging**: `true`
  - **意味**: ログ機能の有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

- **EnableMonitoring**: `true`
  - **意味**: 監視機能の有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

- **EnableSecurity**: `true`
  - **意味**: セキュリティ機能の有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

- **S3BucketVersioning**: `true`
  - **意味**: S3バケットのバージョニング有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

- **S3BucketEncryption**: `true`
  - **意味**: S3バケットの暗号化有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

- **S3BucketPublicAccessBlock**: `true`
  - **意味**: S3バケットのパブリックアクセスブロック有効化
  - **代入可能な値**: `true`, `false`
  - **デフォルト値**: `true`
  - **現在設定値**: `true`

### ses.yaml（SES設定）

#### SES基本設定
- **ProjectCode**: `ses-migration`
  - **意味**: プロジェクトを識別するコード
  - **代入可能な値**: 英数字、ハイフン、アンダースコア
  - **デフォルト値**: `ses-migration`
  - **現在設定値**: `ses-migration`

- **Environment**: `development`
  - **意味**: 環境識別子
  - **代入可能な値**: `dev`, `staging`, `prod`, `production`
  - **デフォルト値**: `production`
  - **現在設定値**: `development`

- **DomainName**: `goo.ne.jp`
  - **意味**: SESで使用するドメイン名
  - **代入可能な値**: 有効なドメイン名
  - **デフォルト値**: `goo.ne.jp`
  - **現在設定値**: `goo.ne.jp`

- **CloudWatchLogRetentionDays**: `30`
  - **意味**: CloudWatch Logsでのログ保持期間（日数）
  - **代入可能な値**: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2555
  - **デフォルト値**: `2555`
  - **現在設定値**: `30`（開発環境用に短縮）

#### 依存関係
- **S3BucketName**: `!stack_output dev/base.yaml::S3BucketName`
  - **意味**: BaseスタックからS3バケット名を取得
  - **代入可能な値**: スタック出力値（自動設定）
  - **デフォルト値**: なし（自動設定）
  - **現在設定値**: Baseスタックの出力値

- **SNSTopicArn**: `!stack_output dev/base.yaml::SNSTopicArn`
  - **意味**: BaseスタックからSNSトピックARNを取得
  - **代入可能な値**: スタック出力値（自動設定）
  - **デフォルト値**: なし（自動設定）
  - **現在設定値**: Baseスタックの出力値

### monitoring.yaml（監視・マスキング機能）

#### 監視機能設定
- **ProjectCode**: `ses-migration`
  - **意味**: プロジェクトを識別するコード
  - **代入可能な値**: 英数字、ハイフン、アンダースコア
  - **デフォルト値**: `ses-migration`
  - **現在設定値**: `ses-migration`

- **Environment**: `development`
  - **意味**: 環境識別子
  - **代入可能な値**: `dev`, `staging`, `prod`, `production`
  - **デフォルト値**: `production`
  - **現在設定値**: `development`

- **DomainName**: `goo.ne.jp`
  - **意味**: SESで使用するドメイン名
  - **代入可能な値**: 有効なドメイン名
  - **デフォルト値**: `goo.ne.jp`
  - **現在設定値**: `goo.ne.jp`

#### アラート閾値設定
- **SendSuccessRateThreshold**: `95.0`
  - **意味**: 送信成功率アラートの閾値（%）
  - **代入可能な値**: 0.1〜100.0の数値
  - **デフォルト値**: `95.0`
  - **現在設定値**: `95.0`

- **BounceRateThreshold**: `5.0`
  - **意味**: バウンス率アラートの閾値（%）
  - **代入可能な値**: 0.1〜100.0の数値
  - **デフォルト値**: `5.0`
  - **現在設定値**: `5.0`

- **ComplaintRateThreshold**: `0.1`
  - **意味**: 苦情率アラートの閾値（%）
  - **代入可能な値**: 0.01〜100.0の数値
  - **デフォルト値**: `0.1`
  - **現在設定値**: `0.1`

#### ログ・保持設定
- **RetentionDays**: `90`
  - **意味**: S3バケットでのログ保持期間（日数）
  - **代入可能な値**: 1〜2555の整数
  - **デフォルト値**: `2555`
  - **現在設定値**: `90`（開発環境用に短縮）

- **CloudWatchLogRetentionDays**: `90`
  - **意味**: CloudWatch Logsでのログ保持期間（日数）
  - **代入可能な値**: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2555
  - **デフォルト値**: `2555`
  - **現在設定値**: `90`（開発環境用に短縮）

#### Lambda設定
- **LambdaMemorySize**: `256`
  - **意味**: Lambda関数に割り当てるメモリ（MB）
  - **代入可能な値**: 128, 256, 512, 1024, 2048, 3008
  - **デフォルト値**: `256`
  - **現在設定値**: `256`

- **LambdaTimeout**: `60`
  - **意味**: Lambda関数の最大実行時間（秒）
  - **代入可能な値**: 1〜900の整数
  - **デフォルト値**: `60`
  - **現在設定値**: `60`

#### 依存関係
- **SNSTopicArn**: `!stack_output dev/base.yaml::SNSTopicArn`
  - **意味**: BaseスタックからSNSトピックARNを取得
  - **代入可能な値**: スタック出力値（自動設定）
  - **デフォルト値**: なし（自動設定）
  - **現在設定値**: Baseスタックの出力値

- **S3BucketName**: `!stack_output dev/base.yaml::S3BucketName`
  - **意味**: BaseスタックからS3バケット名を取得
  - **代入可能な値**: スタック出力値（自動設定）
  - **デフォルト値**: なし（自動設定）
  - **現在設定値**: Baseスタックの出力値

- **SESLogGroupName**: `!stack_output dev/ses.yaml::SESLogGroupName`
  - **意味**: SESスタックからロググループ名を取得
  - **代入可能な値**: スタック出力値（自動設定）
  - **デフォルト値**: なし（自動設定）
  - **現在設定値**: SESスタックの出力値

### security.yaml（セキュリティ・アクセス制御）

#### セキュリティ機能設定
- **ProjectCode**: `ses-migration`
  - **意味**: プロジェクトを識別するコード
  - **代入可能な値**: 英数字、ハイフン、アンダースコア
  - **デフォルト値**: `ses-migration`
  - **現在設定値**: `ses-migration`

- **Environment**: `development`
  - **意味**: 環境識別子
  - **代入可能な値**: `dev`, `staging`, `prod`, `production`
  - **デフォルト値**: `production`
  - **現在設定値**: `development`

- **DomainName**: `goo.ne.jp`
  - **意味**: SESで使用するドメイン名
  - **代入可能な値**: 有効なドメイン名
  - **デフォルト値**: `goo.ne.jp`
  - **現在設定値**: `goo.ne.jp`

#### ユーザー設定
- **AdminUsername**: `dev-admin`
  - **意味**: Admin権限ユーザーのユーザー名
  - **代入可能な値**: 英数字、ハイフン、アンダースコア
  - **デフォルト値**: `production-admin`
  - **現在設定値**: `dev-admin`

- **ReadonlyUsername**: `dev-readonly`
  - **意味**: ReadOnly権限ユーザーのユーザー名
  - **代入可能な値**: 英数字、ハイフン、アンダースコア
  - **デフォルト値**: `production-readonly`
  - **現在設定値**: `dev-readonly`

- **MonitoringUsername**: `dev-monitoring`
  - **意味**: Monitoring権限ユーザーのユーザー名
  - **代入可能な値**: 英数字、ハイフン、アンダースコア
  - **デフォルト値**: `production-monitoring`
  - **現在設定値**: `dev-monitoring`

#### ユーザー連絡先設定
- **AdminEmail**: `dev-admin@goo.ne.jp`
  - **意味**: Adminユーザーのメールアドレス
  - **代入可能な値**: 有効なメールアドレス
  - **デフォルト値**: `admin@goo.ne.jp`
  - **現在設定値**: `dev-admin@goo.ne.jp`

- **ReadonlyEmail**: `dev-readonly@goo.ne.jp`
  - **意味**: ReadOnlyユーザーのメールアドレス
  - **代入可能な値**: 有効なメールアドレス
  - **デフォルト値**: `readonly@goo.ne.jp`
  - **現在設定値**: `dev-readonly@goo.ne.jp`

- **MonitoringEmail**: `dev-monitoring@goo.ne.jp`
  - **意味**: Monitoringユーザーのメールアドレス
  - **代入可能な値**: 有効なメールアドレス
  - **デフォルト値**: `monitoring@goo.ne.jp`
  - **現在設定値**: `dev-monitoring@goo.ne.jp`

- **AdminPhone**: `+81901234567`
  - **意味**: Adminユーザーの電話番号
  - **代入可能な値**: E.164形式（+国コード-電話番号）
  - **デフォルト値**: `+81901234567`
  - **現在設定値**: `+81901234567`

- **ReadonlyPhone**: `+81901234568`
  - **意味**: ReadOnlyユーザーの電話番号
  - **代入可能な値**: E.164形式（+国コード-電話番号）
  - **デフォルト値**: `+81901234568`
  - **現在設定値**: `+81901234568`

- **MonitoringPhone**: `+81901234569`
  - **意味**: Monitoringユーザーの電話番号
  - **代入可能な値**: E.164形式（+国コード-電話番号）
  - **デフォルト値**: `+81901234569`
  - **現在設定値**: `+81901234569`

#### 依存関係
- **DataMaskingFunctionArn**: `!stack_output dev/monitoring.yaml::DataMaskingFunctionArn`
  - **意味**: Monitoringスタックからデータマスキング関数ARNを取得
  - **代入可能な値**: スタック出力値（自動設定）
  - **デフォルト値**: なし（自動設定）
  - **現在設定値**: Monitoringスタックの出力値

- **AdminQueryDefinitionName**: `!stack_output dev/monitoring.yaml::AdminQueryDefinitionName`
  - **意味**: MonitoringスタックからAdmin用クエリ定義名を取得
  - **代入可能な値**: スタック出力値（自動設定）
  - **デフォルト値**: なし（自動設定）
  - **現在設定値**: Monitoringスタックの出力値

- **MaskedQueryDefinitionName**: `!stack_output dev/monitoring.yaml::MaskedQueryDefinitionName`
  - **意味**: Monitoringスタックからマスク用クエリ定義名を取得
  - **代入可能な値**: スタック出力値（自動設定）
  - **デフォルト値**: なし（自動設定）
  - **現在設定値**: Monitoringスタックの出力値

## トラブルシューティング

### よくある問題
1. **スタック作成エラー**
   - パラメータ値の確認
   - AWS権限の確認
   - 依存関係の確認

2. **リソース作成エラー**
   - リソース名の重複確認
   - リージョン設定の確認

### ロールバック手順
```bash
# 問題のあるスタックの削除
sceptre delete-stack dev [stack-name]

# 再デプロイ
sceptre create-stack dev [stack-name]
```

## クリーンアップ

### 開発環境の削除
```bash
# 全スタックの削除（依存関係を考慮して逆順）
sceptre delete-stack dev security
sceptre delete-stack dev monitoring
sceptre delete-stack dev ses
sceptre delete-stack dev base
```

### 注意事項
- 削除前に重要なデータのバックアップを確認
- 依存関係のあるリソースは自動的に削除される
- 手動で作成したリソースは個別に削除が必要
