# Production環境 デプロイ手順書

## 📊 現在のデプロイ状況（2025年9月18日 最新更新）

### ✅ 完了済み統合機能
- **✅ base.yaml** - 統一SNS通知システム基盤デプロイ完了
- **✅ phase-1-infrastructure-foundation.yaml** - BYODKIM基盤デプロイ完了  
- **✅ phase-2-dkim-system.yaml** - DKIM管理システム（V2統合済み）デプロイ完了
- **✅ phase-3-ses-byodkim.yaml** - SES設定 + 機能フラグシステム + BYODKIM安全制御完了
- **✅ phase-8-monitoring.yaml** - 統合監視システム + EventBridge日次実行 + 証明書自動監視完了
- **✅ DKIM Manager重複解消** - V2統合によりBYODKIM安全制御が全システム適用
- **✅ 機能フラグシステム統合** - SESコア機能・地域機能・安全制御の統合管理
- **✅ 通知システム統合** - 統一SNSトピックによる通知システム統合

### � 完全運用開始フェーズ
- **✅ DNS調整連携** - 手動制御モードでDNS調整期間（16日前アラート）対応完了
- **✅ 証明書ライフサイクル管理** - テスト用証明書検証完了、本番運用準備完了
- **✅ 統合監視運用** - Phase 8による証明書期限・SESアラート・DNS調整の統合監視開始

### �️ BYODKIM安全制御対応済み
- **手動制御モード**: `BYODKIMRotationMode: "MANUAL"` でDNS調整期間確保
- **自動適用無効**: `BYODKIMAutoApplyToSES: "false"` で安全なローテーション
- **DNS調整通知**: `DNSTeamNotificationEmail` による自動通知システム

## 重要な更新事項（2025年9月18日）

### 🚀 SES BYODKIMシステム統合完了
**3つの主要統合により運用効率と安全性が大幅向上**：

#### 1. 機能フラグシステム統合 ✅
- **SESコア機能制御**: バウンス処理、DKIM、ドメイン検証、BYODKIM自動化
- **地域・言語機能**: 東京リージョン最適化、日本語対応、法規制対応
- **セキュリティ・監視**: IP制限、CloudWatch監視、アラート制御

#### 2. 通知システム統合 ✅  
- **統一SNSトピック**: 全通知がbase.yamlのSNSトピック経由で統合
- **統一メッセージフォーマット**: 日本語 + 緊急度別分類（CRITICAL/WARNING/INFO）
- **ルーティング最適化**: 運用チーム・DNSチーム・システム管理者への適切な通知配信

#### 3. DKIM Manager重複解消 ✅
- **V2統合完了**: 安全制御付きDKIM ManagerがV1を置き換え
- **透明な移行**: 既存参照はそのまま、全システムがBYODKIM安全制御を取得
- **パラメータ統一**: RenewalAlertDaysが全フェーズで統一参照

### ✅ 運用最適化の効果
1. **DNS調整プロセス**: 16日前アラート → 2週間のDNS調整期間確保
2. **安全なローテーション**: 手動制御でDNS登録完了後のSES適用
3. **統合監視**: 証明書期限・SESアラート・DNS調整の一元管理
4. **日本語運用**: 統一メッセージフォーマットによる即座理解可能な通知

---

## 概要
本番環境用のAWS SES BYODKIM インフラストラクチャをデプロイするための手順書です。本環境は**goo.ne.jpドメインのEmailIdentityの主要管理者**として、統合された安全制御システムを含む完全なSESサービスを提供します。

## 前提条件
- AWS CLI設定済み（Tokyo Region: ap-northeast-1）
- Sceptre 2.x以降
- 適切なIAM権限（SES、Lambda、CloudFormation、S3、KMS、SNS）
- DNS管理権限（goo.ne.jpドメイン）

## 🚀 デプロイ手順

### Phase 1: 基盤インフラストラクチャ

#### Step 1-1: Base Infrastructure（統一SNS基盤）
```bash
cd /c/Temp/AWS_SES_BYODKIM/sceptre
uv run sceptre launch prod/base.yaml --yes
```

**デプロイ内容**:
- S3バケット（ログ、バックアップ、テンプレート）
- KMS暗号化キー
- **統一SNSトピック** (`aws-ses-migration-prod-notifications`)
- IAMロール・ポリシー基盤

#### Step 1-2: BYODKIM Foundation
```bash
uv run sceptre launch prod/phase-1-infrastructure-foundation.yaml --yes
```

**デプロイ内容**:
- DKIM専用S3バケット
- DKIM管理用IAMロール
- Secrets Manager設定
- ドメイン設定基盤

### Phase 2: DKIM管理システム（V2統合版）

#### Step 2: DKIM Manager Deployment
```bash
uv run sceptre launch prod/phase-2-dkim-system.yaml --yes
```

**デプロイ内容**:
- **AWS Official OpenSSL実装** DKIM Manager Lambda
- **BYODKIM安全制御機能**:
  - `BYODKIMAutoApplyToSES: "false"` - 自動適用無効
  - `BYODKIMRotationMode: "MANUAL"` - 手動制御モード
  - DNS調整通知システム
- RenewalAlertDays出力（他フェーズ参照用）

### Phase 3: SES設定 + 機能フラグシステム

#### Step 3: SES Configuration with Feature Flags
```bash
uv run sceptre launch prod/phase-3-ses-byodkim.yaml --yes
```

**デプロイ内容**:
- SES EmailIdentity (goo.ne.jp)
- **機能フラグシステム統合**:
  - SESコア機能制御 (DKIM, バウンス処理, ドメイン検証)
  - 地域機能 (東京リージョン最適化, 日本語対応)
  - セキュリティ機能 (IP制限, CloudWatch監視)
- **BYODKIM安全設定**:
  - DNS調整期間対応
  - 手動ローテーション制御

### Phase 4-7: DNS調整・連携フェーズ

#### Step 4: DNS Preparation
```bash
uv run sceptre launch prod/phase-4-dns-preparation.yaml --yes
```

#### Step 5: DNS Team Collaboration
```bash
uv run sceptre launch prod/phase-5-dns-team-collaboration.yaml --yes
```

#### Step 6-7: DNS調整実行
```bash
# DNS調整フェーズ（手動実行）
uv run sceptre launch prod/phase-7-dns-validation-dkim-activation.yaml --yes
```

### Phase 8: 統合監視システム

#### Step 8: Unified Monitoring System
```bash
uv run sceptre launch prod/phase-8-monitoring.yaml --yes
```

**デプロイ内容**:
- **統合証明書監視**: 期限アラート + 自動DNS通知
- **統一通知システム**: base.yamlのSNSトピック統合
- **RenewalAlertDays統一**: Phase-2から自動継承
- CloudWatch Dashboard統合監視

## 🔧 運用管理

### DKIM証明書管理（V2安全制御版）

#### 証明書生成（AWS Official OpenSSL）
```bash
# DKIM Manager V2による証明書生成
aws lambda invoke \
  --function-name aws-ses-migration-prod-dkim-manager \
  --payload '{
    "action": "create_dkim_certificate",
    "domain": "goo.ne.jp", 
    "selector": "gooid-21-prod",
    "environment": "prod"
  }' \
  --region ap-northeast-1 \
  response.json
```

#### 安全なローテーション実行
```bash
# 1. 新証明書生成（DNS登録前）
aws lambda invoke \
  --function-name aws-ses-migration-prod-dkim-manager \
  --payload '{
    "action": "rotate_dkim_keys",
    "domain": "goo.ne.jp",
    "mode": "GENERATE_ONLY",
    "environment": "prod"
  }' \
  response-generate.json

# 2. DNS調整期間（通知は自動送信）
echo "DNS調整期間: 2週間程度"
echo "DNSチームへの通知: 自動送信済み (goo-idpay-sys@ml.nttdocomo.com)"

# 3. DNS登録完了後、SESへ適用
aws lambda invoke \
  --function-name aws-ses-migration-prod-dkim-manager \
  --payload '{
    "action": "rotate_dkim_keys", 
    "domain": "goo.ne.jp",
    "mode": "APPLY_TO_SES",
    "dns_confirmation": true,
    "environment": "prod"
  }' \
  response-apply.json
```

### 機能フラグ制御

#### SES機能の個別制御
```yaml
# 緊急時の機能無効化例
EnableBounceComplaintHandling: "false"  # バウンス処理停止
EnableSESMonitoring: "false"           # 監視停止
EnableBYODKIMAutomation: "false"       # BYODKIM自動化停止（推奨）
```

#### 地域機能の制御
```yaml
# 大阪リージョン切り替え例
EnableTokyoRegionFeatures: "false"     # 東京機能無効
EnableOsakaRegionFeatures: "true"      # 大阪機能有効（要実装）
```

### 統合監視運用

#### Phase 8統合監視
```bash
# 証明書期限監視の手動実行
aws lambda invoke \
  --function-name aws-ses-migration-prod-certificate-monitor \
  --payload '{
    "environment": "prod",
    "domain": "goo.ne.jp"
  }' \
  monitoring-response.json

# CloudWatch Dashboard確認
echo "監視ダッシュボード:"
echo "https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#dashboards:name=aws-ses-migration-prod-monitoring"
```

#### 通知システム確認
```bash
# 統一SNSトピック状態確認
aws sns get-topic-attributes \
  --topic-arn arn:aws:sns:ap-northeast-1:007773581311:aws-ses-migration-prod-notifications \
  --region ap-northeast-1

# サブスクリプション確認
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:ap-northeast-1:007773581311:aws-ses-migration-prod-notifications \
  --region ap-northeast-1
```

### パラメータ統一管理

