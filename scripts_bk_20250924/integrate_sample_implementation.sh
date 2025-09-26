#!/bin/bash

# =================================================================
# Sample BYODKIM Implementation Integration Script
# =================================================================
#
# このスクリプトは検証済みのサンプルBYODKIM実装を
# 現在のプロジェクトに統合するためのものです。
#
# 実行前要件:
# 1. 現在の設定のバックアップ作成済み
# 2. サンプルディレクトリが存在する
# 3. 適切な権限でスクリプトを実行
#
# =================================================================

set -e  # エラー時に実行を停止

# 設定値
PROJECT_ROOT=$(pwd)
SAMPLE_DIR="$PROJECT_ROOT/sample"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$PROJECT_ROOT/sceptre_backup_$TIMESTAMP"

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ機能
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 事前チェック
check_prerequisites() {
    log_info "事前チェックを開始..."

    # サンプルディレクトリの存在確認
    if [ ! -d "$SAMPLE_DIR" ]; then
        log_error "サンプルディレクトリが見つかりません: $SAMPLE_DIR"
        exit 1
    fi

    # 必要なディレクトリの存在確認
    if [ ! -d "$PROJECT_ROOT/sceptre" ]; then
        log_error "sceptreディレクトリが見つかりません"
        exit 1
    fi

    # 現在のディレクトリがプロジェクトルートか確認
    if [ ! -f "pyproject.toml" ] || [ ! -f "README.md" ]; then
        log_warning "プロジェクトルートディレクトリで実行してください"
    fi

    log_success "事前チェック完了"
}

# バックアップ作成
create_backup() {
    log_info "現在の設定をバックアップ中..."

    if [ -d "$PROJECT_ROOT/sceptre" ]; then
        cp -r "$PROJECT_ROOT/sceptre" "$BACKUP_DIR"
        log_success "バックアップ作成完了: $BACKUP_DIR"
    else
        log_warning "sceptreディレクトリが存在しないため、バックアップはスキップ"
    fi
}

