#!/bin/bash

# 未使用テンプレートの検出と削除スクリプト

echo "🗂️ 未使用テンプレート分析レポート"
echo "=================================="

cd "C:/Users/toshimitsu.tomonaga/OneDrive - NTT DOCOMO-OCX/dfs ドキュメント/Projects/AWS_SES_BYODKIM"

# 使用中のテンプレートを抽出
echo "📋 使用中のテンプレート:"
USED_TEMPLATES=$(grep -h "template_path:" sceptre/config/prod/*.yaml | grep -v "^#" | sed 's/.*template_path: *//' | tr -d '"' | sort -u)
echo "$USED_TEMPLATES"

echo ""
echo "📁 存在するテンプレート:"
ALL_TEMPLATES=$(ls sceptre/templates/*.yaml | xargs -n1 basename | sort)
echo "$ALL_TEMPLATES"

echo ""
echo "🗑️ 削除対象の未使用テンプレート:"

# 未使用テンプレートを特定
for template in $ALL_TEMPLATES; do
    if ! echo "$USED_TEMPLATES" | grep -q "^$template$"; then
        echo "- $template"
    fi
done

echo ""
echo "⚠️ 削除する前に確認してください:"
echo "1. base.yaml, monitoring.yaml, security.yaml, ses.yaml は既存システム用"
echo "2. enhanced-kinesis.yaml も既存システム用"
echo "3. ses-byodkim-*.yaml は旧BYODKIM実装（sample統合により不要）"
echo "4. ses-*.yaml の多くは開発中の実験版"

echo ""
echo "🚀 安全に削除可能なファイル:"
SAFE_TO_DELETE="
ses-byodkim-auto.yaml
ses-byodkim-complete.yaml
ses-byodkim-keygen-only.yaml
ses-byodkim-lambda-simple.yaml
ses-byodkim-lambda.yaml
ses-byodkim.yaml
ses-deed.yaml
ses-dev.yaml
ses-easydkim.yaml
ses-simple.yaml
"

for file in $SAFE_TO_DELETE; do
    if [ -f "sceptre/templates/$file" ]; then
        echo "- $file (旧BYODKIM実装・実験版)"
    fi
done