#### テスト環境設定
```yaml
# phase-2-dkim-system.yaml（マスター設定）
CertificateValidityDays: 2    # テスト用: 2日有効期限
RenewalAlertDays: 2          # テスト用: 2日前アラート

# 他フェーズ自動継承
Phase-3, Phase-8: RenewalAlertDays: 2  # 自動同期
```

#### 本番環境切り替え
```yaml  
# phase-2-dkim-system.yaml（本番用変更）
CertificateValidityDays: 456  # 本番用: 15ヶ月有効期限
RenewalAlertDays: 16         # 本番用: 16日前アラート（DNS調整期間）

# 全フェーズ自動更新
Phase-3, Phase-8: RenewalAlertDays: 16  # 自動同期
```

## 🔍 監視・運用

### 日常監視

#### 統一ダッシュボード確認
```bash
# CloudWatch統合ダッシュボード
aws cloudwatch get-dashboard \
  --dashboard-name aws-ses-migration-prod-monitoring \
  --region ap-northeast-1
```

#### SESメトリクス監視
```bash
# バウンス率・苦情率確認
aws sesv2 get-account-sending-enabled --region ap-northeast-1
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1

# アラーム状態確認
aws cloudwatch describe-alarms \
  --alarm-names "ses-migration-prod-bounce-rate-alarm" \
  "ses-migration-prod-complaint-rate-alarm" \
  --region ap-northeast-1
```

#### DKIM署名状態確認
```bash
# BYODKIM設定確認
aws sesv2 get-email-identity-dkim-attributes \
  --email-identity goo.ne.jp \
  --region ap-northeast-1

# DNS設定確認
dig TXT gooid-21-prod._domainkey.goo.ne.jp
```

### 緊急時対応

#### 機能フラグによる緊急停止
```bash
# SESアラート緊急停止
uv run sceptre update prod/phase-3-ses-byodkim.yaml --yes
# ↑ EnableSESMonitoring: "false" に設定後デプロイ

# BYODKIM緊急停止  
# ↑ EnableBYODKIMAutomation: "false" （すでに設定済み）
```

#### 通知システム緊急確認
```bash
# 緊急通知の手動送信
aws sns publish \
  --topic-arn arn:aws:sns:ap-northeast-1:007773581311:aws-ses-migration-prod-notifications \
  --subject "【CRITICAL】SES緊急事態対応" \
  --message "緊急対応が必要です。詳細確認してください。" \
  --region ap-northeast-1
```

### 定期メンテナンス

#### 月次チェック項目
```bash
# 証明書期限確認（Phase 8統合監視）
aws lambda invoke \
  --function-name aws-ses-migration-prod-certificate-monitor \
  --payload '{"environment": "prod"}' \
  monthly-check.json

# 機能フラグ設定確認
uv run sceptre status prod/phase-3-ses-byodkim.yaml

# 通知システム動作確認
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:ap-northeast-1:007773581311:aws-ses-migration-prod-notifications
```

#### DNS設定定期確認
```bash
# DKIM DNS設定確認（日次推奨）
dig TXT gooid-21-prod._domainkey.goo.ne.jp

# DNS調整状況確認
aws lambda invoke \
  --function-name aws-ses-migration-prod-dns-notifier \
  --payload '{"action": "check_dns_status"}' \
  dns-status.json
```

## 🛡️ セキュリティ・コンプライアンス

### アクセス制御
- **最小権限の原則**: 各Lambdaに必要最小限のIAM権限
- **IP制限**: VDI/大手町ネットワークからのアクセスのみ許可
- **暗号化**: S3、Secrets Manager、CloudWatchログの暗号化

### 監査・ログ管理
- **CloudWatch Logs**: 731日間保存設定
- **統一通知ログ**: SNSトピック経由の全通知履歴
- **BYODKIM操作ログ**: 証明書生成・ローテーションの完全ログ

### 災害復旧
- **設定バックアップ**: Git リポジトリによるバージョン管理
- **KMS鍵バックアップ**: AWS管理による自動バックアップ
- **クロスリージョン対応**: 必要に応じて大阪リージョン対応

### コンプライアンス対応
- **個人情報保護法**: 機能フラグによるデータマスキング対応
- **監査要件**: 731日間のログ保持と統合監視
- **日本語対応**: 統一通知フォーマットによる日本語運用

## 📚 参考資料

### 主要設定ファイル
- `phase-2-dkim-system.yaml` - DKIM Manager V2（安全制御付き）
- `phase-3-ses-byodkim.yaml` - SES設定 + 機能フラグシステム  
- `phase-8-monitoring.yaml` - 統合監視システム
- `BYODKIM安全ローテーション手順書.md` - DNS調整手順詳細

### 統合システム資料
- `機能フラグシステム統合完了確認.md` - 機能フラグ統合詳細
- `Step3_通知システム統合完了レポート.md` - 通知統合詳細  
- `DKIM_Manager重複解消完了レポート.md` - V2統合詳細
- `RenewalAlertDays参照統一修正レポート.md` - パラメータ統一詳細

このドキュメントは統合されたSES BYODKIMシステムの重要な運用手順を記載しています。変更時は必ず承認プロセスを経て実行してください。
# - phase-3-ses-byodkim.yaml                  (SES EmailIdentity)
# - phase-4-dns-preparation.yaml              (DNS準備)
# - phase-5-dns-team-collaboration.yaml       (DNS連携)
# - phase-7-dns-validation-dkim-activation.yaml (DNS検証・DKIM有効化)
# - phase-8-monitoring-system.yaml            (監視システム)
# - enhanced-kinesis.yaml                     (データ処理パイプライン)
# - monitoring.yaml                           (監視・マスキング)
# - security.yaml                             (セキュリティ・アクセス制御)
# - config.yaml                               (共通設定)
```

### 2. 本番環境デプロイの事前確認
```bash
# AWS認証情報の確認
aws sts get-caller-identity

# 本番環境リージョンの確認
aws configure get region
# 期待値: ap-northeast-1

# 既存リソースの確認（重複回避）
aws sesv2 list-email-identities --region ap-northeast-1
```

### 3. スタックの順次デプロイ

#### 3.1 基本インフラのデプロイ
```bash
uv run sceptre launch prod/base.yaml -y
```
**作成されるリソース:**
- S3バケット（Raw/Masked/Error Logs用、本番向け高可用性設定）
- KMS暗号化キー（本番レベルセキュリティ）
- SNS通知トピック（admin@goo.ne.jp）
- アクセスログ設定（監査要件対応）

#### 3.2 Phase 1: インフラ基盤構築
```bash
uv run sceptre launch prod/phase-1-infrastructure-foundation.yaml -y
```
**作成されるリソース:**
- DKIM Manager Lambda実行ロール
- DKIM設定用Secrets Manager
- DKIM証明書用S3バケット
- DKIM暗号化用KMSキー
- EventBridge Rules（自動化トリガー）

#### 3.3 Phase 2: DKIM管理システム V2（AWS公式実装 + 自動化）
```bash
# Phase 2デプロイ（V2統合版）
uv run sceptre launch prod/phase-2-dkim-system.yaml --yes

# ✅ デプロイ状況確認
uv run sceptre status prod/phase-2-dkim-system.yaml
```
**✅ 作成完了リソース（V2）:**
- **DKIM Manager Lambda関数 V2（AWS公式OpenSSL実装）**
- **SES自動更新機能（update_ses_byodkim_automated）**
- **証明書有効期間456日（15ヶ月）+ 60日前アラート**
- DNS前提チェック機能
- 包括的エラーハンドリングとロールバック

**🔧 V2の主要機能:**
- AWS公式OpenSSLによる証明書生成
- DNS完了確認後の自動SES更新
- nslookupを使用したDNS TXT検証
- 自動ロールバック機能
- 詳細な実行ログとエラー分類

#### 3.4 Phase 3: SES設定 + EasyDKIM無効化（重要）
```bash
# SES EmailIdentity作成
uv run sceptre launch prod/phase-3-ses-byodkim.yaml -y
```
**作成されるリソース:**
- **goo.ne.jp EmailIdentity（Primary）**
- Production用ConfigurationSet
- EventBridge Rules（BYODKIM用）
- CloudWatchログ設定

#### 3.4.1 ⚠️ 重要: EasyDKIM無効化の実行タイミング

**Phase 3完了直後にEasyDKIM無効化が必要:**

```bash
# EasyDKIM無効化（Phase 3完了直後に実行）
# SSL検証回避のためuvを使用
uv run aws sesv2 put-email-identity-dkim-attributes --email-identity goo.ne.jp --no-signing-enabled

# または既存スクリプトを使用
./scripts/disable-easydkim.sh goo.ne.jp ap-northeast-1
```

**⚠️ 重要**: Phase 3でSES EmailIdentityが作成されると、自動的にEasyDKIM（AWS管理DKIM）が有効化されます。BYODKIMを使用するには、必ずEasyDKIMを先に無効化する必要があります。

**EasyDKIM無効化後の期待される結果:**
```json
{
  "SigningEnabled": false,
  "SigningAttributesOrigin": "AWS_SES"
}
```

**📝 注意**: この時点ではまだ `AWS_SES` のままです。BYODKIMへの切り替えは証明書生成後に行います。

**⚠️ 重要**: Phase 3ではEasyDKIM無効化のみを実行してください。BYODKIM設定は証明書生成完了後に別途実行します（Phase 7完了後を参照）。

#### 3.5 Phase 4: DNS準備
```bash
uv run sceptre launch prod/phase-4-dns-preparation.yaml -y
```
**作成されるリソース:**
- DKIM証明書生成Lambda
- DNS設定情報生成
- S3への設定情報保存

#### 3.6 Phase 5: DNSチーム連携
```bash
uv run sceptre launch prod/phase-5-dns-team-collaboration.yaml -y
```
**作成されるリソース:**
- DNS設定要求の自動生成
- DNSチーム向け通知機能
- 設定状況の追跡

#### 3.6.1 DKIM証明書生成ステップ（Phase 5完了後）

**Step 1: DKIM証明書の生成（AWS公式OpenSSL実装）**
```bash
# DKIM証明書生成用ペイロード作成
cat > create-dkim-certificate-payload.json << EOF
{
  "action": "create_dkim_certificate",
  "domain": "goo.ne.jp",
  "selector": "selector1",
  "dkim_separator": "gooid-21-pro"
}
EOF

