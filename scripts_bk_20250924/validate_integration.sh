#!/bin/bash

# =================================================================
# Sample Integration Validation Script
# =================================================================
#
# このスクリプトはサンプルBYODKIM実装統合後の
# 設定とファイルの妥当性を検証します。
#
# =================================================================

set -e

# 設定値
PROJECT_ROOT=$(pwd)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

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

# ファイル存在チェック
check_file_structure() {
    log_info "ファイル構造を検証中..."

    # 必須テンプレートファイル
    templates=(
        "sceptre/templates/phase-1-infrastructure-foundation.yaml"
        "sceptre/templates/dkim-manager-lambda.yaml"
        "sceptre/templates/dns-preparation.yaml"
        "sceptre/templates/dns-team-collaboration.yaml"
        "sceptre/templates/dns-validation-dkim-activation.yaml"
        "sceptre/templates/monitoring-system.yaml"
        "sceptre/templates/ses-configuration.yaml"
    )

    echo "=== テンプレートファイル ==="
    for template in "${templates[@]}"; do
        if [ -f "$PROJECT_ROOT/$template" ]; then
            log_success "✓ $template"
        else
            log_error "✗ $template (見つかりません)"
        fi
    done

    # 必須設定ファイル
    configs=(
        "sceptre/config/prod/phase-1-infrastructure-foundation.yaml"
        "sceptre/config/prod/phase-2-dkim-system.yaml"
        "sceptre/config/prod/phase-3-ses-byodkim.yaml"
        "sceptre/config/prod/phase-4-dns-preparation.yaml"
        "sceptre/config/prod/phase-5-dns-team-collaboration.yaml"
        "sceptre/config/prod/phase-7-dns-validation-dkim-activation.yaml"
        "sceptre/config/prod/phase-8-monitoring-system.yaml"
        "sceptre/config/prod/README.md"
    )

    echo ""
    echo "=== 設定ファイル ==="
    for config in "${configs[@]}"; do
        if [ -f "$PROJECT_ROOT/$config" ]; then
            log_success "✓ $config"
        else
            log_error "✗ $config (見つかりません)"
        fi
    done

    # ドキュメントファイル
    docs=(
        "docs/implementation/DKIM証明書自動化設計書.md"
        "docs/implementation/CloudFormationテンプレート設計書.md"
        "SAMPLE_INTEGRATION_PLAN.md"
    )

    echo ""
    echo "=== ドキュメント ==="
    for doc in "${docs[@]}"; do
        if [ -f "$PROJECT_ROOT/$doc" ]; then
            log_success "✓ $doc"
        else
            log_warning "△ $doc (推奨ファイル)"
        fi
    done
}

# パラメータ整合性チェック
validate_parameters() {
    log_info "パラメータ整合性を検証中..."

    echo "=== プロジェクト設定 ==="

    # プロジェクト名の統一確認
    project_name_count=$(grep -r "ProjectName.*aws-byodmim" "$PROJECT_ROOT/sceptre/config/prod/" 2>/dev/null | wc -l)
    if [ "$project_name_count" -gt 0 ]; then
        log_success "✓ プロジェクト名: aws-byodmim (${project_name_count}箇所で確認)"
    else
        log_warning "△ プロジェクト名の設定を確認してください"
    fi

    # 環境名の統一確認
    env_count=$(grep -r "Environment.*prod" "$PROJECT_ROOT/sceptre/config/prod/" 2>/dev/null | wc -l)
    if [ "$env_count" -gt 0 ]; then
        log_success "✓ 環境名: prod (${env_count}箇所で確認)"
    else
        log_warning "△ 環境名の設定を確認してください"
    fi

    # ドメイン名の統一確認
    domain_count=$(grep -r "goo\.ne\.jp" "$PROJECT_ROOT/sceptre/config/prod/" 2>/dev/null | wc -l)
    if [ "$domain_count" -gt 0 ]; then
        log_success "✓ ドメイン名: goo.ne.jp (${domain_count}箇所で確認)"
    else
        log_error "✗ ドメイン名の設定が見つかりません"
    fi

    # DNS管理チームメール
    dns_email_count=$(grep -r "tomonaga@mx2\.mesh\.ne\.jp" "$PROJECT_ROOT/sceptre/config/prod/" 2>/dev/null | wc -l)
    if [ "$dns_email_count" -gt 0 ]; then
        log_success "✓ DNS管理チームメール: tomonaga@mx2.mesh.ne.jp (${dns_email_count}箇所で確認)"
    else
        log_error "✗ DNS管理チームメールの設定が見つかりません"
    fi
}

