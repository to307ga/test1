# 🎯 依存関係問題の統合解決計画

## 📊 現在の問題状況

### 1. 🔥 重複するSESドメイン設定（最高優先度）
```yaml
# 4つのファイルでgoo.ne.jpドメインを設定
- monitoring.yaml
- phase-1-infrastructure-foundation.yaml
- security.yaml  
- ses.yaml
```

### 2. 🔗 依存関係の競合
```yaml
# monitoring.yaml と security.yaml
dependencies:
  - prod/ses.yaml          # ❌ 作成予定なし
  
# 実際の構築順序では
# phase-3-ses-byodkim.yaml でSES作成予定
```

### 3. 📝 ProjectName不統一
```yaml
# Base系: ses-migration
- base.yaml: ProjectCode: ses-migration
- monitoring.yaml: ProjectCode: ses-migration
- security.yaml: ProjectCode: ses-migration
- ses.yaml: ProjectCode: ses-migration

# BYODKIM Phase系: aws-byodmim
- phase-1-*: ProjectName: aws-byodmim
- phase-2-*: ProjectName: aws-byodmim (参照)
```

## 🛠️ 統合解決計画

### Phase 1: 命名規則統一
```yaml
# 全システム統一命名規則
ProjectCode: aws-ses-migration      # Base系統で統一
ProjectName: aws-byodmim           # BYODKIM Phase系統で統一
Environment: prod
DomainName: goo.ne.jp
```

### Phase 2: 依存関係リファクタリング
```yaml
# 新しい構築順序
1. prod/aws-ses-byodkim-base                    # 基盤インフラ
2. prod/aws-ses-byodkim-infrastructure          # BYODKIM専用基盤
3. prod/aws-ses-byodkim-dkim-system            # DKIM管理
4. prod/aws-ses-byodkim-ses-configuration      # SES設定
5. prod/aws-ses-byodkim-monitoring             # 監視（修正済み依存）
6. prod/aws-ses-byodkim-security               # セキュリティ（修正済み依存）
7-11. 残りのPhase続行
```

### Phase 3: テンプレート統合
```yaml
# 重複排除
- ses.yaml を無効化
- phase-3-ses-byodkim.yaml をメインSES設定として使用
- monitoring.yaml/security.yaml の依存をphase-3参照に変更
```

## 🚀 即座に実行すべき修正

### 修正1: monitoring.yaml依存関係
```yaml
# 修正前
dependencies:
  - prod/base.yaml
  - prod/ses.yaml              # ❌

# 修正後
dependencies:
  - prod/base.yaml
  - prod/phase-3-ses-byodkim.yaml   # ✅
```

### 修正2: security.yaml依存関係
```yaml
# 依存チェーン修正
dependencies:
  - prod/base.yaml
  - prod/phase-3-ses-byodkim.yaml   # SES設定取得
  - prod/monitoring.yaml            # 監視機能取得
```

### 修正3: ProjectCode統一
```yaml
# 全ファイルで統一
ProjectCode: aws-ses-migration      # Base系統
ProjectName: aws-byodmim           # BYODKIM Phase系統
```

## 📅 実装スケジュール

### 🔥 緊急（今すぐ）
1. monitoring.yaml の ses.yaml依存削除
2. security.yaml の依存関係修正
3. ProjectName不統一の修正

### 📋 短期（1日以内）
1. スタック命名規則の統一実装
2. 新しい構築順序の検証
3. テンプレート重複の排除

### 🏗️ 中期（1週間以内）
1. 統一されたアーキテクチャの完全テスト
2. ドキュメント更新
3. 運用手順の整備
