#!/bin/bash

# 全体的な依存関係とスタック名一貫性の分析スクリプト

echo "# 📊 完全依存関係分析レポート"
echo "生成日時: $(date)"
echo ""

cd "C:/Users/toshimitsu.tomonaga/OneDrive - NTT DOCOMO-OCX/dfs ドキュメント/Projects/AWS_SES_BYODKIM/sceptre/config/prod"

echo "## 🏗️ スタック構成一覧"
echo "| ファイル名 | スタック名（推定） | 用途 |"
echo "|---|---|---|"

for file in *.yaml; do
    if [ "$file" != "config.yaml" ] && [ "$file" != "README.md" ]; then
        stack_name=$(echo "$file" | sed 's/\.yaml$//')
        template_path=$(grep "template_path:" "$file" 2>/dev/null | sed 's/.*template_path: *//' | tr -d '"')
        echo "| $file | prod/$stack_name | $template_path |"
    fi
done

echo ""
echo "## 🔗 依存関係マップ"
echo ""

for file in *.yaml; do
    if [ "$file" != "config.yaml" ] && [ "$file" != "README.md" ]; then
        echo "### 📋 $file"

        # 依存関係抽出
        if grep -q "dependencies:" "$file" 2>/dev/null; then
            echo "**Dependencies:**"
            grep -A 10 "dependencies:" "$file" | grep -E "^\s*-" | sed 's/^\s*- */- /'
        else
            echo "**Dependencies:** なし"
        fi

        # stack_output参照抽出
        stack_outputs=$(grep "stack_output" "$file" 2>/dev/null | wc -l)
        if [ "$stack_outputs" -gt 0 ]; then
            echo ""
            echo "**Stack Output参照 ($stack_outputs 個):**"
            grep "stack_output" "$file" | sed 's/.*stack_output */- /' | sed 's/::.*$//' | sort -u
        fi

        echo ""
    fi
done

echo "## 📈 ProjectCode/ProjectName 一貫性チェック"
echo ""

echo "| ファイル | ProjectCode | ProjectName |"
echo "|---|---|---|"

for file in *.yaml; do
    if [ "$file" != "config.yaml" ] && [ "$file" != "README.md" ]; then
        project_code=$(grep "ProjectCode:" "$file" 2>/dev/null | sed 's/.*ProjectCode: *//' | tr -d '"')
        project_name=$(grep "ProjectName:" "$file" 2>/dev/null | sed 's/.*ProjectName: *//' | tr -d '"' | head -1)
        echo "| $file | $project_code | $project_name |"
    fi
done

echo ""
echo "## 🚨 検出された問題"
echo ""

# 重複するドメイン設定をチェック
echo "### ドメイン設定の重複チェック"
grep -l "DomainName.*goo.ne.jp" *.yaml | while read file; do
    echo "- $file でgoo.ne.jpドメインを設定"
done

echo ""

# ProjectCode vs ProjectName の不一致
echo "### ProjectCode/ProjectName 不一致"
for file in *.yaml; do
    if [ "$file" != "config.yaml" ] && [ "$file" != "README.md" ]; then
        project_code=$(grep "ProjectCode:" "$file" 2>/dev/null | sed 's/.*ProjectCode: *//' | tr -d '"')
        project_name=$(grep "ProjectName:" "$file" 2>/dev/null | sed 's/.*ProjectName: *//' | tr -d '"' | head -1)

        if [ -n "$project_code" ] && [ -n "$project_name" ] && [ "$project_code" != "$project_name" ]; then
            echo "- $file: ProjectCode='$project_code' vs ProjectName='$project_name'"
        fi
    fi
done

echo ""
echo "## 💡 推奨改善アクション"
echo ""
echo "1. **スタック名の統一**: 'aws-ses-byodkim' プレフィックスで統一"
echo "2. **ProjectName統一**: 全ファイルで'aws-ses-byodkim'に統一"
echo "3. **依存関係の最適化**: 不要な外部依存を削除"
echo "4. **命名規則の標準化**: 階層的なスタック命名の導入"