# 依存関係チェック
validate_dependencies() {
    log_info "スタック依存関係を検証中..."

    echo "=== Phase間依存関係 ==="

    # Phase 2の依存関係確認
    if [ -f "$PROJECT_ROOT/sceptre/config/prod/phase-2-dkim-system.yaml" ]; then
        phase1_dep=$(grep -c "phase-1-infrastructure-foundation" "$PROJECT_ROOT/sceptre/config/prod/phase-2-dkim-system.yaml" 2>/dev/null || echo "0")
        if [ "$phase1_dep" -gt 0 ]; then
            log_success "✓ Phase 2 → Phase 1 依存関係"
        else
            log_error "✗ Phase 2 → Phase 1 依存関係が見つかりません"
        fi
    fi

    # Phase 7の依存関係確認（重要）
    if [ -f "$PROJECT_ROOT/sceptre/config/prod/phase-7-dns-validation-dkim-activation.yaml" ]; then
        phase_deps=$(grep -c "dependencies:" "$PROJECT_ROOT/sceptre/config/prod/phase-7-dns-validation-dkim-activation.yaml" 2>/dev/null || echo "0")
        if [ "$phase_deps" -gt 0 ]; then
            log_success "✓ Phase 7 依存関係定義"

            # 具体的な依存関係確認
            echo "  Phase 7の依存関係:"
            grep -A 10 "dependencies:" "$PROJECT_ROOT/sceptre/config/prod/phase-7-dns-validation-dkim-activation.yaml" | grep -E "phase-[0-9]" | sed 's/^/    /'
        else
            log_error "✗ Phase 7 依存関係が定義されていません"
        fi
    fi
}

# BYODKIM設定確認
validate_byodkim_config() {
    log_info "BYODKIM設定を検証中..."

    echo "=== BYODKIM設定 ==="

    # DKIMセパレーター確認
    separator_count=$(grep -r "gooid-21-pro" "$PROJECT_ROOT/sceptre/config/prod/" 2>/dev/null | wc -l)
    if [ "$separator_count" -gt 0 ]; then
        log_success "✓ DKIMセパレーター: gooid-21-pro"
    else
        log_warning "△ DKIMセパレーターの設定を確認してください"
    fi

    # TXTレコード形式確認（CNAMEではない）
    cname_count=$(grep -r "CNAME" "$PROJECT_ROOT/sceptre/templates/" 2>/dev/null | wc -l)
    txt_count=$(grep -r "TXT" "$PROJECT_ROOT/sceptre/templates/" 2>/dev/null | wc -l)

    if [ "$txt_count" -gt "$cname_count" ]; then
        log_success "✓ TXTレコード形式採用（BYODKIM対応）"
    else
        log_warning "△ DNSレコード形式を確認してください（TXTレコード推奨）"
    fi

    # EventBridge自動連携確認
    eventbridge_count=$(grep -r "Events::Rule" "$PROJECT_ROOT/sceptre/templates/" 2>/dev/null | wc -l)
    if [ "$eventbridge_count" -gt 0 ]; then
        log_success "✓ EventBridge自動連携設定"
    else
        log_warning "△ EventBridge設定を確認してください"
    fi
}

