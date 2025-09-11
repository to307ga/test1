# BYODKIM手順書の修正版

## ❌ 手順書の問題点

### 1. **Step 2の`enable_dkim`アクションが不完全**
```bash
# ❌ 誤った手順（現在の手順書）
{
  "action": "enable_dkim",  # これはAWS管理DKIMを有効化するだけ
  "domain": "goo.ne.jp",
  "environment": "prod",
  "projectName": "aws-ses-migration",
  "dkimSeparator": "gooid-21-pro"
}
```

**問題**: `enable_dkim`アクションは単にDKIMを有効化するだけで、BYODKIMとしてSESに登録しません。

### 2. **Phase 7が必要なことが記載されていない**
現在の手順書ではStep 1とStep 2だけでBYODKIMが完了するように記載されていますが、実際にはPhase 7の実行が必要です。

## ✅ 正しい手順

### **Step 1: DKIM証明書の生成** ✅ **完了済み**
```bash
# DKIM証明書生成用ペイロード作成
cat > create-dkim-payload.json << EOF
{
  "action": "create_dkim",
  "domain": "goo.ne.jp",
  "environment": "prod",
  "projectName": "aws-ses-migration",
  "dkimSeparator": "gooid-21-pro"
}
