# AWS SES マイグレーション プロジェクト

オンプレミス環境のPostfix + CuenoteからAWS SESへのマイグレーションプロジェクト

## 📋 プロジェクト概要

### 目的
- オンプレミス環境で運用しているPostfix + Cuenoteのメール送信システムをAWS SESへマイグレーション
- 運用の自動化とコスト最適化を実現
- セキュリティ強化と監査体制の確立

### 対象システム
- **現在**: オンプレミスPostfix + Cuenote（リレー先）
- **移行先**: AWS SES + Amazon Data Firehose
- **対象ドメイン**: goo.ne.jp
- **送信量**: 5,300,000通/日

## 🗂️ プロジェクト構造

```
AWS_SES_NOT_DNS/
├── 要件定義.md                    # プロジェクト要件定義
├── README.md                     # プロジェクト概要（このファイル）
├── docs/                         # ドキュメント
│   ├── design/                   # 設計書
│   │   ├── 01_システム設計書.md
│   │   ├── 02_ネットワーク構成図.md
│   │   └── 03_セキュリティ設計書.md
│   ├── migration/                # 移行関連
│   │   └── 01_移行手順書.md
│   ├── operations/               # 運用関連
│   │   └── 01_監視・アラート設定書.md
│   └── implementation/           # 実装関連
├── sceptre/                      # Sceptre + CloudFormation
│   ├── config.yaml              # プロジェクト共通設定
│   ├── dev/                     # 開発環境
│   │   ├── config.yaml          # 開発環境設定
│   │   ├── base.yaml            # 開発環境のbaseスタック設定
│   │   ├── ses.yaml             # 開発環境のsesスタック設定
│   │   ├── monitoring.yaml      # 開発環境のmonitoringスタック設定
│   │   ├── security.yaml        # 開発環境のsecurityスタック設定
│   │   └── README.md            # 開発環境の説明書
│   ├── prod/                    # 本番環境
│   │   ├── config.yaml          # 本番環境設定
│   │   ├── base.yaml            # 本番環境のbaseスタック設定
│   │   ├── ses.yaml             # 本番環境のsesスタック設定
│   │   ├── monitoring.yaml      # 本番環境のmonitoringスタック設定
│   │   ├── security.yaml        # 本番環境のsecurityスタック設定
│   │   └── README.md            # 本番環境の説明書
│   └── templates/               # CloudFormationテンプレート
│       ├── base.yaml            # 基本インフラテンプレート
│       ├── ses.yaml             # SES設定テンプレート
│       ├── monitoring.yaml      # 監視・アラートテンプレート
│       └── security.yaml        # セキュリティ・IAMテンプレート
├── terraform/                    # Terraform
│   ├── main.tf
│   ├── variables.tf
│   └── modules/                  # Terraformモジュール
└── scripts/                      # 運用スクリプト
```

## 📖 ドキュメント一覧

### 設計書
1. **[システム設計書](docs/design/01_システム設計書.md)**
   - 全体システム構成
   - AWSサービス構成
   - 移行計画とコスト見積もり

2. **[ネットワーク構成図](docs/design/02_ネットワーク構成図.md)**
   - 現在の構成とAWS移行後の構成
   - 通信フローとセキュリティ設定

3. **[セキュリティ設計書](docs/design/03_セキュリティ設計書.md)**
   - 脅威分析とセキュリティ対策
   - アクセス制御とデータ保護
   - コンプライアンス対応

4. **[ディレクトリ構造説明書](docs/design/04_ディレクトリ構造説明書.md)**
   - プロジェクト構造の詳細説明
   - 設定ファイルの役割と使用方法
   - 環境別設定の管理方法

### 移行・運用
4. **[移行手順書](docs/migration/01_移行手順書.md)**
   - 段階的移行手順
   - オンプレミス側作業手順
   - ロールバック手順

5. **[監視・アラート設定書](docs/operations/01_監視・アラート設定書.md)**
   - CloudWatch監視設定
   - アラート設定と通知ルール
   - ダッシュボードとレポート設定

## 🚀 デプロイ方法

### 前提条件
- AWS CLI設定済み
- 適切なIAM権限
- Terraform または Sceptre のインストール

### Option 1: Sceptre + CloudFormation

