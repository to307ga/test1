# 依存関係分析レポート

## 🚨 発見された依存関係の競合

### 1. SES ドメイン重複競合
- **prod/ses.yaml**: `goo.ne.jp` + `gooid-21-prod`
- **phase-3-ses-byodkim.yaml**: `goo.ne.jp` + `gooid-21-pro`
- **競合**: 同一ドメインに対する異なるBYODKIM設定

### 2. 監視システム依存ミスマッチ
- **monitoring.yaml**: `!stack_output prod/ses.yaml::SESLogGroupName` を期待
- **実際**: Phase 3でSES作成、異なるoutput名の可能性

### 3. セキュリティスタック循環依存
- **security.yaml → monitoring.yaml**: outputs依存
- **構築順序**: monitoring → security (逆順)

## 💡 推奨解決策

### Option A: BYODKIM Phase優先統合
```yaml
# 構築順序
1. prod/base.yaml                                    # 基盤
2. prod/phase-1-infrastructure-foundation.yaml      # BYODKIM基盤
3. prod/phase-2-dkim-system.yaml                   # DKIM管理
4. prod/phase-3-ses-byodkim.yaml                   # SES+BYODKIM
5. prod/monitoring.yaml (依存修正)                  # 監視
6. prod/security.yaml                               # セキュリティ
```

### Option B: 統一テンプレート作成
- 既存sesとBYODKIM Phase 3を統合した新テンプレート作成
- 一貫したoutput名とパラメータ

### Option C: 段階的移行
- 既存ses.yamlは無効化
- BYODKIM Phaseを主軸とした新アーキテクチャ

## 🔄 推奨アクション

1. **即座**: prod/ses.yaml の依存を削除
2. **短期**: monitoring/security の依存関係をPhase outputs に変更
3. **長期**: 統一された依存関係グラフの構築