# V2 Lambda関数でDKIM証明書生成実行
aws lambda invoke \
  --function-name aws-ses-migration-prod-dkim-manager-v2 \
  --payload fileb://create-dkim-certificate-payload.json \
  response-create-dkim-certificate.json

# 結果確認（DNS TXT設定情報が含まれます）
cat response-create-dkim-certificate.json | jq .
```

**Step 2: DNS チームへの通知送信（修正版 - 2025/09/18）**
```bash
# 【重要】DKIM Manager V2にはphase_managerアクションが実装されていません
# 正しくはDNSNotifier関数を使用します（修正済み実装）

# DKIM証明書生成によりDNS情報が自動的にS3に保存されるため
# DNSNotifier関数を空ペイロードで実行するとS3からDNS情報を読み込みます
aws lambda invoke \
  --function-name aws-ses-migration-prod-dns-notifier \
  --payload '{}' \
  response-dns-notifier.json

# 📧 注意事項:
# - SNSサブスクリプションが削除されている場合は再作成が必要
# - 確認メールでサブスクリプションを有効化する必要があります

# サブスクリプション再作成（必要に応じて）
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-northeast-1:007773581311:aws-ses-migration-prod-dns-team-notifications \
  --protocol email \
  --notification-endpoint goo-idpay-sys@ml.nttdocomo.com

# 通知送信結果確認
cat response-dns-notifier.json
```

**Step 3: 実装確認とトラブルシューティング（2025/09/18追加）**
```bash
# ✅ DKIM Manager V2でサポートされているアクション:
# - create_dkim_certificate (✅ 使用済み・DNS情報S3保存機能付き) 
# - create_dkim_certificate_prepare_only
# - test_openssl
# - update_ses_byodkim_automated

# ❌ 非対応アクション（README記載ミスを修正）:
# - phase_manager (実装されていません)

# ✅ DNS通知の正しい実装（修正済み）:
# - aws-ses-migration-prod-dns-notifier関数を使用
# - S3からDNS情報を自動読み込み（dns_records/{domain}/パス）
# - 修正により正しいDNS TXTレコード値を含む通知が送信されます

# DNS情報の保存確認
aws s3 ls s3://aws-ses-migration-prod-dkim-certificates/dns_records/goo.ne.jp/
```

#### 3.7 Phase 6: DNS設定完了待機フェーズ

**⚠️ 外部作業待ちフェーズです**

**📋 前提条件:** 
- Phase 1-5が完了していること
- **Step 1-2: DKIM証明書生成、DNS通知が完了していること**

**現在の状況: DNS設定完了待ち**
```bash
# ⚠️ 外部作業: DNSチームによる手動TXTレコード設定
# response-create-dkim-certificate.json から取得したDNS情報を使用:

# DNS TXT レコード設定例:
# レコード名: selector1._domainkey.goo.ne.jp
# レコードタイプ: TXT  
# レコード値: v=DKIM1; k=rsa; p=[公開キー文字列]

# DNS設定完了確認（DNSチームによる設定後に実行）
nslookup -type=TXT selector1._domainkey.goo.ne.jp

# または dig コマンド
dig TXT selector1._domainkey.goo.ne.jp

# ✅ DNS TXT レコードが確認できたら Phase 7 自動実行へ進む
```

#### 3.8 Phase 7: 自動化されたSES BYODKIM更新（🚀 新機能）

**🎯 DNS完了確認後、1コマンドでSES BYODKIM設定を自動完了**

> **📋 前提条件**: Step 1でのDKIM証明書生成時に、DKIM Manager V2が自動的にDNS情報をS3（`dns_records/{domain}/`）に保存し、DNSNotifier関数がDNS担当者に通知メールを送信済みであること。

**Step 1: 自動化された SES BYODKIM 更新実行**
```bash
# 自動化されたSES更新用ペイロード作成
cat > update-ses-byodkim-automated-payload.json << EOF
{
  "action": "update_ses_byodkim_automated",
  "domain": "goo.ne.jp", 
  "selector": "selector1"
}
EOF

# 🚀 DNS完了後の自動SES更新実行（従来の7ステップが1ステップに）
aws lambda invoke \
  --function-name aws-ses-migration-prod-dkim-manager-v2 \
  --payload fileb://update-ses-byodkim-automated-payload.json \
  response-update-ses-automated.json

# 実行結果確認
cat response-update-ses-automated.json | jq .

# ✅ 成功例:
# {
#   "statusCode": 200,
#   "message": "SES BYODKIM update completed successfully",
#   "domain": "goo.ne.jp",
#   "selector": "selector1",
#   "final_dkim_status": "SUCCESS",
#   "signing_origin": "EXTERNAL",
#   "automation_type": "lambda_extension"
# }
```

**Step 2: 自動化プロセスの詳細確認**
```bash
# SES DKIM設定の最終確認
aws sesv2 get-email-identity-dkim-attributes \
  --email-identity goo.ne.jp \
  --region ap-northeast-1

# 期待される結果:
# - Status: "SUCCESS" 
# - SigningAttributesOrigin: "EXTERNAL"
# - DkimEnabled: true
```

**🔧 自動化プロセスの内容:**
1. **DNS TXT完了確認**: nslookup で DKIM TXT レコード検証
2. **証明書・DNS情報取得**: S3から秘密鍵と保存されたDNS情報を自動取得
   - 証明書: `s3://bucket/dkim-certificates/{domain}/selector1/private_key.pem`
   - DNS情報: `s3://bucket/dns_records/{domain}/`
3. **SES更新**: put_email_identity_dkim_signing_attributes API 実行
4. **DKIM有効化**: put_email_identity_dkim_attributes API 実行
5. **設定検証**: 最終設定の確認とログ記録
6. **エラー処理**: 失敗時の自動ロールバック

**⚠️ エラー対応:**
```bash
# DNS_TXT_NOT_READY エラーの場合
# → DNS伝播を待ってから再実行

# CERTIFICATE_NOT_FOUND エラーの場合  
# → Step 1 DKIM証明書生成を再実行（DNS情報もS3に保存される）

# SES_UPDATE_FAILED エラーの場合
# → IAM権限確認後、手動フォールバックを検討

# 📧 "SubscriptionArn": "Deleted" の場合は unsubscribe により削除済み
# この場合は Step 3-1 でサブスクリプションを再作成する

# 🔧 DNS通知システムについて:
# - DKIM Manager V2がDNS情報をS3の dns_records/{domain}/ に保存
# - DNSNotifier関数（aws-ses-migration-prod-dns-notifier）が通知メール送信
# - phase_manager アクションは実装されていません（DNSNotifier関数を使用）
```

#### 3.8.1 Phase 7 CloudFormation スタックのデプロイ

**DNS検証とモニタリング用のインフラをデプロイ:**
```bash
# Phase 7インフラのデプロイ
uv run sceptre launch prod/phase-7-dns-validation-dkim-activation.yaml --yes
```
**作成されるリソース:**
- DNS検証Lambda関数
- DKIM検証処理機能
- 検証結果通知システム

#### 3.8.2 🚀 BYODKIM設定の統合適用（証明書生成・DNS通知後）

**🎯 前提条件**: 証明書生成完了 + DNSチームへの通知送信後

**統合スクリプトによる簡単BYODKIM設定:**
```bash
# 🚀 自動セレクター検出（推奨）- 最新のセレクターを自動使用
./scripts/apply-byodkim-to-ses.sh goo.ne.jp ap-northeast-1

# セレクター手動指定の場合
./scripts/apply-byodkim-to-ses.sh goo.ne.jp ap-northeast-1 aws-ses-migration-prod-dkim-certificates gooid-21-pro-20250918-1
```

**🤖 スクリプトの自動機能:**
- **最新セレクター自動検出**: S3から最新の証明書セレクターを自動識別
- **利用可能セレクター一覧表示**: 手動確認用の全セレクター表示
- **証明書更新対応**: 新しい証明書が生成されても自動で最新を使用

**スクリプトが自動実行する処理:**
1. ✅ **セレクター自動検出**: S3から最新のセレクターを自動取得
2. ✅ **EasyDKIM無効化**: AWS_SES DKIMを自動無効化  
3. ✅ **S3証明書取得**: 検出されたセレクターの秘密鍵を自動取得
4. ✅ **base64変換**: PEMヘッダー除去とエンコーディング
5. ✅ **SES BYODKIM設定**: `put-email-identity-dkim-signing-attributes`
6. ✅ **DKIM署名有効化**: `put-email-identity-dkim-attributes --signing-enabled`
7. ✅ **設定検証**: SigningAttributesOrigin=EXTERNALの確認

**期待される結果:**
```json
{
  "SigningEnabled": true,
  "Status": "PENDING", 
  "Tokens": ["gooid-21-pro-20250918-1"],
  "SigningAttributesOrigin": "EXTERNAL"
}
```

**🔧 手動手順（スクリプト利用不可の場合）:**
```bash
# 前提条件: 証明書生成とDNS通知が完了していること

# Step 1: EasyDKIM無効化（未実行の場合）
uv run aws sesv2 put-email-identity-dkim-attributes \
  --email-identity goo.ne.jp \
  --no-signing-enabled

# Step 2: BYODKIM設定（DKIM Manager Lambda使用）
echo '{"action":"update_ses_byodkim_automated","domain":"goo.ne.jp","selector":"gooid-21-pro-20250918-1"}' | base64 -w 0 > payload_byodkim_b64.txt
uv run aws lambda invoke --function-name aws-ses-migration-prod-dkim-manager-v2 --payload file://payload_byodkim_b64.txt response-byodkim.json

# Step 3: 結果確認
uv run aws sesv2 get-email-identity --email-identity goo.ne.jp --query "DkimAttributes"
```

