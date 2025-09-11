# BYODKIM Migration - Sceptre Template Updates

## Overview
EasyDKIMからBYODKIMへの移行に対応したSceptreテンプレート・パラメータファイルの更新内容です。

## 変更されたファイル

### 1. SESテンプレート (`templates/ses.yaml`)

#### 追加されたパラメータ:
- `DKIMMode`: "BYODKIM" | "EasyDKIM" (Default: "BYODKIM")
- `BYODKIMSelector`: DKIMセレクター名 (Default: "gooid-21")
- `BYODKIMRotationInterval`: ローテーション間隔（日） (Default: 365)
- `EnableBYODKIMAutomation`: BYODKIM自動化の有効化 (Default: "true")

#### 追加されたリソース:
**KMS関連**
- `BYODKIMKMSKey`: RSA-2048 Asymmetric Key for BYODKIM
- `BYODKIMKMSKeyAlias`: KMSキーエイリアス

**IAMロール**
- `BYODKIMAutomationLambdaRole`: BYODKIM自動化用Lambda実行ロール

**Lambda関数群（5つ）**
1. `DKIMRotationOrchestratorLambda`: 全体のローテーション統合管理
2. `DKIMKeyGeneratorLambda`: KMS Asymmetric Keyによる鍵生成
3. `SESConfigUpdaterLambda`: SES BYODKIM設定の自動更新
4. `NotificationManagerLambda`: 通知・レポート自動送信
5. `ValidationMonitorLambda`: DKIM検証状況の自動監視

**EventBridge**
- `BYODKIMRotationScheduleRule`: 年次自動ローテーションスケジュール
- `BYODKIMRotationLambdaPermission`: EventBridge→Lambda実行権限

#### 更新されたリソース:
**SES EmailIdentity**
- `SigningAttributesOrigin`: BYODKIMモード時は"EXTERNAL"
- `NextSigningKeyLength`: EasyDKIMモード時のみRSA_2048_BIT

### 2. 監視テンプレート (`templates/monitoring.yaml`)

#### 追加されたパラメータ:
- `EnableBYODKIMMonitoring`: BYODKIM監視の有効化 (Default: "true")
- `BYODKIMSelector`: 監視対象BYODKIMセレクター

#### 追加されたアラート:
- `BYODKIMVerificationAlarm`: BYODKIM検証失敗アラート
- `BYODKIMKeyRotationAlarm`: BYODKIMキーローテーションアラート
- `KMSKeyGenerationFailedAlarm`: KMS鍵生成失敗アラート

### 3. 設定ファイル更新

#### 本番環境 (`config/prod/ses.yaml`)
```yaml
# BYODKIM Configuration
DKIMMode: "BYODKIM"
BYODKIMSelector: "gooid-21"
BYODKIMRotationInterval: 365
EnableBYODKIMAutomation: "true"
```

#### 開発環境 (`config/dev/ses.yaml`)
```yaml
# BYODKIM Configuration (Development)
DKIMMode: "BYODKIM"
BYODKIMSelector: "gooid-21-dev"
BYODKIMRotationInterval: 365
EnableBYODKIMAutomation: "true"
```

#### 監視設定
**本番環境** (`config/prod/monitoring.yaml`)
```yaml
EnableBYODKIMMonitoring: "true"
BYODKIMSelector: "gooid-21"
```

**開発環境** (`config/dev/monitoring.yaml`)
```yaml
EnableBYODKIMMonitoring: "true"
BYODKIMSelector: "gooid-21-dev"
```

## 主要な自動化機能

### 1. BYODKIM自動ローテーション
- **スケジュール**: EventBridge年次実行（365日間隔）
- **処理フロー**:
  1. DKIMRotationOrchestrator → 全体統合管理
  2. DKIMKeyGenerator → KMS RSA-2048鍵生成
  3. SESConfigUpdater → SES設定自動更新
  4. NotificationManager → DNS更新依頼メール送信
  5. ValidationMonitor → 継続的検証状況監視

### 2. 通知システム
- **1か月前予告**: EventBridge事前スケジュール
- **実行完了通知**: DNS更新依頼（48時間以内）
- **エラー通知**: Lambda関数・KMS鍵生成失敗

### 3. 監視・アラート
- **BYODKIM検証状況**: SUCCESS/FAILED監視
- **KMS鍵生成**: 成功/失敗監視
- **Lambda自動化**: 各関数の実行状況監視

## DNS設定作業（手動対応必要）

### 実行時期: 年1回（大幅負荷軽減）

#### 新規追加レコード:
```
Name: gooid-21._domainkey.goo.ne.jp
Type: TXT
Value: [KMS生成公開鍵]
TTL: 300
```

#### 旧レコード削除:
- 新レコード検証完了後（48-72時間後）
- 削除期限: 7日以内

## デプロイ順序

```bash
# 1. ベーススタック（変更なし）
sceptre launch prod/base

# 2. SESスタック（BYODKIM対応）
sceptre launch prod/ses

# 3. 監視スタック（BYODKIM監視対応）
sceptre launch prod/monitoring

# 4. その他のスタック
sceptre launch prod/security
sceptre launch prod/enhanced-kinesis
```

## 運用負荷軽減効果

| 項目 | EasyDKIM（従来） | BYODKIM自動化 |
|------|-----------------|---------------|
| **ローテーション頻度** | 月1回（30日） | 年1回（365日） |
| **DNS作業回数** | 年12回 | 年1回 |
| **手動作業** | 毎月DNS更新 | 年1回DNS更新のみ |
| **事前準備期間** | 2-3日 | 1か月 |
| **自動化レベル** | 一部 | ほぼ完全自動化 |

## セキュリティ強化

- **KMS Asymmetric Keys**: AWS管理による高セキュリティ鍵生成
- **IAM権限**: Lambda関数別の最小権限設定
- **暗号化**: RSA-2048による強力な暗号化
- **監査ログ**: CloudTrail + CloudWatch Logs による完全監査

---

**作成日**: 2025年9月4日
**対象環境**: 本番・開発環境
**DKIMセレクター**: gooid-21 (本番) / gooid-21-dev (開発)
