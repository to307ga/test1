# DKIM Manager重複解消分析

## 現在の重複状況

### 設定ファイル重複
```
❌ phase-2-dkim-system.yaml (古いバージョン)
   - テンプレート: dkim-manager-lambda.yaml
   - 機能: 基本DKIM管理のみ
   - 安全制御: なし

✅ phase-2-dkim-system-v2.yaml (新バージョン) 
   - テンプレート: dkim-manager-lambda-v2-clean.yaml
   - 機能: DKIM管理 + BYODKIM安全制御
   - 安全制御: BYODKIMAutoApplyToSES, BYODKIMRotationMode等
```

### テンプレート重複
```  
❌ dkim-manager-lambda.yaml (1090行)
   - 古い実装
   - Layerベース
   - BYODKIM安全制御なし

✅ dkim-manager-lambda-v2-clean.yaml (630行)
   - 新しい実装  
   - AWS Official OpenSSL
   - BYODKIM安全制御付き
   - DNS調整対応
```

## 他ファイルからの参照状況

### V1(古い)を参照しているファイル
```yaml
# 要修正: 全てphase-2-dkim-system.yamlを参照
- phase-3-ses-byodkim.yaml
- phase-4-dns-preparation.yaml  
- phase-5-dns-team-collaboration.yaml
- phase-7-dns-validation-dkim-activation.yaml
- phase-8-monitoring.yaml
```

## 機能比較: V1 vs V2

### V1 (phase-2-dkim-system.yaml) - 削除対象
```yaml
# 基本機能のみ
parameters:
  CertificateValidityDays: 2
  RenewalAlertDays: 1
  
# 安全制御なし
# DNS調整機能なし
# 手動制御機能なし
```

### V2 (phase-2-dkim-system-v2.yaml) - 保持対象
```yaml
# 基本機能 + 安全制御
parameters:
  CertificateValidityDays: 2  
  RenewalAlertDays: 2
  DKIMSeparator: "gooid-21-pro"
  
# BYODKIM安全制御付き
BYODKIMAutoApplyToSES: "false"
BYODKIMRotationMode: "MANUAL"
DNSTeamNotificationEmail: "goo-idpay-sys@ml.nttdocomo.com"
```

## 重複解消計画（修正版）

### ステップ1: 古いファイル削除
```bash
# 古い設定ファイル削除
rm sceptre/config/prod/phase-2-dkim-system.yaml

# 古いテンプレート削除  
rm sceptre/templates/dkim-manager-lambda.yaml
```

### ステップ2: V2を正式版にリネーム
```bash
# V2を正式版にリネーム（既存参照はそのまま使える）
mv sceptre/config/prod/phase-2-dkim-system-v2.yaml sceptre/config/prod/phase-2-dkim-system.yaml
mv sceptre/templates/dkim-manager-lambda-v2-clean.yaml sceptre/templates/dkim-manager-lambda.yaml
```

### 利点: 参照更新不要
```yaml
# 他ファイルの参照はそのまま有効
!stack_output prod/phase-2-dkim-system.yaml::DKIMManagerFunctionArn
dependencies:
  - prod/phase-2-dkim-system.yaml

# リネーム後は自動的にV2の機能を参照
✅ BYODKIM安全制御付き
✅ DNS調整対応
✅ 手動制御機能
```

## 重複解消の効果

### ✅ メンテナンス性向上
- 単一ソースでの管理
- 設定変更時の影響範囲明確

### ✅ 機能統一
- BYODKIM安全制御の全システム適用
- DNS調整機能の統一

### ✅ 混乱防止
- 開発者の迷いを防止
- デプロイミスの防止

## 注意事項

### 既存デプロイへの影響
- 現在稼働中のスタックがある場合は慎重に移行
- phase-2-dkim-system スタックが存在する場合は削除が必要

### テスト必要性
- 参照変更後のスタック間連携確認
- V2機能の正常動作確認

この重複解消により、DKIM Managerが単一の最新バージョンで統一され、メンテナンス性と安全性が向上します。
