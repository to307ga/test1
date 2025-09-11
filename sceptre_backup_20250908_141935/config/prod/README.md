# Production環境 デプロイ手順書

## 概要
本番環境用のAWS SESインフラストラクチャをデプロイするための手順書です。本環境は**goo.ne.jpドメインのEmailIdentityの主要管理者**として、TRUE BYODKIM実装を含む完全なSESサービスを提供します。

## 前提条件
- AWS CLI設定済み（Tokyo Region: ap-northeast-1）
- Sceptre 4.5.3以上インストール済み
- **本番環境への適切なAWS権限があること**
- 本番環境の承認プロセスが完了していること
- NTT DOCOMO VDI/大手町ネットワークもしくはSplashTopからのアクセス
- **TRUE BYODKIM用DNS設定権限があること**

## アーキテクチャ概要
```
Production SES (goo.ne.jp) ← Primary EmailIdentity Owner
  ├── TRUE BYODKIM (gooid-21-prod)
  ├── Base Infrastructure  
  ├── SES Configuration (Production Primary)
  ├── Enhanced Kinesis Data Processing
  ├── Monitoring & Data Masking
  └── Security & Access Control
       ↓ (共有設定)
Development Environment (依存関係)
```

## デプロイ手順

### 1. 環境設定の確認
```bash
# sceptreディレクトリに移動
cd sceptre

# prodディレクトリの設定ファイル確認
ls -la config/prod/
# 期待されるファイル:
# - base.yaml              (基本インフラ)
# - ses.yaml               (SES設定 - Primary EmailIdentity)
# - enhanced-kinesis.yaml  (データ処理パイプライン)
# - monitoring.yaml        (監視・マスキング)
# - security.yaml          (セキュリティ・アクセス制御)
# - config.yaml            (共通設定)
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
sceptre launch prod/base
```
**作成されるリソース:**
- S3バケット（Raw/Masked/Error Logs用、本番向け高可用性設定）
- KMS暗号化キー（本番レベルセキュリティ）
- SNS通知トピック（ops@goo.ne.jp）
- アクセスログ設定（監査要件対応）

#### 3.2 Enhanced Kinesisデータ処理のデプロイ
```bash
sceptre launch prod/enhanced-kinesis
```
**作成されるリソース:**
- Kinesis Data Firehose（本番向け最大バッファサイズ）
- データ変換Lambda関数（高性能設定）
- S3への配信設定（長期保存設定）

#### 3.3 SES設定のデプロイ（Primary EmailIdentity作成）
```bash
sceptre launch prod/ses
```
**作成されるリソース:**
- **goo.ne.jp EmailIdentity（Primary）**
- **TRUE BYODKIM設定（gooid-21-prod）**
- Production用ConfigurationSet
- IP制限ポリシー（本番ネットワーク限定）
- CloudWatchログ設定（長期保存）
- イベント発行設定

#### 3.4 監視・マスキング機能のデプロイ
```bash
sceptre launch prod/monitoring
```
**作成されるリソース:**
- CloudWatchダッシュボード（本番監視）
- カスタムメトリクス（有効化）
- データマスキングLambda関数（高性能設定）
- CloudWatch Insightsクエリ（本番用）

#### 3.5 セキュリティ・アクセス制御のデプロイ
```bash
sceptre launch prod/security
```
**作成されるリソース:**
- IAMユーザー（prod-admin, prod-readonly, prod-monitoring）
- IAMグループとポリシー（厳格な権限設定）
- アクセス制御設定（IP制限有効）

### 4. TRUE BYODKIM DNS設定

#### 4.1 BYODKIM情報の取得
```bash
# DNS設定用の情報生成
cd sceptre
python generate_byodkim_dns.py

# 出力されるDNS設定情報を確認
cat true_byodkim_dns_config.json
```

#### 4.2 DNS TXT レコード設定
**必要なDNS設定:**
- レコード名: `gooid-21-prod._domainkey.goo.ne.jp`
- レコードタイプ: `TXT`
- レコード値: 出力されたDKIM公開キー

**設定例:**
```
gooid-21-prod._domainkey.goo.ne.jp. TXT "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..."
```

### 5. デプロイ状況の確認
```bash
# 全スタックの状況確認
sceptre list-stacks prod

# 各スタックの詳細確認
sceptre describe-stack-events prod/base
sceptre describe-stack-events prod/enhanced-kinesis
sceptre describe-stack-events prod/ses
sceptre describe-stack-events prod/monitoring
sceptre describe-stack-events prod/security
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

# BYODKIM設定の確認
aws sesv2 get-email-identity-dkim-attributes \
  --email-identity goo.ne.jp \
  --region ap-northeast-1

# ConfigurationSetの確認
aws sesv2 list-configuration-sets --region ap-northeast-1

# SES イベント発行設定の確認
aws sesv2 get-configuration-set-event-destinations \
  --configuration-set-name ses-migration-production \
  --region ap-northeast-1
```

