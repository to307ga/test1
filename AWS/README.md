# Jenkins バックアップ復元ツール

このディレクトリには、Jenkins バックアップからの復元に必要なスクリプトが含まれています。

## ファイル構成

### 🔧 メインツール
- `jenkins_sync_manager.sh` - **統合管理スクリプト（メイン）**
- `jenkins_quick_tools.sh` - **クイック管理ツール（推奨開始点）**
- `jenkins_cli_helper.sh` - CLI/REST APIヘルパー

### ⚙️ 個別同期スクリプト
- `jenkins_sync_analysis.sh` - バックアップ内容の分析
- `jenkins_sync_jobs.sh` - ジョブの同期（curl/REST API）
- `jenkins_sync_users.sh` - ユーザーの同期（API + ブラウザ手順）
- `jenkins_sync_config.sh` - 設定の同期（安全チェック付き）

## 🚀 使用方法

### ステップ1: 事前準備
```bash
# AWS MFA認証
./get_mfa_token.sh

# Jenkins SSMトンネル確立
./AWS_POC/poc/scripts/connect-jenkins.sh
```

### ステップ2: ツール起動（推奨順序）
```bash
# 1. クイック管理ツール（状況確認）
./jenkins_quick_tools.sh

# 2. 統合管理スクリプト（メイン復元作業）
./jenkins_sync_manager.sh

# 3. CLI/APIヘルパー（詳細操作）
./jenkins_cli_helper.sh
```

### ステップ3: 復元手順
1. **バックアップ分析** - 復元対象の確認
2. **ジョブ同期** - config.xml ベースでジョブ復元
3. **ユーザー同期** - API + ブラウザ手順でユーザー復元
4. **設定同期** - 安全な設定ファイル復元

## 🌐 ブラウザレス環境対応

このツールセットは **ブラウザレス環境** に最適化されています：

### ✅ curl/REST API 中心
- ジョブ作成・更新・削除
- システム情報取得
- プラグイン管理
- ノード管理

### 🔄 ハイブリッドアプローチ
- **自動化可能**: curl/Jenkins CLI で実行
- **手動対応**: 別環境のブラウザで補完手順提供

### 🛡️ 安全性重視
- 「既存を残しつつ同期」アプローチ
- 設定変更前の確認機能
- ロールバック用の現在設定保存

## 📊 機能一覧

### jenkins_quick_tools.sh
- ✅ Jenkins状態確認
- 📊 バックアップ vs 現在の比較
- 📋 ジョブ詳細取得
- ⚙️ 設定XML取得

### jenkins_sync_manager.sh
- 🔍 バックアップ分析
- 🔄 段階的ジョブ同期
- 👥 ユーザー管理（API+ブラウザ）
- ⚙️ 設定同期（安全チェック）

### jenkins_cli_helper.sh
- 📈 システム詳細情報
- 📦 プラグイン管理
- 🖥️ ノード管理
- 🧪 ジョブ作成テスト

## ⚠️ 注意事項

### 環境要件
- ✅ SSMトンネル必須（ポート9090）
- ✅ AWS MFA認証必須
- ✅ curl利用可能
- ⚠️ ブラウザアクセス不要（別環境推奨）

### 安全性
- 🛡️ 既存Jenkins設定を保護
- 📝 変更前の設定保存
- 🔄 段階的復元（強制上書きなし）
- ⚠️ 復元前バックアップ推奨

### トラブルシューティング
- SSMトンネル接続確認
- Jenkins認証情報確認
- REST API応答確認
- ログファイル確認

## 🔗 関連ファイル

- `jenkins-backup-2025-10-28.tar.gz` - 元バックアップファイル
- `jenkins-backup-extracted/` - 展開済みバックアップ
- `/tmp/jenkins-cli.jar` - 自動ダウンロード済みCLI