**📝 手動実行時の注意**: 
- 証明書が存在しない場合、Lambda関数がエラーを返します
- セレクター名は実際の生成されたものを使用してください
- 統合スクリプトの使用を強く推奨します

**⚠️ 重要な注意点:**
- DNS登録前でも SES へのBYODKIM設定は可能
- Status は DNS登録完了まで "PENDING" のまま
- DNS登録後、自動的に "SUCCESS" に変更

#### 3.9 Phase 8: 統合監視システム
```bash
# Phase 8統合監視システムのデプロイ
uv run sceptre launch prod/phase-8-monitoring.yaml --yes
```
**作成されるリソース:**
- **証明書監視Lambda関数**: `aws-ses-migration-prod-certificate-monitor`
- **統合監視ダッシュボード**: CloudWatch Dashboard
- **SNS通知統合**: DKIM Manager・DNS Notifier連携
- **EventBridge日次実行**: 毎日9:00 AM JST自動監視
- **テスト設定**: 2日証明書、1日前アラート

**監視システムの動作確認:**
```bash
# 手動で証明書監視を実行
uv run aws lambda invoke --function-name aws-ses-migration-prod-certificate-monitor --payload '{}' response-monitoring-test.json

# 実行結果確認
cat response-monitoring-test.json
```

**期待される監視結果:**
- 証明書期限の自動チェック
- 期限切れ前のアラート発信
- 自動証明書更新トリガー
- DNS通知の自動送信

#### 3.10 Phase 8完了後の運用開始

**🎯 全システム統合完了後の運用フロー:**

**日次自動処理 (毎日9:00 AM JST):**
```bash
# EventBridge による自動実行（手動操作不要）
# aws-ses-migration-prod-certificate-monitor 関数が自動実行
# ↓
# 証明書期限チェック → 必要に応じて自動更新 → DNS通知 → SES適用
```

**アラート発生時の対応:**
```bash
# 1. アラート受信（SNS/メール）
# 2. 自動証明書生成の確認
uv run aws s3 ls s3://aws-ses-migration-prod-dkim-certificates/dkim-keys/goo.ne.jp/ --recursive

# 3. DNS通知送信の確認
uv run aws s3 ls s3://aws-ses-migration-prod-dkim-certificates/dns_records/goo.ne.jp/ --recursive

# 4. SES BYODKIM適用（DNS登録完了後）
./scripts/apply-byodkim-to-ses.sh goo.ne.jp ap-northeast-1
```

**運用監視ポイント:**
- CloudWatch Dashboard での証明書状況確認
- SNS通知の受信確認
- DNS登録の進捗追跡
- SES BYODKIM設定の正常性確認

### 4. テスト手順

#### 4.1 自動化機能のテスト
```bash
# テストスクリプトを使用（推奨）
uv run python test_ses_automated_update.py

# 1. Full SES automated update test を選択
# 2. ドメインとセレクタの設定確認
# 3. テスト結果の確認

# 期待される成功結果:
# ✅ SUCCESS: SES BYODKIM automated update completed successfully
# Domain: goo.ne.jp
# Selector: selector1  
# DKIM Status: SUCCESS
# Signing Origin: EXTERNAL
```

#### 4.2 DNS検証のテスト
```bash
# DNS検証のみのテスト
uv run python test_ses_automated_update.py

# 2. DNS validation test only を選択
# DNS TXT レコードの存在確認を実行

# 期待される結果:
# ✅ DNS validation would succeed  (DNS設定完了済みの場合)
# ❌ DNS validation would fail    (DNS設定未完了の場合)
```

#### 4.3 証明書有効期間の確認
```bash
# 生成された証明書の有効期間確認
aws s3 cp s3://aws-ses-migration-prod-dkim-certificates/dkim-certificates/goo.ne.jp/selector1/certificate_info.json ./

cat certificate_info.json | jq .

# 期待される値:
# - validity_days: 456 (15ヶ月)
# - renewal_alert_days: 60 (60日前アラート)
```

#### 4.4 証明書監視のテスト
```bash
# 手動で証明書監視Lambda関数を実行
aws lambda invoke \
  --function-name aws-ses-migration-prod-certificate-monitor \
  --payload '{"source":"manual","domain":"goo.ne.jp","environment":"prod"}' \
  --region ap-northeast-1 \
  --no-verify-ssl \
  test-monitor-response.json

# 実行結果確認
cat test-monitor-response.json | jq .

# 期待される結果:
# {
#   "statusCode": 200,
#   "message": "Certificate monitoring completed",
#   "timestamp": "2025-09-17T07:50:00.000Z"
# }

# EventBridge スケジュール確認
aws events describe-rule \
  --name "aws-ses-migration-prod-daily-certificate-monitor" \
  --region ap-northeast-1 \
  --no-verify-ssl

# 期待される結果:
# "ScheduleExpression": "cron(0 9 * * ? *)"  # 毎日 9:00AM JST
```

### 5. トラブルシューティング

#### 5.1 自動化機能のエラー対応

**DNS_TXT_NOT_READY エラー**
```bash
# 症状: DNS TXT record for selector1._domainkey.goo.ne.jp is not yet available
# 原因: DNS TXT レコードが未設定または伝播未完了
# 対処:
# 1. DNS設定状況をDNS管理者に確認
# 2. nslookup でTXTレコード確認
nslookup -type=TXT selector1._domainkey.goo.ne.jp

# 3. DNS伝播待機（通常24-48時間）
# 4. 伝播完了後に自動化コマンド再実行
```

**CERTIFICATE_NOT_FOUND エラー**
```bash  
# 症状: Certificate not found at S3 path
# 原因: DKIM証明書がS3に存在しない
# 対処:
# 1. S3バケットの確認
aws s3 ls s3://aws-ses-migration-prod-dkim-certificates/dkim-certificates/goo.ne.jp/

# 2. 証明書再生成
aws lambda invoke \
  --function-name aws-ses-migration-prod-dkim-manager-v2 \
  --payload '{"action":"create_dkim_certificate","domain":"goo.ne.jp","selector":"selector1"}' \
  response-cert-regen.json
```

**SES_UPDATE_FAILED エラー**
```bash
# 症状: SES BYODKIM update failed
# 原因: SES API権限不足またはSES設定競合
# 対処:
# 1. IAM権限確認
aws iam get-role --role-name aws-ses-migration-prod-dkim-manager-role

# 2. SES現在設定確認
aws sesv2 get-email-identity-dkim-attributes --email-identity goo.ne.jp

# 3. SESリセット後に再実行
aws sesv2 put-email-identity-dkim-attributes \
  --email-identity goo.ne.jp \
  --dkim-enabled false

# 4. 自動化コマンド再実行
```

#### 5.2 手動フォールバック手順

**自動化が完全に失敗した場合の手動実行:**
```bash
# 1. 現在のDKIM設定確認
aws sesv2 get-email-identity-dkim-attributes --email-identity goo.ne.jp

# 2. S3から証明書取得
aws s3 cp s3://aws-ses-migration-prod-dkim-certificates/dkim-certificates/goo.ne.jp/selector1/private_key.pem ./

# 3. 手動でBYODKIM設定
aws sesv2 put-email-identity-dkim-signing-attributes \
  --email-identity goo.ne.jp \
  --signing-attributes-origin EXTERNAL \
  --signing-attributes DomainSigningSelector=selector1,DomainSigningPrivateKey=file://private_key.pem

# 4. DKIM有効化
aws sesv2 put-email-identity-dkim-attributes \
  --email-identity goo.ne.jp \
  --dkim-enabled true

# 5. 設定確認
aws sesv2 get-email-identity-dkim-attributes --email-identity goo.ne.jp
```

#### 5.3 監視システムの確認

**毎日証明書有効期限監視:**
```bash
# EventBridge Rule確認（新しい毎日監視）
aws events list-rules --name-prefix aws-ses-migration-prod --region ap-northeast-1 --no-verify-ssl

# 毎日スケジュール確認（毎日 9:00 実行）
aws events describe-rule \
  --name aws-ses-migration-prod-daily-certificate-monitor \
  --region ap-northeast-1 \
  --no-verify-ssl

# 証明書監視Lambda関数確認
aws lambda get-function \
  --function-name aws-ses-migration-prod-certificate-monitor \
  --region ap-northeast-1 \
  --no-verify-ssl

# CloudWatch Logs確認
aws logs describe-log-groups \
  --log-group-name-prefix /aws/lambda/aws-ses-migration-prod \
  --region ap-northeast-1 \
  --no-verify-ssl

# 監視ログの確認
aws logs describe-log-streams \
  --log-group-name /aws/lambda/aws-ses-migration-prod-certificate-monitor \
  --region ap-northeast-1 \
  --no-verify-ssl
```

#### 3.10 Enhanced Kinesis データ処理のデプロイ
```bash
uv run sceptre launch prod/enhanced-kinesis.yaml -y
```
**作成されるリソース:**
- Kinesis Data Firehose（本番向け最大バッファサイズ）
- データ変換Lambda関数（高性能設定）
- S3への配信設定（長期保存設定）
- IPアドレス別アクセス制御

#### 3.11 監視・マスキング機能のデプロイ
```bash
uv run sceptre launch prod/monitoring.yaml -y
```
**作成されるリソース:**
- CloudWatchダッシュボード（本番監視）
- カスタムメトリクス（有効化）
- データマスキングLambda関数（高性能設定）
- CloudWatch Insightsクエリ（本番用）