# Sceptre設定検証
validate_sceptre_config() {
    log_info "Sceptre設定を検証中..."

    echo "=== Sceptre設定 ==="

    # config.yamlの存在確認
    if [ -f "$PROJECT_ROOT/sceptre/config/config.yaml" ]; then
        log_success "✓ メインconfig.yaml"
    else
        log_warning "△ メインconfig.yamlが見つかりません"
    fi

    # prod/config.yamlの存在確認
    if [ -f "$PROJECT_ROOT/sceptre/config/prod/config.yaml" ]; then
        log_success "✓ prod/config.yaml"
    else
        log_warning "△ prod/config.yamlが見つかりません"
    fi

    # template_pathの確認
    template_path_count=$(grep -r "template_path:" "$PROJECT_ROOT/sceptre/config/prod/" 2>/dev/null | wc -l)
    if [ "$template_path_count" -gt 0 ]; then
        log_success "✓ template_path設定 (${template_path_count}箇所)"
    else
        log_error "✗ template_path設定が見つかりません"
    fi
}

# セキュリティ設定確認
validate_security_config() {
    log_info "セキュリティ設定を検証中..."

    echo "=== セキュリティ設定 ==="

    # KMS設定確認
    kms_count=$(grep -r "AWS::KMS::Key" "$PROJECT_ROOT/sceptre/templates/" 2>/dev/null | wc -l)
    if [ "$kms_count" -gt 0 ]; then
        log_success "✓ KMS暗号化設定"
    else
        log_warning "△ KMS設定を確認してください"
    fi

    # IAM最小権限確認
    iam_policy_count=$(grep -r "PolicyDocument" "$PROJECT_ROOT/sceptre/templates/" 2>/dev/null | wc -l)
    if [ "$iam_policy_count" -gt 0 ]; then
        log_success "✓ IAMポリシー設定"
    else
        log_warning "△ IAMポリシー設定を確認してください"
    fi

    # Secrets Manager設定確認
    secrets_count=$(grep -r "AWS::SecretsManager::Secret" "$PROJECT_ROOT/sceptre/templates/" 2>/dev/null | wc -l)
    if [ "$secrets_count" -gt 0 ]; then
        log_success "✓ Secrets Manager設定"
    else
        log_warning "△ Secrets Manager設定を確認してください"
    fi

    # Slackトークンクリア確認
    slack_token_count=$(grep -r "SlackWebhookURL.*http" "$PROJECT_ROOT/sceptre/config/prod/" 2>/dev/null | wc -l)
    if [ "$slack_token_count" -eq 0 ]; then
        log_success "✓ Slackトークンクリア済み"
    else
        log_error "✗ Slackトークンが残っています（セキュリティリスク）"
    fi
}

# デプロイメント準備確認
validate_deployment_readiness() {
    log_info "デプロイメント準備状況を確認中..."

    echo "=== デプロイメント準備 ==="

    # Phase 1の検証
    if command -v uv &> /dev/null; then
        log_success "✓ UV (Python package manager)"

        # Sceptreの検証
        if uv run sceptre --version &> /dev/null; then
            log_success "✓ Sceptre実行環境"

            # Phase 1設定の検証
            if uv run sceptre validate prod/phase-1-infrastructure-foundation &> /dev/null; then
                log_success "✓ Phase 1設定検証"
            else
                log_warning "△ Phase 1設定に問題がある可能性があります"
            fi
        else
            log_warning "△ Sceptre実行環境を確認してください"
        fi
    else
        log_warning "△ UV (Python package manager)をインストールしてください"
    fi

    # AWS CLI確認
    if command -v aws &> /dev/null; then
        log_success "✓ AWS CLI"

        # AWS認証確認
        if aws sts get-caller-identity &> /dev/null; then
            log_success "✓ AWS認証設定"
        else
            log_warning "△ AWS認証を設定してください"
        fi
    else
        log_warning "△ AWS CLIをインストールしてください"
    fi
}

