# AWS SES Infrastructure with Sceptre + CloudFormation

## 概要

このプロジェクトは、AWS SES（Simple Email Service）のインフラストラクチャをSceptre + CloudFormationで構築し、個人情報保護機能を含む包括的な監視・セキュリティシステムを提供します。

## ディレクトリ構造

```
templates/sceptre/
├── dev/                          # 開発・テスト環境
│   ├── base.yaml                # 基本インフラ設定
│   ├── ses.yaml                 # SES設定
│   ├── monitoring.yaml          # 監視・マスキング機能設定
│   ├── security.yaml            # セキュリティ・アクセス制御設定
│   └── README.md                # 開発環境デプロイ手順書
├── prod/                        # 本番環境
│   ├── base.yaml                # 基本インフラ設定
│   ├── ses.yaml                 # SES設定
│   ├── monitoring.yaml          # 監視・マスキング機能設定
│   ├── security.yaml            # セキュリティ・アクセス制御設定
│   └── README.md                # 本番環境デプロイ手順書
├── templates/                    # CloudFormationテンプレート
│   ├── base.yaml                # 基本インフラテンプレート
│   ├── ses.yaml                 # SES設定テンプレート
│   ├── monitoring.yaml          # 監視・マスキング機能テンプレート
│   └── security.yaml            # セキュリティ・アクセス制御テンプレート
├── config.yaml                  # 共通設定
└── README.md                    # このファイル
```

## 環境別の特徴

### Dev環境
- **用途**: 開発・テスト
- **ドメイン**: dev.example.com
- **ログ保持**: 30日
- **Lambda設定**: 軽量（128MB、30秒）
- **パスワードポリシー**: 緩い設定
- **通知先**: 開発用メールアドレス

### Production環境
- **用途**: 本番運用
- **ドメイン**: goo.ne.jp
- **ログ保持**: 2555日（7年間）
- **Lambda設定**: 本格（256MB、60秒）
- **パスワードポリシー**: 厳格設定
- **通知先**: 本番用メールアドレス・電話番号

## 主要機能

### 1. 個人情報保護・マスキング機能
- **メールアドレスマスキング**: `u***@***.***` 形式
- **IPアドレスマスキング**: `192.*.*.*` 形式
- **ユーザー権限による制御**:
  - Admin: 完全な情報表示
  - ReadOnly/Monitoring: マスクされた情報表示

### 2. セキュリティ機能
- IPアドレス制限によるアクセス制御
- IAMユーザー・グループによる権限管理
- CloudTrailによる監査ログ
- AWS Configによるコンプライアンス監視

### 3. 監視・アラート機能
- CloudWatchアラーム
- カスタムメトリクス
- ログ分析・クエリ

## デプロイ手順

### 開発環境のデプロイ
```bash
cd dev
sceptre create-stack dev base
sceptre create-stack dev ses
sceptre create-stack dev monitoring
sceptre create-stack dev security
```

### 本番環境のデプロイ
```bash
cd prod
sceptre create-stack prod base
sceptre create-stack prod ses
sceptre create-stack prod monitoring
sceptre create-stack prod security
```

## スタックの依存関係

```
base (基本インフラ)
├── S3バケット
├── SNSトピック
├── CloudTrail
└── AWS Config

ses (SES設定)
├── ドメイン設定
├── DKIM設定
├── 受信ルール
└── CloudWatch統合
    └── base::LogBucketName
    └── base::NotificationTopicArn

monitoring (監視・マスキング)
├── CloudWatchアラーム
├── Insightsクエリ
├── Lambda関数
└── カスタムメトリクス
    └── ses::SESLogGroupName
    └── base::LogBucketName
    └── base::NotificationTopicArn

security (セキュリティ・アクセス制御)
├── IAMグループ・ユーザー
├── アクセス制御ポリシー
└── IP制限
    └── monitoring::DataMaskingFunctionArn
    └── monitoring::AdminQueryDefinitionName
    └── monitoring::MaskedQueryDefinitionName
```