#### 6.3 TRUE BYODKIM検証
```bash
# DNS伝播確認
dig TXT gooid-21-prod._domainkey.goo.ne.jp

# DKIM署名テスト
aws sesv2 send-email \
  --from-email-address "test@goo.ne.jp" \
  --destination ToAddresses="test@example.com" \
  --content Simple='{Subject={Data="BYODKIM Test",Charset="UTF-8"},Body={Text={Data="BYODKIM署名テストです",Charset="UTF-8"}}}' \
  --configuration-set-name ses-migration-production \
  --region ap-northeast-1
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
| BYODKIM Selector | gooid-21-prod | gooid-21-dev |
| CloudWatch保持期間 | 731日 | 30日 |
| S3ログ保持期間 | 2555日 | 90日 |
| Lambda Memory | 512MB | 256MB |
| Lambda Timeout | 60秒 | 60秒 |
| アラート閾値 | 厳格設定 | 緩い設定 |
| IP制限 | 厳格制御 | 開発用緩和 |
| カスタムメトリクス | 有効 | 無効 |

### 本番環境の注意事項
- **EmailIdentity Primary**: 他の環境（dev）が依存
- **BYODKIM責任**: DNS設定とキー管理の責任
- **可用性要件**: 24時間365日稼働
- **セキュリティ**: 最高レベルの設定
- **監査要件**: 全操作ログの長期保存
- **DNS管理**: goo.ne.jpドメインの管理責任

## パラメータ設定の詳細

### base.yaml（基本インフラ）

#### 基本設定
- **ProjectCode**: `ses-migration`
  - **パラメータの説明**: プロジェクト全体を識別するコード。すべてのリソース名のプレフィックスとして使用
  - **代入可能な値**: 英数字、ハイフン（-）、アンダースコア（_）、3-20文字
  - **デフォルト値**: ses-migration
  - **現在設定値**: ses-migration
  - **効果**: CloudFormation スタック、S3バケット、IAMロール等のリソース名に使用

- **Environment**: `production`
  - **パラメータの説明**: デプロイ環境を識別する文字列。リソース名や設定値の決定に使用
  - **代入可能な値**: development, dev, staging, production, prod
  - **デフォルト値**: production
  - **現在設定値**: production
  - **効果**: 環境別のリソース分離、設定値の自動調整（ログ保持期間等）

- **RetentionDays**: `365`
  - **パラメータの説明**: S3バケットでのログファイル保持期間（日数）
  - **代入可能な値**: 1〜2555の整数
  - **デフォルト値**: 2555
  - **現在設定値**: 365（本番環境用設定）
  - **効果**: ストレージコスト管理、監査要件への対応

- **NotificationEmail**: `admin@goo.ne.jp`
  - **パラメータの説明**: アラートや通知を受信するメールアドレス
  - **代入可能な値**: 有効なメールアドレス形式
  - **デフォルト値**: admin@goo.ne.jp
  - **現在設定値**: admin@goo.ne.jp
  - **効果**: 障害通知、アラート受信、システム状況の把握

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
sceptre launch prod/base
sceptre launch prod/enhanced-kinesis
sceptre launch prod/ses
sceptre launch prod/monitoring
sceptre launch prod/security
```

### 本番環境専用デバッグ手順
```bash
# 本番スタック作成の詳細ログ確認
sceptre launch prod/[stack-name] --debug

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
sceptre describe-stack-events prod/[problem-stack]

# 2. 依存関係を考慮した削除順序（逆順）
sceptre delete prod/security
sceptre delete prod/monitoring  
sceptre delete prod/ses
sceptre delete prod/enhanced-kinesis
sceptre delete prod/base

# 3. 前回正常版からの再デプロイ
git checkout [previous-stable-commit]
sceptre launch prod/base
sceptre launch prod/enhanced-kinesis
sceptre launch prod/ses
sceptre launch prod/monitoring
sceptre launch prod/security
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
sceptre delete prod/security
# 確認: IAMユーザー・グループの削除確認

# 2. 監視スタックの削除  
sceptre delete prod/monitoring
# 確認: CloudWatchダッシュボード・アラームの削除確認

# 3. SESスタックの削除（EmailIdentity削除）
# ⚠️ 警告: goo.ne.jpドメイン設定が削除されます
sceptre delete prod/ses
# 確認: EmailIdentity、BYODKIM設定の削除確認

# 4. Enhanced Kinesisスタックの削除
sceptre delete prod/enhanced-kinesis
# 確認: Kinesis Firehose、Lambda関数の削除確認

# 5. 基本インフラスタックの削除
sceptre delete prod/base
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
