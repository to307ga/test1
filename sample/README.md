# AWS BYODMIM (Bring Your Own DKIM Migration and Management)

AWS SES BYODKIM（Bring Your Own DKIM）を使用したメール送信システムの移行・管理プロジェクトです。

## プロジェクト概要

このプロジェクトは、オンプレミス環境からAWS SESへのメール送信システム移行において、BYODKIM機能を活用したDKIM証明書の自動管理システムを提供します。

### 主要機能

- **DKIM証明書自動生成・更新**: RSA 2048ビット以上のキーペアを自動生成
- **DNS設定自動化**: CNAMEレコードの生成とDNS管理チームへの通知
- **証明書監視・アラート**: 期限切れ1ヶ月前の自動アラート
- **段階的移行**: 無停止での証明書切り替え
- **セキュリティ強化**: AWS KMSによる暗号化、IAMロールベースのアクセス制御

## 技術スタック

- **Python**: 3.13+
- **AWS Services**: SES, Lambda, KMS, Secrets Manager, S3, CloudWatch, EventBridge
- **Infrastructure as Code**: Sceptre + CloudFormation
- **Package Management**: uv
- **Code Quality**: pre-commit, black, flake8, isort

## プロジェクトルール

### 実行コマンド
- **Python実行**: `uv run python script.py`
- **Sceptre実行**: `uv run sceptre command`
- **変更系コマンド**: `uv run sceptre launch stack-name --yes`
- **参照系コマンド**: `uv run sceptre list stacks` (--yesなし)

### ファイル言語
- **コードファイル** (.py, .yaml, .json, .toml, .tf, .sh, .ps1): 英語のみ
- **ドキュメントファイル** (.md, .txt): 日本語使用可能

### 文字コード
- **文字コード**: UTF-8
- **改行コード**: LF (Unix形式)
- **BOM**: なし

詳細は [プロジェクトルール.md](プロジェクトルール.md) を参照してください。

## セットアップ

### 1. 前提条件

- Python 3.13+
- uv (Python package manager)
- AWS CLI設定済み
- Git

### 2. プロジェクトクローン

```bash
git clone <repository-url>
cd AWS_BYODMIM
```

### 3. 依存関係インストール

```bash
# 開発用依存関係も含めてインストール
uv sync --dev

# または個別にインストール
uv add boto3 click pyyaml sceptre
uv add --dev pre-commit black flake8 isort pytest pytest-cov
```

### 4. 開発環境セットアップ

```bash
# pre-commitフックのセットアップ
uv run python scripts/setup_hooks.py

# または手動でセットアップ
uv run pre-commit install
uv run pre-commit run --all-files
```

## 使用方法

### 1. 設定ファイルの準備

```bash
# Sceptre設定ディレクトリの作成
mkdir -p config/production
mkdir -p config/staging

# 設定ファイルのコピー（例）
cp templates/sceptre-config.yaml config/production/
```

### 2. CloudFormationスタックのデプロイ

```bash
# スタック一覧の確認
uv run sceptre list stacks

# スタックのデプロイ
uv run sceptre launch dkim-manager --yes

# スタックの状態確認
uv run sceptre describe dkim-manager
```

### 3. DKIM証明書の管理

```bash
# DKIM証明書の生成
uv run python scripts/generate_dkim_certificate.py

# 証明書の状態確認
uv run python scripts/check_dkim_status.py

# 証明書の更新
uv run python scripts/rotate_dkim_certificate.py
```

## プロジェクト構造

```
AWS_BYODMIM/
├── README.md                          # プロジェクト概要
├── プロジェクトルール.md                # プロジェクトルール
├── pyproject.toml                     # プロジェクト設定
├── .editorconfig                      # エディタ設定
├── pre-commit-config.yaml             # pre-commit設定
├── main.py                           # メインエントリーポイント
├── scripts/                          # ユーティリティスクリプト
│   ├── check_japanese.py             # 日本語チェック
│   ├── check_sceptre_commands.py     # Sceptreコマンドチェック
│   └── setup_hooks.py                # フックセットアップ
├── config/                           # Sceptre設定
│   ├── production/                   # 本番環境設定
│   └── staging/                      # ステージング環境設定
├── templates/                        # CloudFormationテンプレート
│   ├── dkim-manager.yaml             # DKIM管理Lambda
│   ├── kms-keys.yaml                 # KMS暗号化キー
│   └── monitoring.yaml               # 監視・アラート
├── lambda/                           # Lambda関数
│   ├── dkim_manager/                 # DKIM管理関数
│   ├── dns_notifier/                 # DNS通知関数
│   └── certificate_monitor/          # 証明書監視関数
└── docs/                            # ドキュメント
    ├── システム設計書.md
    ├── CloudFormationテンプレート設計書.md
    ├── セキュリティ設計書.md
    ├── DKIM証明書自動化設計書.md
    ├── 監視・アラート設計書.md
    ├── Sceptreデプロイメントガイド.md
    └── 運用ガイド.md
```

## 開発ガイド

### コード品質チェック

```bash
# 全ファイルのチェック
uv run pre-commit run --all-files

# 個別チェック
uv run black --check .
uv run flake8 .
uv run isort --check-only .
```

### テスト実行

```bash
# 全テスト実行
uv run pytest

# カバレッジ付きテスト
uv run pytest --cov=aws_byodmim

# 特定のテスト実行
uv run pytest tests/test_dkim_manager.py
```

### 新機能開発

1. フィーチャーブランチの作成
2. プロジェクトルールに従ってコード作成
3. テストの追加
4. pre-commitチェックの実行
5. プルリクエストの作成

## デプロイメント

### 本番環境

```bash
# 本番環境へのデプロイ
uv run sceptre launch dkim-manager --config-dir config/production --yes

# デプロイメント確認
uv run sceptre describe dkim-manager --config-dir config/production
```

### ステージング環境

```bash
# ステージング環境へのデプロイ
uv run sceptre launch dkim-manager --config-dir config/staging --yes

# デプロイメント確認
uv run sceptre describe dkim-manager --config-dir config/staging
```

## 監視・運用

### ログ確認

```bash
# CloudWatchログの確認
uv run python scripts/check_logs.py

# エラーログの確認
uv run python scripts/check_errors.py
```

### メトリクス確認

```bash
# DKIM署名成功率の確認
uv run python scripts/check_dkim_metrics.py

# 送信統計の確認
uv run python scripts/check_sending_stats.py
```

## トラブルシューティング

### よくある問題

1. **DKIM署名失敗**
   - DNS設定の確認
   - 証明書の有効性確認
   - SES設定の確認

2. **証明書更新失敗**
   - KMSキーのアクセス権限確認
   - Secrets Managerの設定確認
   - Lambda関数の実行ログ確認

3. **DNS通知失敗**
   - SNS設定の確認
   - メール配信設定の確認
   - 通知先の確認

### ログの確認方法

```bash
# Lambda関数のログ確認
uv run python scripts/check_lambda_logs.py --function-name dkim-manager

# CloudWatchアラームの確認
uv run python scripts/check_alarms.py
```

## コントリビューション

1. プロジェクトをフォーク
2. フィーチャーブランチを作成
3. プロジェクトルールに従って変更
4. テストを追加・実行
5. プルリクエストを作成

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。

## サポート

問題や質問がある場合は、GitHubのIssuesページで報告してください。

---

**注意**: このプロジェクトは、AWS SES BYODKIM機能を使用しており、適切なAWS権限とDNS設定が必要です。本番環境での使用前に、必ずテスト環境で動作確認を行ってください。