## パラメータの設定

### 環境別パラメータ
各環境（dev/prod）のディレクトリ内のYAMLファイルで、環境固有のパラメータを設定します。

### 共通パラメータ
- `ProjectCode`: プロジェクトコード
- `Environment`: 環境名
- `DomainName`: SESドメイン名
- `AllowedIPRanges`: 許可IPアドレス範囲

### 環境固有パラメータ
- **Dev**: 軽量設定、短いログ保持期間
- **Prod**: 本格設定、長いログ保持期間、厳格なセキュリティ

## 個人情報保護の詳細

### マスキングレベル
- **メールアドレス**: `u***@***.***`
- **IPアドレス**: `192.*.*.*`

### アクセス制御
| ユーザー権限 | メールアドレス | IPアドレス | アクセス可能IP |
|-------------|---------------|------------|----------------|
| Admin      | 完全表示      | 完全表示   | 制限なし       |
| ReadOnly   | マスク表示    | マスク表示 | 許可されたIPのみ |
| Monitoring | マスク表示    | マスク表示 | 許可されたIPのみ |

### 実装方法
1. **CloudWatch Insights**: 2つのクエリ定義（Admin用・マスク用）
2. **Lambda関数**: リアルタイムデータマスキング
3. **IAMポリシー**: ユーザー権限とIP制限の組み合わせ

## 運用・監視

### ログ分析
```bash
# Admin用クエリ（完全表示）
aws logs start-query \
  --log-group-name "ses-migration-production-ses" \
  --query-string "fields @timestamp, eventType, destination, sourceIp | filter eventType = 'bounce'"

# マスク用クエリ（個人情報保護）
aws logs start-query \
  --log-group-name "ses-migration-production-ses" \
  --query-string "fields @timestamp, eventType, maskedDestination, maskedSourceIp | filter eventType = 'bounce'"
```

### アラート設定
- バウンス率 > 5%
- 苦情率 > 0.1%
- 送信成功率 < 95%

## トラブルシューティング

### よくある問題
1. **スタック作成エラー**
   - パラメータ値の確認
   - AWS権限の確認
   - 依存関係の確認

2. **個人情報保護・マスキング機能の異常**
   - Lambda関数のログ確認
   - IAMポリシーの確認
   - CloudWatch Insightsクエリの確認

### ロールバック手順
```bash
# 問題のあるスタックの削除
sceptre delete-stack [env] [stack-name]

# 再デプロイ
sceptre create-stack [env] [stack-name]
```

## セキュリティ考慮事項

### データ保護
- 個人情報の自動マスキング
- アクセスログの記録
- 暗号化の適用

### アクセス制御
- 最小権限の原則
- IPアドレス制限
- 多要素認証の推奨

### 監査・コンプライアンス
- CloudTrailによるAPI呼び出しログ
- AWS Configによるリソース設定監視
- 定期的なセキュリティレビュー

## 参考資料

### 関連ドキュメント
- [要件定義](../../要件定義.md)
- [個人情報保護・マスキング設定書](../../docs/operations/02_個人情報保護・マスキング設定書.md)
- [移行手順書](../../docs/migration/01_移行手順書.md)

### AWS公式ドキュメント
- [AWS SES 開発者ガイド](https://docs.aws.amazon.com/ses/latest/dg/)
- [CloudFormation ユーザーガイド](https://docs.aws.amazon.com/cloudformation/)
- [CloudWatch ユーザーガイド](https://docs.aws.amazon.com/cloudwatch/)

### Sceptre公式ドキュメント
- [Sceptre ドキュメント](https://sceptre.cloudreach.com/)

## ライセンス

このプロジェクトは社内利用を目的としています。

## サポート

技術的な質問や問題がある場合は、開発チームまでお問い合わせください。
