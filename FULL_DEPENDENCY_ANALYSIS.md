# 📊 完全依存関係分析レポート
生成日時: Mon, Sep  8, 2025  3:07:54 PM

## 🏗️ スタック構成一覧
| ファイル名 | スタック名（推定） | 用途 |
|---|---|---|
| base.yaml | prod/base |  |
| enhanced-kinesis.yaml | prod/enhanced-kinesis |  |
| monitoring.yaml | prod/monitoring |  |
| phase-1-infrastructure-foundation.yaml | prod/phase-1-infrastructure-foundation | phase-1-infrastructure-foundation.yaml |
| phase-2-dkim-system.yaml | prod/phase-2-dkim-system | dkim-manager-lambda.yaml |
| phase-3-ses-byodkim.yaml | prod/phase-3-ses-byodkim | ses-configuration.yaml |
| phase-4-dns-preparation.yaml | prod/phase-4-dns-preparation | dns-preparation.yaml |
| phase-5-dns-team-collaboration.yaml | prod/phase-5-dns-team-collaboration | dns-team-collaboration.yaml |
| phase-7-dns-validation-dkim-activation.yaml | prod/phase-7-dns-validation-dkim-activation | dns-validation-dkim-activation.yaml |
| phase-8-monitoring-system.yaml | prod/phase-8-monitoring-system | monitoring-system.yaml |
| security.yaml | prod/security |  |
| ses.yaml | prod/ses |  |
| simple-base.yaml | prod/simple-base |  |

## 🔗 依存関係マップ

### 📋 base.yaml
**Dependencies:** なし

### 📋 enhanced-kinesis.yaml
**Dependencies:**
- prod/base.yaml

**Stack Output参照 (4 個):**
- prod/base.yaml

### 📋 monitoring.yaml
**Dependencies:**
- prod/base.yaml
- prod/ses.yaml

**Stack Output参照 (3 個):**
- prod/base.yaml
- prod/ses.yaml

### 📋 phase-1-infrastructure-foundation.yaml
**Dependencies:** なし

### 📋 phase-2-dkim-system.yaml
**Dependencies:**
- prod/phase-1-infrastructure-foundation.yaml

**Stack Output参照 (6 個):**
- prod/phase-1-infrastructure-foundation.yaml

### 📋 phase-3-ses-byodkim.yaml
**Dependencies:**
- prod/phase-1-infrastructure-foundation.yaml
- prod/phase-2-dkim-system.yaml

**Stack Output参照 (4 個):**
- prod/phase-1-infrastructure-foundation.yaml
- prod/phase-2-dkim-system.yaml

### 📋 phase-4-dns-preparation.yaml
**Dependencies:**
- prod/phase-1-infrastructure-foundation.yaml
- prod/phase-2-dkim-system.yaml
- prod/phase-3-ses-byodkim.yaml

**Stack Output参照 (4 個):**
- prod/phase-1-infrastructure-foundation.yaml
- prod/phase-2-dkim-system.yaml

### 📋 phase-5-dns-team-collaboration.yaml
**Dependencies:**
- prod/phase-1-infrastructure-foundation.yaml
- prod/phase-2-dkim-system.yaml
- prod/phase-3-ses-byodkim.yaml
- prod/phase-4-dns-preparation.yaml

**Stack Output参照 (4 個):**
- prod/phase-1-infrastructure-foundation.yaml
- prod/phase-2-dkim-system.yaml

### 📋 phase-7-dns-validation-dkim-activation.yaml
**Dependencies:**
- prod/phase-1-infrastructure-foundation.yaml
- prod/phase-2-dkim-system.yaml
- prod/phase-3-ses-byodkim.yaml
- prod/phase-4-dns-preparation.yaml
- prod/phase-5-dns-team-collaboration.yaml

**Stack Output参照 (4 個):**
- prod/phase-1-infrastructure-foundation.yaml
- prod/phase-2-dkim-system.yaml

### 📋 phase-8-monitoring-system.yaml
**Dependencies:**
- prod/phase-1-infrastructure-foundation.yaml
- prod/phase-2-dkim-system.yaml
- prod/phase-3-ses-byodkim.yaml
- prod/phase-4-dns-preparation.yaml
- prod/phase-5-dns-team-collaboration.yaml
- prod/phase-7-dns-validation-dkim-activation.yaml

**Stack Output参照 (4 個):**
- prod/phase-1-infrastructure-foundation.yaml
- prod/phase-2-dkim-system.yaml

### 📋 security.yaml
**Dependencies:**
- prod/base.yaml
- prod/monitoring.yaml

**Stack Output参照 (3 個):**
- prod/monitoring.yaml

### 📋 ses.yaml
**Dependencies:**
- prod/base.yaml

**Stack Output参照 (2 個):**
- prod/base.yaml

### 📋 simple-base.yaml
**Dependencies:** なし

## 📈 ProjectCode/ProjectName 一貫性チェック

| ファイル | ProjectCode | ProjectName |
|---|---|---|
| base.yaml | ses-migration |  |
| enhanced-kinesis.yaml | ses-migration |  |
| monitoring.yaml | ses-migration |  |
| phase-1-infrastructure-foundation.yaml |  | aws-byodmim |
| phase-2-dkim-system.yaml |  | !stack_output prod/phase-1-infrastructure-foundation.yaml::ProjectName |
| phase-3-ses-byodkim.yaml |  | !stack_output prod/phase-1-infrastructure-foundation.yaml::ProjectName |
| phase-4-dns-preparation.yaml |  | !stack_output prod/phase-1-infrastructure-foundation.yaml::ProjectName |
| phase-5-dns-team-collaboration.yaml |  | !stack_output prod/phase-1-infrastructure-foundation.yaml::ProjectName |
| phase-7-dns-validation-dkim-activation.yaml |  | !stack_output prod/phase-1-infrastructure-foundation.yaml::ProjectName |
| phase-8-monitoring-system.yaml |  | !stack_output prod/phase-1-infrastructure-foundation.yaml::ProjectName |
| security.yaml | ses-migration |  |
| ses.yaml | ses-migration |  |
| simple-base.yaml | ses-migration |  |

## 🚨 検出された問題

### ドメイン設定の重複チェック
- monitoring.yaml でgoo.ne.jpドメインを設定
- phase-1-infrastructure-foundation.yaml でgoo.ne.jpドメインを設定
- security.yaml でgoo.ne.jpドメインを設定
- ses.yaml でgoo.ne.jpドメインを設定

### ProjectCode/ProjectName 不一致

## 💡 推奨改善アクション

1. **スタック名の統一**: 'aws-ses-byodkim' プレフィックスで統一
2. **ProjectName統一**: 全ファイルで'aws-ses-byodkim'に統一
3. **依存関係の最適化**: 不要な外部依存を削除
4. **命名規則の標準化**: 階層的なスタック命名の導入