#### 3.12 セキュリティ・アクセス制御のデプロイ
```bash
uv run sceptre launch prod/security.yaml -y
```
**作成されるリソース:**
- IAMユーザー（prod-admin, prod-readonly, prod-monitoring）
- IAMグループとポリシー（厳格な権限設定）
- アクセス制御設定（IP制限有効）

### 4. 重要な手動ステップ

#### 4.1 Layer作成（Phase 2後に必須）
```bash
# cryptographyライブラリのLayer作成
./scripts/create-layer.sh prod aws-ses-migration

# 作成確認
aws lambda list-layers --region ap-northeast-1 --query "Layers[?contains(LayerName, 'aws-ses-migration-prod-cryptography')]"
```

### 6. 重要な設定パラメータ確認

#### 6.1 Phase-2 設定の確認
```bash
# DKIM Manager統合版設定パラメータ確認
cat sceptre/config/prod/phase-2-dkim-system.yaml | grep -A 10 "parameters:"

# 期待される設定値:
# CertificateValidityDays: 456  # 15ヶ月有効期限
# RenewalAlertDays: 60          # 60日前アラート  
# DKIMSeparator: "gooid-21-pro" # 本番環境用セパレーター
```

#### 6.2 監視スケジュールの確認
```bash
# 毎日監視スケジュール確認（毎日 9:00実行 - テスト用）
aws events describe-rule \
  --name aws-ses-migration-prod-daily-certificate-monitor \
  --region ap-northeast-1 \
  --no-verify-ssl \
  --query 'ScheduleExpression'

# 期待値: "cron(0 9 * * ? *)"  # 毎日 9:00AM JST

# 監視Lambda関数の確認
aws lambda get-function \
  --function-name aws-ses-migration-prod-certificate-monitor \
  --region ap-northeast-1 \
  --no-verify-ssl \
  --query 'Configuration.{Runtime:Runtime,Timeout:Timeout}'

# 期待値: {"Runtime": "python3.13", "Timeout": 300}
```

#### 6.3 Lambda関数バージョンの確認
```bash
# V2 Lambda関数の存在確認
aws lambda get-function \
  --function-name aws-ses-migration-prod-dkim-manager-v2 \
  --region ap-northeast-1 \
  --no-verify-ssl \
  --query 'Configuration.Description'

# 期待値: "Clean DKIM Manager Lambda function - AWS Official OpenSSL Implementation"
```

#### 6.4 本番運用時の監視スケジュール変更

**⚠️ 重要: 本番運用開始時の設定変更**

現在の設定はテスト用として毎日監視に設定されています。本番運用時には以下の変更を実施してください：

```bash
# phase-8-monitoring-system.yamlの監視スケジュール変更
# テスト用: "cron(0 9 * * ? *)"  # 毎日 9:00AM
# 本番用: "cron(0 9 1 * ? *)"   # 毎月1日 9:00AM

# 設定ファイルを編集後、再デプロイ
uv run sceptre launch prod/phase-8-monitoring-system.yaml --yes
```

**監視頻度の考慮事項:**
- **テスト期間**: 毎日監視で動作確認
- **本番運用**: 月次監視で十分（証明書有効期間456日 + 60日前アラート）
- **コスト最適化**: 月次監視でLambda実行コストを削減

#### 4.2 EasyDKIM無効化（Phase 3後に必須）
```bash
# Phase 3デプロイ直後に実行
./scripts/disable-easydkim-ssl-safe.sh goo.ne.jp ap-northeast-1

# 無効化確認
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1 --query "DkimAttributes.SigningEnabled"
# 期待値: false
```

**📋 注意事項:**
- **手動実行ステップ (Steps 1-3) は 3.6.1 で実行済み**
- **DNS設定待ちの状況は Phase 6 で管理**
- **トラブルシューティングが必要な場合は個別対応**

### 5. デプロイ状況の確認
```bash
# 全スタックの状況確認
uv run sceptre list stacks prod
```bash
# DKIM証明書生成用ペイロード作成
cat > create-dkim-payload.json << EOF
{
  "action": "create_dkim",
  "domain": "goo.ne.jp",
  "environment": "prod",
  "projectName": "aws-ses-migration",
  "dkimSeparator": "gooid-21-pro"
}
EOF

# DKIM証明書生成実行
aws lambda invoke --function-name aws-ses-migration-prod-dkim-manager --payload fileb://create-dkim-payload.json response-create-dkim.json

# 結果確認（DNS設定情報が含まれます）
cat response-create-dkim.json
```

**Step 3: DNS通知システムの確認**
```bash
# SNSサブスクリプション状態確認
aws sns list-subscriptions-by-topic --topic-arn "arn:aws:sns:ap-northeast-1:007773581311:aws-ses-migration-prod-dns-team-notifications" --region ap-northeast-1

# ⚠️ "SubscriptionArn": "Deleted" の場合は再作成が必要
```

**Step 4: DNS通知サブスクリプション再作成（必要な場合）**
```bash
# unsubscribeで削除された場合の再作成
aws sns subscribe --topic-arn "arn:aws:sns:ap-northeast-1:007773581311:aws-ses-migration-prod-dns-team-notifications" --protocol email --notification-endpoint "goo-idpay-sys@ml.nttdocomo.com" --region ap-northeast-1

# 📧 確認メールが送信されるので "Confirm subscription" をクリック
# ❌ "Unsubscribe" は絶対にクリックしない
```

**Step 5: Phase-5 DNS通知の再実行**
```bash
# Phase-5 DNS通知用ペイロード作成
cat > phase5-manager-payload.json << EOF
{
  "action": "phase_manager",
  "phase": "5",
  "domain": "goo.ne.jp",
  "environment": "prod",
  "projectName": "aws-ses-migration",
  "dkimSeparator": "gooid-21-pro"
}
EOF

# DNSチームへの通知実行
aws lambda invoke --function-name aws-ses-migration-prod-dkim-manager --payload fileb://phase5-manager-payload.json response-phase5-manager.json

# 通知送信結果確認
cat response-phase5-manager.json
```

**Step 6: 直接DNS通知送信（Lambda経由で失敗する場合）**
```bash
# 詳細なDNS設定要求を直接送信
aws sns publish --topic-arn "arn:aws:sns:ap-northeast-1:007773581311:aws-ses-migration-prod-dns-team-notifications" --message "DNS Configuration Required for BYODKIM Setup

Domain: goo.ne.jp
Environment: Production

Please add the following TXT records to DNS:

1. Record Name: gooid-21-pro-20250909-1._domainkey.goo.ne.jp
   Record Type: TXT
   Record Value: [生成されたDKIM公開キー1]

2. Record Name: gooid-21-pro-20250909-2._domainkey.goo.ne.jp
   Record Type: TXT
   Record Value: [生成されたDKIM公開キー2]

3. Record Name: gooid-21-pro-20250909-3._domainkey.goo.ne.jp
   Record Type: TXT
   Record Value: [生成されたDKIM公開キー3]

Please confirm when DNS records are added." --subject "BYODKIM DNS Configuration Request - goo.ne.jp" --region ap-northeast-1
```

**Step 7: DNS設定確認**
```bash
# 手動DNS設定後の確認
dig TXT gooid-21-pro-20250909-1._domainkey.goo.ne.jp
dig TXT gooid-21-pro-20250909-2._domainkey.goo.ne.jp
dig TXT gooid-21-pro-20250909-3._domainkey.goo.ne.jp
```

**📋 DNS通知で設定すべきTXTレコード例:**
- **レコード名**: `gooid-21-pro-YYYYMMDD-N._domainkey.goo.ne.jp`
- **レコードタイプ**: `TXT`
- **レコード値**: `k=rsa; p=[RSA公開キー]`

### 5. デプロイ状況の確認
```bash
# 全スタックの状況確認
uv run sceptre list stacks prod

# 各フェーズの詳細確認
uv run sceptre describe prod/base.yaml
uv run sceptre describe prod/phase-1-infrastructure-foundation.yaml
uv run sceptre describe prod/phase-2-dkim-system.yaml
uv run sceptre describe prod/phase-3-ses-byodkim.yaml
uv run sceptre describe prod/phase-4-dns-preparation.yaml
uv run sceptre describe prod/phase-5-dns-team-collaboration.yaml
uv run sceptre describe prod/phase-7-dns-validation-dkim-activation.yaml
uv run sceptre describe prod/phase-8-monitoring-system.yaml
uv run sceptre describe prod/enhanced-kinesis.yaml
uv run sceptre describe prod/monitoring.yaml
uv run sceptre describe prod/security.yaml
```

### 6. 動作確認

#### 6.1 基本リソースの確認
```bash
# S3バケットの確認
aws s3 ls | grep ses-migration-production

# CloudWatch Logsの確認
aws logs describe-log-groups --log-group-name-prefix "ses-migration-production"

# Lambda関数の確認
aws lambda list-functions --query 'Functions[?contains(FunctionName, `ses-migration-production`)]'

# Kinesis Data Firehoseの確認
aws firehose list-delivery-streams --query 'DeliveryStreamNames[?contains(@, `ses-migration-production`)]'
```

#### 6.2 SES設定の確認
```bash
# EmailIdentity（Primary）の確認
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1

# EasyDKIM無効化確認
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1 --query "DkimAttributes.SigningEnabled"
# 期待値: false

# ConfigurationSetの確認
aws sesv2 list-configuration-sets --region ap-northeast-1

# SES イベント発行設定の確認
aws sesv2 get-configuration-set-event-destinations \
  --configuration-set-name aws-ses-migration-prod-config-set \
  --region ap-northeast-1
```

#### 6.3 BYODKIM検証
```bash
# DNS伝播確認
dig TXT gooid-21-pro._domainkey.goo.ne.jp