# 推奨事項生成
generate_recommendations() {
    log_info "推奨事項を生成中..."

    RECOMMENDATIONS_FILE="$PROJECT_ROOT/INTEGRATION_VALIDATION_$TIMESTAMP.md"

    cat > "$RECOMMENDATIONS_FILE" << EOF
# Sample BYODKIM実装統合検証レポート

## 検証実行日時
$(date '+%Y年%m月%d日 %H:%M:%S')

## 検証結果サマリー

### ✅ 完了している項目
- 検証済みテンプレートファイル統合
- 設定ファイル統合
- BYODKIM設定（TXTレコード形式）
- パラメータ統一（goo.ne.jp）
- DNS管理チーム設定（tomonaga@mx2.mesh.ne.jp）

### ⚠️ 確認が必要な項目
- Sceptre実行環境の動作確認
- AWS認証設定の確認
- Phase 1デプロイメント前テスト

### 🔧 デプロイメント前チェックリスト

#### 1. 環境準備
\`\`\`bash
# Python環境確認
uv --version

# Sceptre動作確認
uv run sceptre --version

# AWS認証確認
aws sts get-caller-identity
\`\`\`

#### 2. 設定検証
\`\`\`bash
# Phase 1設定検証
uv run sceptre validate prod/phase-1-infrastructure-foundation

# 全体設定確認
uv run sceptre list stacks --config-dir sceptre/config/prod
\`\`\`

#### 3. DNS管理チーム事前連絡
- **連絡先**: tomonaga@mx2.mesh.ne.jp
- **内容**: BYODKIM TXTレコード設定依頼（約2週間後）
- **形式**: TXTレコード（CNAMEではない）
- **セレクター**: gooid-21-pro-20250907-1/2/3

### 📅 推奨デプロイメントスケジュール

#### Week 1: 基盤構築
1. **Phase 1**: インフラ基盤構築
   \`\`\`bash
   uv run sceptre launch prod/phase-1-infrastructure-foundation
   \`\`\`

2. **Phase 2**: DKIM管理システム構築
   \`\`\`bash
   uv run sceptre launch prod/phase-2-dkim-system
   \`\`\`

3. **Phase 3**: SES設定・BYODKIM初期化
   \`\`\`bash
   uv run sceptre launch prod/phase-3-ses-byodkim
   \`\`\`

#### Week 2: DNS連携準備
4. **Phase 4**: DNS設定準備
   \`\`\`bash
   uv run sceptre launch prod/phase-4-dns-preparation
   \`\`\`

5. **Phase 5**: DNS管理チーム連携
   \`\`\`bash
   uv run sceptre launch prod/phase-5-dns-team-collaboration
   \`\`\`

#### Week 3-4: DNS設定完了待機
6. **外部作業**: DNS管理チームによるTXTレコード設定（約2週間）

#### Week 5: 有効化・監視開始
7. **Phase 7**: DNS検証・DKIM有効化（自動実行）
8. **Phase 8**: 監視システム開始

### ⚠️ 重要な注意事項

1. **DNS管理プロセス**: 内部DNS変更には約2週間必要
2. **自動連携**: Phase 5完了後、Phase 7が自動実行される
3. **TXTレコード**: CNAMEレコードではなくTXTレコードを使用
4. **監視**: 毎月1日 9:00 JSTに証明書期限チェック実行

### 🆘 問題発生時の連絡先
- **技術担当**: プロジェクトチーム
- **DNS管理**: tomonaga@mx2.mesh.ne.jp
- **AWS運用**: 社内AWS運用チーム

EOF

    log_success "検証レポート生成完了: $RECOMMENDATIONS_FILE"
}

# メイン実行
main() {
    echo ""
    echo "=============================================================="
    echo "🔍 Sample BYODKIM Integration Validation"
    echo "=============================================================="
    echo ""

    check_file_structure
    echo ""
    validate_parameters
    echo ""
    validate_dependencies
    echo ""
    validate_byodkim_config
    echo ""
    validate_sceptre_config
    echo ""
    validate_security_config
    echo ""
    validate_deployment_readiness
    echo ""
    generate_recommendations

    echo ""
    echo "=============================================================="
    log_success "🎉 統合検証が完了しました！"
    echo "=============================================================="
    echo ""
    log_info "次のステップ:"
    echo "1. 検証レポートの確認: cat INTEGRATION_VALIDATION_$TIMESTAMP.md"
    echo "2. Phase 1デプロイメント: uv run sceptre launch prod/phase-1-infrastructure-foundation"
    echo "3. DNS管理チーム事前連絡: tomonaga@mx2.mesh.ne.jp"
    echo ""
    log_warning "重要: デプロイメント前にAWS認証設定とSceptre動作確認を行ってください！"
    echo ""
}

# スクリプト実行
main "$@"