```bash
# Sceptreのインストール
pip install sceptre

# 開発環境の設定確認
cd sceptre/dev
sceptre list

# 開発環境のデプロイ
sceptre launch base
sceptre launch ses
sceptre launch monitoring
sceptre launch security

# 本番環境の設定確認
cd ../prod
sceptre list

# 本番環境のデプロイ
sceptre launch base
sceptre launch ses
sceptre launch monitoring
sceptre launch security
```

### Option 2: Terraform

```bash
# Terraformの初期化
cd terraform
terraform init

# 設定確認
terraform plan

# デプロイ
terraform apply
```

## ⚙️ 設定パラメータ

### 主要パラメータ（仮定値）
- **ドメイン名**: goo.ne.jp
- **送信クォータ**: 5,300,000通/日
- **許可IPレンジ**: 10.0.0.0/8, 192.168.1.0/24
- **ログ保持期間**: 7年（2555日）
- **リージョン**: ap-northeast-1 (Tokyo)

### 実サーバー確認後に変更が必要な項目
- Postfix設定（リレー先、認証方式）
- ネットワーク設定（IPアドレス、ポート）
- 監視項目（閾値、アラート条件）
- セキュリティ設定（IPアドレス範囲）

## 🔧 移行フェーズ

### フェーズ1: 準備・検証（1週間）
- AWS環境構築
- ドメイン検証・DKIM設定
- テスト環境での動作確認

### フェーズ2: 並行運用（2週間）
- 10%トラフィック移行（1台）
- 50%トラフィック移行（6台）
- 監視・アラートの動作確認

### フェーズ3: 完全移行（1週間）
- 残りサーバーの移行（5台）
- 全システムでの動作確認
- 最適化・安定化

## 📊 監視・アラート

### 主要監視項目
- 送信成功率（目標: 99.5%以上）
- 送信レイテンシ（目標: 1分以内）
- エラー率（目標: 0.5%以下）
- バウンス率・苦情率

### アラート条件
- **緊急（P1）**: 送信成功率 < 95%
- **重要（P2）**: 送信レイテンシ > 3分
- **情報（P3）**: エラー率 > 1%

## 🔐 セキュリティ

### アクセス制御
- **Admin権限**: SES設定変更、ユーザー管理
- **ReadOnly権限**: 統計・ログ参照（マスク済み）
- **Monitoring権限**: CloudWatch参照、アラート確認

### データ保護
- **転送時暗号化**: TLS 1.2以上
- **保存時暗号化**: AES-256（S3 SSE-S3）
- **ログ管理**: 7年間保持、IP制限付きアクセス

## 💰 コスト見積もり

### 月額運用コスト（概算）
- **Amazon SES**: $530（5.3M通/月）
- **Amazon Data Firehose**: $50
- **Amazon S3**: $30
- **CloudWatch**: $20
- **合計**: 約$630/月

## 🛠️ トラブルシューティング

### よくある問題と対処法

#### 1. ドメイン検証が失敗する
```bash
# DNS設定を確認
dig TXT _amazonses.goo.ne.jp

# AWS CLIで検証状況確認
aws ses get-identity-verification-attributes --identities goo.ne.jp
```

#### 2. DKIM設定が完了しない
```bash
# DKIM トークンを確認
aws ses get-identity-dkim-attributes --identities goo.ne.jp

# DNS管理チームにCNAMEレコード設定を依頼
```

#### 3. 送信クォータが不足する
```bash
# 現在のクォータを確認
aws ses get-send-quota

# クォータ増加申請をAWSサポートに提出
```

## 📞 サポート・連絡先

### プロジェクトチーム
- **プロジェクトマネージャー**: [担当者名]
- **システムエンジニア**: [担当者名]
- **ネットワークエンジニア**: [担当者名]

### 外部連携
- **DNS管理チーム**: [連絡先]
- **セキュリティチーム**: [連絡先]
- **AWSサポート**: [契約情報]

## 📝 変更履歴

| 版数 | 日付 | 変更内容 | 作成者 |
|------|------|----------|--------|
| 1.0  | 2024年12月 | 初版作成 | システム設計チーム |

## 📄 ライセンス

このプロジェクトは内部利用のみを目的としています。

---

**注意**: 実際の移行作業前に、必ず実サーバーでの設定確認と詳細なテストを実施してください。