# DKIM署名テスト（DNS設定完了後）
aws sesv2 send-email \
  --from-email-address "test@goo.ne.jp" \
  --destination ToAddresses="test@example.com" \
  --content Simple='{Subject={Data="BYODKIM Test",Charset="UTF-8"},Body={Text={Data="BYODKIM署名テストです",Charset="UTF-8"}}}' \
  --configuration-set-name aws-ses-migration-prod-config-set \
  --region ap-northeast-1

# DKIM Manager Lambda関数の確認
aws lambda get-function --function-name aws-ses-migration-prod-dkim-manager --region ap-northeast-1

# Layer確認
aws lambda list-layers --region ap-northeast-1 --query "Layers[?contains(LayerName, 'aws-ses-migration-prod-cryptography')]"
```

#### 6.4 監視・マスキング機能の確認
```bash
# CloudWatch Insightsクエリの確認
aws logs describe-query-definitions \
  --query-definition-name-prefix "ses-migration-production"

# データマスキングLambda関数のテスト
aws lambda invoke \
  --function-name "ses-migration-production-data-masking" \
  --payload '{"userGroups":["ses-migration-production-readonly"],"logData":"Email sent to user@goo.ne.jp from IP 192.168.1.100"}' \
  response.json

# マスキング結果の確認
cat response.json
```

#### 6.5 セキュリティ設定の確認
```bash
# IAMユーザーの確認
aws iam list-users --query 'Users[?contains(UserName, `prod-`)]'

# IAMグループの確認
aws iam list-groups --query 'Groups[?contains(GroupName, `ses-migration-production`)]'