# テンプレートファイル統合
integrate_templates() {
    log_info "検証済みテンプレートを統合中..."

    # テンプレートディレクトリ作成
    mkdir -p "$PROJECT_ROOT/sceptre/templates"

    # サンプルテンプレートをコピー
    if [ -d "$SAMPLE_DIR/sceptre/templates" ]; then
        cp -f "$SAMPLE_DIR/sceptre/templates"/* "$PROJECT_ROOT/sceptre/templates/"
        log_success "テンプレートファイル統合完了"

        # コピーされたファイルリスト表示
        log_info "統合されたテンプレート:"
        ls -la "$PROJECT_ROOT/sceptre/templates/"
    else
        log_error "サンプルテンプレートディレクトリが見つかりません"
        exit 1
    fi
}

# 設定ファイル統合
integrate_config() {
    log_info "設定ファイルを統合中..."

    # 設定ディレクトリ作成
    mkdir -p "$PROJECT_ROOT/sceptre/config/prod"
    mkdir -p "$PROJECT_ROOT/sceptre/config/dev"

    # サンプル設定ファイルをコピー
    if [ -d "$SAMPLE_DIR/sceptre/config/prod" ]; then
        cp -f "$SAMPLE_DIR/sceptre/config/prod"/* "$PROJECT_ROOT/sceptre/config/prod/"
        log_success "本番環境設定ファイル統合完了"

        # コピーされたファイルリスト表示
        log_info "統合された設定ファイル:"
        ls -la "$PROJECT_ROOT/sceptre/config/prod/"
    else
        log_error "サンプル設定ディレクトリが見つかりません"
        exit 1
    fi
}

# ドキュメント統合
integrate_documentation() {
    log_info "ドキュメントを統合中..."

    # ドキュメントディレクトリ作成
    mkdir -p "$PROJECT_ROOT/docs/implementation"

    # サンプルドキュメントをコピー
    if [ -f "$SAMPLE_DIR/DKIM証明書自動化設計書.md" ]; then
        cp "$SAMPLE_DIR/DKIM証明書自動化設計書.md" "$PROJECT_ROOT/docs/implementation/"
        log_success "DKIM証明書自動化設計書統合完了"
    fi

    if [ -f "$SAMPLE_DIR/CloudFormationテンプレート設計書.md" ]; then
        cp "$SAMPLE_DIR/CloudFormationテンプレート設計書.md" "$PROJECT_ROOT/docs/implementation/"
        log_success "CloudFormationテンプレート設計書統合完了"
    fi

    # READMEファイルがあれば統合
    if [ -f "$SAMPLE_DIR/sceptre/config/prod/README.md" ]; then
        cp "$SAMPLE_DIR/sceptre/config/prod/README.md" "$PROJECT_ROOT/docs/implementation/BYODKIM運用ガイド.md"
        log_success "運用ガイド統合完了"
    fi
}

# パラメータ調整
adjust_parameters() {
    log_info "パラメータを調整中..."

    # DNS管理チームメールアドレス更新
    log_info "DNS管理チームメールアドレスを更新..."
    find "$PROJECT_ROOT/sceptre/config/prod" -name "*.yaml" -type f -exec sed -i.bak 's/dns-team@goo\.ne\.jp/tomonaga@mx2.mesh.ne.jp/g' {} \;

    # Slackトークン削除（セキュリティ対策）
    log_info "Slack設定をクリア..."
    find "$PROJECT_ROOT/sceptre/config/prod" -name "*.yaml" -type f -exec sed -i.bak 's/SlackWebhookURL: ".*"/SlackWebhookURL: ""/g' {} \;

    # バックアップファイル削除
    find "$PROJECT_ROOT/sceptre/config/prod" -name "*.bak" -delete

    log_success "パラメータ調整完了"
}

# 統合後検証
verify_integration() {
    log_info "統合結果を検証中..."

    # 必要なファイルの存在確認
    required_files=(
        "sceptre/templates/phase-1-infrastructure-foundation.yaml"
        "sceptre/templates/dkim-manager-lambda.yaml"
        "sceptre/config/prod/phase-1-infrastructure-foundation.yaml"
        "sceptre/config/prod/phase-2-dkim-system.yaml"
        "sceptre/config/prod/README.md"
    )

    for file in "${required_files[@]}"; do
        if [ -f "$PROJECT_ROOT/$file" ]; then
            log_success "✓ $file"
        else
            log_error "✗ $file (見つかりません)"
        fi
    done

    # パラメータ確認
    log_info "重要パラメータ確認:"
    echo "--- Domain Configuration ---"
    grep -r "goo\.ne\.jp" "$PROJECT_ROOT/sceptre/config/prod/" | head -5
    echo "--- Project Configuration ---"
    grep -r "aws-byodmim" "$PROJECT_ROOT/sceptre/config/prod/" | head -5
    echo "--- DNS Team Configuration ---"
    grep -r "tomonaga@mx2.mesh.ne.jp" "$PROJECT_ROOT/sceptre/config/prod/" | head -3
}

# 統合サマリー生成
generate_summary() {
    log_info "統合サマリーを生成中..."

    SUMMARY_FILE="$PROJECT_ROOT/INTEGRATION_SUMMARY_$TIMESTAMP.md"

    cat > "$SUMMARY_FILE" << EOF
# Sample BYODKIM実装統合サマリー

## 統合実行日時
$(date '+%Y年%m月%d日 %H:%M:%S')

## 統合内容

### 1. テンプレートファイル
$(ls -la "$PROJECT_ROOT/sceptre/templates/" | grep -E "\\.yaml$" | wc -l) 個のテンプレートファイルを統合

### 2. 設定ファイル
$(ls -la "$PROJECT_ROOT/sceptre/config/prod/" | grep -E "\\.yaml$" | wc -l) 個の設定ファイルを統合

### 3. ドキュメント
- DKIM証明書自動化設計書
- CloudFormationテンプレート設計書
- BYODKIM運用ガイド

### 4. バックアップ
元の設定は以下に保存: $BACKUP_DIR

## 次のステップ

### 1. 設定確認
\`\`\`bash
# 統合された設定の確認
cd $PROJECT_ROOT
find sceptre/config/prod -name "*.yaml" -exec echo "=== {} ===" \\; -exec head -20 {} \\;
\`\`\`

### 2. Phase 1デプロイメント準備
\`\`\`bash
# Phase 1の依存関係チェック
uv run sceptre validate prod/phase-1-infrastructure-foundation

# Phase 1実行（準備完了後）
uv run sceptre launch prod/phase-1-infrastructure-foundation
\`\`\`

### 3. 段階的デプロイメント
1. Phase 1: インフラ基盤構築
2. Phase 2: DKIM管理システム構築
3. Phase 3: SES設定・BYODKIM初期化
4. Phase 4-8: DNS準備〜監視開始

## 重要事項
- DNS管理チーム連絡先: tomonaga@mx2.mesh.ne.jp
- BYODKIM形式: TXTレコード（CNAMEではない）
- 自動連携: Phase 5→7（EventBridge）
- 監視スケジュール: 毎月1日 9:00 JST

EOF

    log_success "統合サマリー生成完了: $SUMMARY_FILE"
}

# メイン実行
main() {
    echo ""
    echo "=============================================================="
    echo "🚀 Sample BYODKIM Implementation Integration"
    echo "=============================================================="
    echo ""

    check_prerequisites

    echo ""
    log_info "統合を開始します..."

    create_backup
    integrate_templates
    integrate_config
    integrate_documentation
    adjust_parameters
    verify_integration
    generate_summary

    echo ""
    echo "=============================================================="
    log_success "🎉 Sample BYODKIM実装統合が完了しました！"
    echo "=============================================================="
    echo ""
    log_info "次のステップ:"
    echo "1. 統合サマリーの確認: cat INTEGRATION_SUMMARY_$TIMESTAMP.md"
    echo "2. 設定ファイルの確認: ls -la sceptre/config/prod/"
    echo "3. Phase 1デプロイメント準備: uv run sceptre validate prod/phase-1-infrastructure-foundation"
    echo ""
    log_warning "重要: DNS管理チーム（tomonaga@mx2.mesh.ne.jp）への事前連絡を忘れずに！"
    echo ""
}

# スクリプト実行
main "$@"