# IP制限の確認（prod-readonlyユーザーで）
aws sts get-caller-identity
```

## 環境固有の設定

### 本番環境の特徴
- **ログ保持期間**: 731日（2年間、監査要件対応）
- **Lambda設定**: 512MB、60秒（高性能設定）
- **CloudWatch設定**: 731日ログ保持（監査要件対応）
- **通知先**: ops@goo.ne.jp（本番運用チーム）
- **ドメイン**: goo.ne.jp（Primary EmailIdentity Owner）
- **BYODKIM**: gooid-21-prod（本番用セレクタ）
- **IP制限**: 厳格なネットワーク制限

### Development環境との違い
| 項目 | Production | Development |
|------|------------|-------------|
| EmailIdentity | Primary Owner | 依存（共有）|
| BYODKIM Selector | gooid-21-pro | 開発環境用セレクタ |
| CloudWatch保持期間 | 731日 | 30日 |
| S3ログ保持期間 | 2555日 | 90日 |
| Lambda Memory | 512MB | 256MB |
| Lambda Timeout | 60秒 | 60秒 |
| アラート閾値 | 厳格設定 | 緩い設定 |
| IP制限 | 厳格制御 | 開発用緩和 |
| カスタムメトリクス | 有効 | 無効 |
| Layer管理 | 自動作成 | 自動作成 |
| EasyDKIM無効化 | 必須手動ステップ | 必須手動ステップ |

### 本番環境の注意事項
- **EmailIdentity Primary**: 他の環境（dev）が依存
- **BYODKIM責任**: DNS設定とキー管理の責任
- **8段階デプロイ**: Phase 1-8の順次実行が必要
- **手動ステップ**: Layer作成、EasyDKIM無効化、DNS設定
- **可用性要件**: 24時間365日稼働
- **セキュリティ**: 最高レベルの設定
- **監査要件**: 全操作ログの長期保存
- **DNS管理**: goo.ne.jpドメインの管理責任
- **Phase 6待機**: DNSチームによる手動設定完了待ち

## パラメータ設定の詳細

### base.yaml（基本インフラ）

#### 基本設定
- **ProjectCode**: `aws-ses-migration`
  - **パラメータの説明**: プロジェクト全体を識別するコード。すべてのリソース名のプレフィックスとして使用
  - **代入可能な値**: 英数字、ハイフン（-）、アンダースコア（_）、3-20文字
  - **デフォルト値**: ses-migration
  - **現在設定値**: aws-ses-migration
  - **効果**: CloudFormation スタック、S3バケット、IAMロール等のリソース名に使用

- **Environment**: `production`
  - **パラメータの説明**: デプロイ環境を識別する文字列。リソース名や設定値の決定に使用
  - **代入可能な値**: development, dev, staging, production, prod
  - **デフォルト値**: production
  - **現在設定値**: production
  - **効果**: 環境別のリソース分離、設定値の自動調整（ログ保持期間等）

### phase-1-infrastructure-foundation.yaml（BYODKIM基盤）

#### 基本設定
- **DKIMSeparator**: `gooid-21-pro`
  - **パラメータの説明**: BYODKIM用の一意識別子（DNS設定に使用）
  - **代入可能な値**: 英数字とハイフン（1-63文字）
  - **デフォルト値**: default
  - **現在設定値**: gooid-21-pro（本番環境専用）
  - **効果**: DNS TXTレコード名、DKIM署名セレクタとして使用

- **CertificateValidityDays**: `365`
  - **パラメータの説明**: DKIM証明書の有効期間（日数）
  - **代入可能な値**: 30〜1095の整数
  - **デフォルト値**: 365
  - **現在設定値**: 365（年1回更新）
  - **効果**: セキュリティと運用負荷のバランス

### phase-2-dkim-system.yaml（DKIM管理システム）

#### Lambda設定
- **CryptographyLayerKey**: `cryptography-layer.zip`
  - **パラメータの説明**: Lambda Layer用のS3オブジェクトキー
  - **代入可能な値**: 有効なS3オブジェクトキー
  - **デフォルト値**: cryptography-layer.zip
  - **現在設定値**: cryptography-layer.zip
  - **効果**: DKIM証明書処理用のcryptographyライブラリ提供

- **CertificateValidityDays**: `365`
  - **パラメータの説明**: 証明書有効期間設定
  - **代入可能な値**: 30〜1095の整数
  - **デフォルト値**: 365
  - **現在設定値**: 365
  - **効果**: 証明書ローテーション頻度の制御

### phase-3-ses-byodkim.yaml（SES設定）

#### SES基本設定
- **DKIMSeparator**: `gooid-21-pro`
  - **パラメータの説明**: phase-1と同じセレクタ（一貫性確保）
  - **代入可能な値**: phase-1と同一値必須
  - **現在設定値**: gooid-21-pro
  - **効果**: 一貫したBYODKIM設定

### enhanced-kinesis.yaml（データ処理パイプライン）

#### Kinesis設定
- **BufferSize**: `128`
  - **パラメータの説明**: Kinesis Data Firehoseのバッファサイズ（MB）
  - **代入可能な値**: 1〜128の整数
  - **デフォルト値**: 64
  - **現在設定値**: 128（本番環境用最大値）
  - **効果**: 最大処理能力、高スループット対応

- **RetentionDays**: `2555`
  - **パラメータの説明**: Kinesisデータの保持期間（日数）
  - **代入可能な値**: 1〜2555の整数
  - **デフォルト値**: 365
  - **現在設定値**: 2555（本番環境用最長保存）
  - **効果**: 監査要件対応、長期データ分析

#### アクセス制御（IPベース）
- **AdminIPRange**: `"10.0.0.0/8"`
  - **パラメータの説明**: 管理者アクセスを許可するIPアドレス範囲（フルアクセス・マスキングなし）
  - **代入可能な値**: CIDR表記のIPアドレス範囲
  - **デフォルト値**: "10.0.0.0/8"
  - **現在設定値**: "10.0.0.0/8"
  - **効果**: 管理者には生データへのフルアクセス許可

- **OperatorIPRange**: `"192.168.100.0/24"`
  - **パラメータの説明**: オペレータアクセスを許可するIPアドレス範囲（部分的マスキング）
  - **代入可能な値**: CIDR表記のIPアドレス範囲
  - **デフォルト値**: "192.168.1.0/24"
  - **現在設定値**: "192.168.100.0/24"（本番環境専用）
  - **効果**: 運用チームには制限付きアクセス許可

#### S3ライフサイクル設定
- **TransitionToIADays**: `30`
  - **パラメータの説明**: Standard から Infrequent Access への移行日数
  - **代入可能な値**: 30〜365の整数
  - **デフォルト値**: 30
  - **現在設定値**: 30
  - **効果**: ストレージコスト最適化（アクセス頻度の低いデータ）

- **TransitionToIntelligentTieringDays**: `90`
  - **パラメータの説明**: Intelligent Tiering への移行日数
  - **代入可能な値**: 30〜365の整数
  - **デフォルト値**: 60
  - **現在設定値**: 90（本番環境用調整）
  - **効果**: アクセスパターンに基づく自動コスト最適化

- **TransitionToGlacierDays**: `730`
  - **パラメータの説明**: Glacier への移行日数
  - **代入可能な値**: 90〜2555の整数
  - **デフォルト値**: 365
  - **現在設定値**: 730（2年保存後にアーカイブ）
  - **効果**: 長期保存データのコスト大幅削減

- **TransitionToDeepArchiveDays**: `1095`
  - **パラメータの説明**: Deep Archive への移行日数
  - **代入可能な値**: 180〜2555の整数
  - **デフォルト値**: 1095
  - **現在設定値**: 1095（3年保存後に最安アーカイブ）
  - **効果**: 最長期保存データの最大コスト削減

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

- **Environment**: `production`
  - **パラメータの説明**: デプロイ環境識別子（base.yamlと同一値必須）
  - **代入可能な値**: development, dev, staging, production, prod
  - **デフォルト値**: production
  - **現在設定値**: production
  - **効果**: 環境別のSES設定、Configuration Set名の決定

- **DomainName**: `goo.ne.jp`
  - **パラメータの説明**: SESで使用するドメイン名（Primary EmailIdentity Owner）
  - **代入可能な値**: 有効なドメイン名
  - **デフォルト値**: example.com
  - **現在設定値**: goo.ne.jp
  - **効果**: EmailIdentity設定、DKIM設定、DNS設定

- **CloudWatchLogRetentionDays**: `731`
  - **パラメータの説明**: SES関連のCloudWatch Logsログ保持期間
  - **代入可能な値**: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2555
  - **デフォルト値**: 2555
  - **現在設定値**: 731（2年間保存、監査要件対応）
  - **効果**: ログストレージコスト管理、監査要件の遵守

#### TRUE BYODKIM設定
- **DKIMMode**: `"BYODKIM"`
  - **パラメータの説明**: DKIM実装方式の選択
  - **代入可能な値**: "AWS_MANAGED", "BYODKIM"
  - **デフォルト値**: "AWS_MANAGED"
  - **現在設定値**: "BYODKIM"（TRUE BYODKIM実装）
  - **効果**: 独自DKIM鍵管理、高度なセキュリティ制御

- **BYODKIMSelector**: `"gooid-21-prod"`
  - **パラメータの説明**: BYODKIM用のセレクタ名（DNS設定に使用）
  - **代入可能な値**: 英数字とハイフン（1-63文字）
  - **デフォルト値**: "default"
  - **現在設定値**: "gooid-21-prod"（本番環境専用）
  - **効果**: 本番専用DKIM設定、dev環境との分離

- **BYODKIMRotationInterval**: `365`
  - **パラメータの説明**: BYODKIM鍵の自動ローテーション間隔（日数）
  - **代入可能な値**: 30〜730の整数
  - **デフォルト値**: 90
  - **現在設定値**: 365（年1回ローテーション）
  - **効果**: セキュリティと運用負荷のバランス

#### IP制限設定
- **SESAllowedIPs**:
  - **パラメータの説明**: SES送信を許可するIPアドレスのリスト（CIDR表記）
  - **代入可能な値**: IPv4 CIDR表記のリスト（例: 192.168.1.100/32）
  - **デフォルト値**: ["0.0.0.0/0"]（制限なし）
  - **現在設定値**: 
    ```yaml
    - 202.217.75.98/32
    - 202.217.75.91/32
    ```
  - **効果**: 不正送信防止、本番環境専用IPからの送信のみ許可

- **EnableSESIPFiltering**: `"true"`
  - **パラメータの説明**: SESのIP制限機能の有効/無効設定
  - **代入可能な値**: "true", "false"（文字列形式）
  - **デフォルト値**: "false"
  - **現在設定値**: "true"（本番環境で厳格制御）
  - **効果**: IP制限ポリシーの厳格な適用

#### アラート閾値設定（本番環境用厳格設定）
- **BounceRateThreshold**: `3.0`
  - **パラメータの説明**: バウンス率アラートの閾値（パーセンテージ）
  - **代入可能な値**: 0.1〜100.0の数値
  - **デフォルト値**: 5.0
  - **現在設定値**: 3.0（本番環境用に厳格化）
  - **効果**: 早期バウンス検出、送信品質管理

- **ComplaintRateThreshold**: `0.05`
  - **パラメータの説明**: 苦情率アラートの閾値（パーセンテージ）
  - **代入可能な値**: 0.01〜100.0の数値
  - **デフォルト値**: 0.1
  - **現在設定値**: 0.05（本番環境用に厳格化）
  - **効果**: スパム判定回避、送信レピュテーション保護

- **SuccessRateThreshold**: `98.0`
  - **パラメータの説明**: 送信成功率アラートの閾値（パーセンテージ）
  - **代入可能な値**: 0.1〜100.0の数値
  - **デフォルト値**: 95.0
  - **現在設定値**: 98.0（本番環境用に厳格化）
  - **効果**: 高い配信品質の維持、サービス品質保証

### enhanced-kinesis.yaml（データ処理パイプライン）

#### Kinesis設定
- **BufferSize**: `128`
  - **パラメータの説明**: Kinesis Data Firehoseのバッファサイズ（MB）
  - **代入可能な値**: 1〜128の整数
  - **デフォルト値**: 64
  - **現在設定値**: 128（本番環境用最大値）
  - **効果**: 最大処理能力、高スループット対応

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

- **RetentionDays**: `2555`
  - **パラメータの説明**: Kinesisデータの保持期間（日数）
  - **代入可能な値**: 1〜2555の整数
  - **デフォルト値**: 365
  - **現在設定値**: 2555（本番環境用最長保存）
  - **効果**: 監査要件対応、長期データ分析

#### アクセス制御
- **AdminIPRange**: `"10.0.0.0/8"`
  - **パラメータの説明**: 管理者アクセスを許可するIPアドレス範囲
  - **代入可能な値**: CIDR表記のIPアドレス範囲
  - **デフォルト値**: "10.0.0.0/8"
  - **現在設定値**: "10.0.0.0/8"
  - **効果**: 管理機能への不正アクセス防止

- **OperatorIPRange**: `"192.168.100.0/24"`
  - **パラメータの説明**: オペレータアクセスを許可するIPアドレス範囲
  - **代入可能な値**: CIDR表記のIPアドレス範囲
  - **デフォルト値**: "192.168.1.0/24"
  - **現在設定値**: "192.168.100.0/24"（本番環境専用）
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

#### ログ・保持設定
- **RetentionDays**: `731`
  - **パラメータの説明**: S3バケットでのログ保持期間（日数）
  - **代入可能な値**: 1〜2555の整数
  - **デフォルト値**: 365
  - **現在設定値**: 731（2年間保存、監査要件対応）
  - **効果**: 監査要件対応、コスト管理

- **CloudWatchLogRetentionDays**: `731`
  - **パラメータの説明**: CloudWatch Logsでのログ保持期間（日数）
  - **代入可能な値**: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2555
  - **デフォルト値**: 365
  - **現在設定値**: 731（2年間保存、監査要件対応）
  - **効果**: 監査要件対応、ログストレージコスト管理

#### Lambda設定
- **LambdaMemorySize**: `512`
  - **パラメータの説明**: Lambda関数に割り当てるメモリサイズ（MB）
  - **代入可能な値**: 128, 256, 512, 1024, 1536, 2048, 3008
  - **デフォルト値**: 256
  - **現在設定値**: 512（本番環境用に強化）
  - **効果**: 高性能処理、レスポンス時間改善

- **LambdaTimeout**: `60`
  - **パラメータの説明**: Lambda関数の最大実行時間（秒）
  - **代入可能な値**: 1〜900の整数
  - **デフォルト値**: 60
  - **現在設定値**: 60
  - **効果**: 適切なタイムアウト設定、コスト管理

- **LambdaRuntime**: `python3.9`
  - **パラメータの説明**: Lambda関数の実行環境
  - **代入可能な値**: python3.7, python3.8, python3.9, python3.10, python3.11
  - **デフォルト値**: python3.9
  - **現在設定値**: python3.9
  - **効果**: 実行環境の統一、セキュリティアップデート対応

#### 機能フラグ
- **EnableCustomMetrics**: `"true"`
  - **パラメータの説明**: カスタムCloudWatchメトリクスの有効/無効
  - **代入可能な値**: "true", "false"（文字列形式）
  - **デフォルト値**: "true"
  - **現在設定値**: "true"（本番環境で有効）
  - **効果**: 詳細監視、高度な分析機能

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
- **BYODKIMSelector**: `"gooid-21-prod"`
  - **パラメータの説明**: 本番環境用のDKIMセレクタ名
  - **代入可能な値**: 英数字とハイフン（1-63文字）
  - **デフォルト値**: "default"
  - **現在設定値**: "gooid-21-prod"（本番環境専用）
  - **効果**: 本番環境のDKIM設定、dev環境との分離

### security.yaml（セキュリティ・アクセス制御）

#### ユーザー設定
- **AdminUsername**: `prod-admin`
  - **パラメータの説明**: 管理者権限を持つIAMユーザー名
  - **代入可能な値**: 英数字、ハイフン、アンダースコア（1-64文字）
  - **デフォルト値**: production-admin
  - **現在設定値**: prod-admin
  - **効果**: フル管理権限でのリソース操作、システム設定変更

- **ReadonlyUsername**: `prod-readonly`
  - **パラメータの説明**: 読み取り専用権限を持つIAMユーザー名
  - **代入可能な値**: 英数字、ハイフン、アンダースコア（1-64文字）
  - **デフォルト値**: production-readonly
  - **現在設定値**: prod-readonly
  - **効果**: システム状況確認、ログ閲覧（変更権限なし）

- **MonitoringUsername**: `prod-monitoring`
  - **パラメータの説明**: 監視専用権限を持つIAMユーザー名
  - **代入可能な値**: 英数字、ハイフン、アンダースコア（1-64文字）
  - **デフォルト値**: production-monitoring
  - **現在設定値**: prod-monitoring
  - **効果**: CloudWatch、ログ、メトリクスへの監視アクセス

#### 連絡先設定
- **AdminEmail**: `admin@goo.ne.jp`
  - **パラメータの説明**: 管理者の連絡先メールアドレス
  - **代入可能な値**: 有効なメールアドレス形式
  - **デフォルト値**: admin@goo.ne.jp
  - **現在設定値**: admin@goo.ne.jp
  - **効果**: 重要なアラート通知、セキュリティ通知の受信

- **ReadonlyEmail**: `readonly@goo.ne.jp`
  - **パラメータの説明**: 読み取り専用ユーザーの連絡先メールアドレス
  - **代入可能な値**: 有効なメールアドレス形式
  - **デフォルト値**: readonly@goo.ne.jp
  - **現在設定値**: readonly@goo.ne.jp
  - **効果**: レポート通知、システム状況通知の受信

- **MonitoringEmail**: `monitoring@goo.ne.jp`
  - **パラメータの説明**: 監視ユーザーの連絡先メールアドレス
  - **代入可能な値**: 有効なメールアドレス形式
  - **デフォルト値**: monitoring@goo.ne.jp
  - **現在設定値**: monitoring@goo.ne.jp
  - **効果**: 監視アラート、パフォーマンス通知の受信

#### 機能フラグ
- **EnableIPRestriction**: `"true"`
  - **パラメータの説明**: IP制限機能の有効/無効設定
  - **代入可能な値**: "true", "false"（文字列形式）
  - **デフォルト値**: "true"
  - **現在設定値**: "true"（本番環境で厳格制御）
  - **効果**: アクセス制限の厳格な適用、セキュリティ強化

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

#### 0. 企業ネットワーク環境でのSSL証明書問題（✅ 解決済み）
```bash
# 問題: SSL certificate verify failed
# 症状: aws command や uv pip install でSSLエラー
# エラー例: 
# - [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed
# - InsecureRequestWarning表示

# ✅ 解決法（既適用済み）:
# 1. 環境変数設定
export AWS_CA_BUNDLE=""
export PYTHONHTTPSVERIFY=0
export SSL_VERIFY=false

# 2. AWS CLI設定
aws configure set ca_bundle ""

# 3. AWS CLIコマンドに--no-verify-sslオプション追加
aws sts get-caller-identity --no-verify-ssl
aws lambda invoke --function-name [name] --no-verify-ssl [other options]

# 4. Layer作成は専用SSL対応スクリプト使用
./scripts/create-layer-ssl-safe.sh
```

#### 1. TRUE BYODKIM DNS設定エラー
```bash
# DNS設定確認
dig TXT gooid-21-prod._domainkey.goo.ne.jp

# エラー例: DNS record not found
# 解決法: DNS TXT レコードの正確な設定
# - レコード名: gooid-21-prod._domainkey.goo.ne.jp
# - レコード値: 生成されたDKIM公開キー
```

#### 2. EmailIdentity作成エラー
```bash
# エラー例: EmailIdentity already exists
# 解決法: 既存のEmailIdentityの確認と削除
aws sesv2 delete-email-identity --email-identity goo.ne.jp --region ap-northeast-1
```

#### 3. 本番環境権限エラー
```bash
# エラー例: Access denied for production resources
# 解決法: 本番環境IAM権限の確認
aws sts get-caller-identity
aws iam get-user
```

#### 4. スタック依存関係エラー
```bash
# エラー例: Stack dependency not found
# 解決法: 依存関係の順次デプロイ
uv run sceptre launch prod/base.yaml -y
uv run sceptre launch prod/enhanced-kinesis.yaml -y
uv run sceptre launch prod/ses.yaml -y
uv run sceptre launch prod/monitoring.yaml -y
uv run sceptre launch prod/security.yaml -y
```

### 本番環境専用デバッグ手順
```bash
# 本番スタック作成の詳細ログ確認
uv run sceptre launch prod/[stack-name].yaml --debug

# CloudFormationイベント確認
aws cloudformation describe-stack-events \
  --stack-name ses-migration-production-[stack-name]

# リソース作成状況確認
aws cloudformation list-stack-resources \
  --stack-name ses-migration-production-[stack-name]

# 本番環境特有のログ確認
aws logs describe-log-groups --log-group-name-prefix "ses-migration-production"
```

### 緊急時ロールバック手順
```bash
# 緊急時の即座ロールバック（本番環境用）
# 注意: 本番データへの影響を事前確認

# 1. 問題のあるスタックの詳細確認
uv run sceptre describe prod/[problem-stack].yaml

# 2. 依存関係を考慮した削除順序（逆順）
uv run sceptre delete prod/security.yaml -y
uv run sceptre delete prod/monitoring.yaml -y
uv run sceptre delete prod/ses.yaml -y
uv run sceptre delete prod/enhanced-kinesis.yaml -y
uv run sceptre delete prod/base.yaml -y

# 3. 前回正常版からの再デプロイ
git checkout [previous-stable-commit]
uv run sceptre launch prod/base.yaml -y
uv run sceptre launch prod/enhanced-kinesis.yaml -y
uv run sceptre launch prod/ses.yaml -y
uv run sceptre launch prod/monitoring.yaml -y
uv run sceptre launch prod/security.yaml -y
```

### 本番環境監視
```bash
# リアルタイム監視
aws logs tail /aws/lambda/ses-migration-production-data-masking --follow

# TRUE BYODKIM状況確認
aws sesv2 get-email-identity-dkim-attributes \
  --email-identity goo.ne.jp \
  --region ap-northeast-1

# 本番環境メトリクス確認
aws cloudwatch get-metric-statistics \
  --namespace "ses-migration/production/SES" \
  --metric-name "Send" \
  --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

## クリーンアップ

### ⚠️ 本番環境削除の重要注意事項 ⚠️
**本番環境の削除は以下の承認とチェックが完了してから実行してください**

#### 削除前必須確認事項
1. **ビジネス影響の確認**
   - サービス停止による顧客への影響
   - メール配信サービスの代替手段確保
   - ステークホルダーへの事前通知完了

2. **データバックアップの確認**
   - 重要な設定データのバックアップ
   - CloudWatch Logsの必要な情報の保存
   - S3バケット内の重要データの移行

3. **dependencies確認**
   - 開発環境（dev）への影響確認
   - 他のシステムでのgoo.ne.jpドメイン使用状況確認

#### 本番環境削除手順（承認後のみ実行）
```bash
# 段階的削除（依存関係を考慮して逆順）

# 1. セキュリティスタックの削除
uv run sceptre delete prod/security.yaml -y
# 確認: IAMユーザー・グループの削除確認

# 2. 監視スタックの削除  
uv run sceptre delete prod/monitoring.yaml -y
# 確認: CloudWatchダッシュボード・アラームの削除確認

# 3. SESスタックの削除（EmailIdentity削除）
# ⚠️ 警告: goo.ne.jpドメイン設定が削除されます
uv run sceptre delete prod/ses.yaml -y
# 確認: EmailIdentity、BYODKIM設定の削除確認

# 4. Enhanced Kinesisスタックの削除
uv run sceptre delete prod/enhanced-kinesis.yaml -y
# 確認: Kinesis Firehose、Lambda関数の削除確認

# 5. 基本インフラスタックの削除
uv run sceptre delete prod/base.yaml -y
# 確認: S3バケット、KMS鍵の削除確認
```

#### 削除完了後の確認
```bash
# 全リソースの削除確認
aws cloudformation list-stacks \
  --stack-status-filter DELETE_COMPLETE \
  --query 'StackSummaries[?contains(StackName, `ses-migration-production`)]'

# EmailIdentity削除確認
aws sesv2 list-email-identities --region ap-northeast-1

# S3バケット削除確認
aws s3 ls | grep ses-migration-production

# IAMリソース削除確認
aws iam list-users --query 'Users[?contains(UserName, `prod-`)]'
aws iam list-groups --query 'Groups[?contains(GroupName, `ses-migration-production`)]'
```

### 削除時の重要な注意事項
- **EmailIdentity削除**: goo.ne.jpのSES設定が完全に削除されます
- **開発環境への影響**: dev環境がprod環境に依存している場合、先にdev環境を削除する必要があります
- **DNS設定**: BYODKIM用DNS TXT レコードは手動で削除する必要があります
- **監査要件**: 削除ログは監査用に保存してください
- **復旧不可**: 一度削除されたリソースは復旧できません

### DNS設定のクリーンアップ
```bash
# BYODKIM DNS TXT レコードの削除
# 手動でDNS管理画面から以下のレコードを削除:
# - gooid-21-prod._domainkey.goo.ne.jp TXT レコード

# 削除確認
dig TXT gooid-21-prod._domainkey.goo.ne.jp
# 期待値: レコードが見つからない（NXDOMAIN）
```

## 追加情報

### TRUE BYODKIM運用
本番環境では以下のBYODKIM運用が重要です：

#### DNS設定の監視
```bash
# 定期的なDNS設定確認（日次推奨）
dig TXT gooid-21-prod._domainkey.goo.ne.jp

# DKIM署名検証
aws sesv2 get-email-identity-dkim-attributes \
  --email-identity goo.ne.jp \
  --region ap-northeast-1
```

#### 鍵ローテーション
- **自動ローテーション**: 365日間隔で設定済み
- **手動ローテーション**: 必要に応じてKMS鍵の手動更新

#### セキュリティ監視
```bash
# BYODKIM関連のCloudWatch Insightsクエリ実行
aws logs start-query \
  --log-group-name "/aws/lambda/ses-migration-production-byodkim-monitoring" \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /BYODKIM/'
```

### 災害復旧計画
#### バックアップ戦略
- **設定ファイル**: Git リポジトリによるバージョン管理
- **KMS鍵**: 自動バックアップ（AWS管理）
- **CloudWatch Logs**: 731日間保存設定
- **S3データ**: クロスリージョンレプリケーション（必要に応じて）

#### 復旧手順
1. **Gitリポジトリからの設定復旧**
2. **KMS鍵の復旧（必要に応じて新規作成）**
3. **DNS設定の再構築**
4. **スタックの順次再作成**

### 本番環境の継続的改善
- **月次レビュー**: 設定とパフォーマンスの確認
- **四半期評価**: セキュリティと監査要件の確認
- **年次アップデート**: AWS サービスの最新機能適用

### コンプライアンス対応
- **個人情報保護法**: データマスキング機能による対応
- **監査要件**: 731日間のログ保持
- **アクセス制御**: 最小権限の原則
- **暗号化**: 保存時・転送時の暗号化実装

このドキュメントは本番環境の重要な運用手順を記載しています。変更時は必ず承認プロセスを経て実行してください。
