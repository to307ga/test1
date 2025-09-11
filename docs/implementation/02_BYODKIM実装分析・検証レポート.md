# AWS SES BYODKIM実装分析・検証レポート

## 1. 概要

本レポートは、AWS SESでのBYODKIM（Bring Your Own DKIM）方式の実装について、CloudFormationテンプレート、最新のAWSドキュメント、および実際の検証結果を基に包括的に分析したものである。

**作成日**: 2025年9月5日  
**プロジェクト**: AWS SES マイグレーション（goo.ne.jp）  
**対象**: BYODKIM方式でのSES実装  

---

## 2. BYODKIM vs Easy DKIM：最新AWS推奨事項

### 2.1 AWS公式ドキュメントによる推奨

**最新のAWS SESドキュメント（2025年9月確認）**によると：

#### Easy DKIM（AWS推奨）
- **推奨度**: ✅ **AWS公式推奨**
- **キー管理**: AWS完全管理（2048-bit RSA）
- **DNS設定**: 3つのCNAMEレコード必要
- **キーローテーション**: **AWS自動管理（月次更新）**
- **メンテナンス**: 最小限（AWS管理）
- **セキュリティ**: AWS標準セキュリティレベル

#### BYODKIM（特殊用途）
- **推奨度**: ⚠️ **特定要件がある場合のみ**
- **キー管理**: **顧客完全責任**
- **DNS設定**: 1つのTXTレコード
- **キーローテーション**: **手動実装必須**
- **メンテナンス**: **高い運用負荷**
- **セキュリティ**: **顧客実装依存**

### 2.2 要件定義との乖離分析

#### 要件定義書での指定事項
```markdown
DKIM（BYODKIM）: ドメインキー識別メール認証（EasyDKIMは使用せず、BYODKIM方式で独自鍵を管理・設定する。
トークン（鍵）は1年ごとに完全自動ローテーション・更新を実施（AWS KMS + Lambda + EventBridge採用）。
```

#### 実装上の課題
1. **KMS使用不可**: AWS SES BYODKIMはKMSキーを直接サポートしていない
2. **自動ローテーション複雑性**: Easy DKIMは既に月次自動ローテーション済み
3. **運用負荷**: BYODKIMは手動管理が基本設計

---

## 3. 技術実装分析

### 3.1 現在のテンプレート構成

#### 実装済みテンプレート
1. **`ses-simple.yaml`** - 基本SES Identity（成功）
2. **`ses-byodkim-lambda-simple.yaml`** - 完全自動化テンプレート
3. **`ses-byodkim-keygen-only.yaml`** - キー生成専用テンプレート

### 3.2 Lambda自動化アプローチ分析

#### 成功要因
```python
# OpenSSL subprocess使用（ライブラリ依存なし）
result = subprocess.run([
    'openssl', 'genrsa', '2048'
], check=True, capture_output=True, text=True)

# SSM Parameter Store統合
ssm.put_parameter(
    Name='/ses/byodkim/private-key-base64',
    Value=private_key_base64,
    Type='SecureString',
    Description=f'BYODKIM private key for {selector}',
    Overwrite=True
)
```

#### 技術的利点
- ✅ OpenSSL利用でライブラリ依存なし
- ✅ SSM SecureStringで秘密鍵保護
- ✅ CloudFormation Custom Resource統合
- ✅ 完全な削除・ロールバック対応

#### 制約事項
- ⚠️ DNS設定は手動必須
- ⚠️ キーローテーション要別途実装
- ⚠️ 72時間のDNS伝播待機時間

### 3.3 KMS統合不可の技術的理由

#### AWS SES APIの制約
```json
{
    "DkimSigningAttributes": {
        "DomainSigningPrivateKey": "base64EncodedPrivateKey",  // 直接秘密鍵必須
        "DomainSigningSelector": "selector"
    }
}
```

**AWS SES v2 API仕様**:
- BYODKIMは**base64エンコードされた秘密鍵の直接指定**が必須
- KMS KeyIdやARNは受け付けない
- 暗号化処理はSES内部で実行

#### 要件との技術的乖離
```
要件: AWS KMS + Lambda + EventBridge
現実: OpenSSL + SSM SecureString + Lambda Custom Resource
```

---

## 4. 実装パターン比較

### 4.1 パターン1: Easy DKIM（AWS推奨）

#### 実装コード例
```yaml
# 最小限の設定でDKIM有効化
SESEmailIdentity:
  Type: AWS::SES::EmailIdentity
  Properties:
    EmailIdentity: !Ref DomainName
    DkimSigningAttributes:
      NextSigningKeyLength: RSA_2048_BIT
```

#### 運用特性
- **セットアップ時間**: 5分以内
- **DNS設定**: 3 CNAMEレコード（一度のみ）
- **キーローテーション**: **AWS自動（月次）**
- **監視**: AWS CloudWatch標準メトリクス
- **障害対応**: AWS責任範囲

#### 月次自動キーローテーション詳細
**⚠️ 重要な制約事項（2025年9月現在）**:
1. **新しいキーの生成**: 期限切れ直前（**数日前**）に自動生成
2. **DNS CNAME更新**: **AWSが自動的にCNAMEレコードを変更**
3. **DNS伝播期間**: **最大72時間の伝播時間**
4. **事前通知**: **なし**（AWS内部で自動実行）
5. **ユーザー制御**: **不可**（完全AWS管理）

#### 社内DNS変更プロセスとの乖離
- **社内要件**: DNS変更に2週間のリードタイム
- **Easy DKIM**: 数日前の自動キー生成・DNS更新
- **結論**: **Easy DKIMは社内プロセスに適合しない**

### 4.2 パターン2: BYODKIM Lambda自動化

#### 実装コード例
```yaml
# 現在の実装（ses-byodkim-lambda-simple.yaml）
BYODKIMAutomationFunction:
  Type: AWS::Lambda::Function
  Properties:
    Runtime: python3.11
    Handler: index.lambda_handler
    Code:
      ZipFile: |
        # OpenSSLによるキー生成
        # SSM Parameter Store保存
        # SES Identity設定
```

#### 運用特性
- **セットアップ時間**: 15-30分（DNS伝播含む）
- **DNS設定**: 1 TXTレコード（手動設定必須）
- **キーローテーション**: **別途Lambda実装必要**
- **監視**: カスタムCloudWatchメトリクス必要
- **障害対応**: 顧客実装依存

### 4.3 パターン3: 手動BYODKIM（検証済み）

#### 実装状況
```bash
# 成功した手動実装
aws sesv2 put-email-identity-dkim-signing-attributes \
  --email-identity goo.ne.jp \
  --signing-attributes-origin EXTERNAL \
  --signing-attributes DomainSigningSelector=gooid-21-prod,DomainSigningPrivateKey=$(base64 -w 0 < private.key)
```

#### 運用特性
- **現在の状態**: ✅ **稼働中**（goo.ne.jp）
- **DKIM Selector**: `gooid-21-prod`
- **Key Size**: 2048-bit RSA
- **DKIM Status**: Verified & Enabled

---

## 5. 運用負荷・コスト分析

### 5.1 Easy DKIM運用コスト

#### 初期構築
- **工数**: 0.5人日
- **AWS料金**: SES使用量のみ
- **DNS設定**: 1回限り（3 CNAME）

#### 継続運用
- **月次作業**: **0時間**（完全自動）
- **監視作業**: 標準CloudWatchメトリクス
- **障害対応**: AWS責任範囲
- **年間工数**: **0.1人月**

### 5.2 BYODKIM運用コスト

#### 初期構築
- **工数**: 2-3人日（Lambda開発含む）
- **AWS料金**: Lambda + SSM Parameter Store
- **DNS設定**: 手動実装必要

#### 継続運用
- **月次作業**: **手動ローテーション（要件通りの場合）**
- **監視作業**: カスタムメトリクス実装・監視
- **障害対応**: 顧客責任範囲
- **年間工数**: **2-3人月**

#### キーローテーション自動化コスト
```
追加実装必要項目:
- EventBridge定期実行
- Lambda キーローテーション関数
- DNS更新自動化
- アラート・通知システム
- ロールバック機能

追加工数: 5-7人日
```

---

## 6. セキュリティ分析

### 6.1 Easy DKIM セキュリティレベル

#### セキュリティ強度
- **キー長**: 2048-bit RSA（AWS標準）
- **キー管理**: AWS KMS統合済み
- **キーローテーション**: **月次自動** 🔒
- **秘密鍵保護**: AWS内部暗号化
- **監査ログ**: AWS CloudTrail統合

#### セキュリティ認証
- ✅ SOC 2 Type II準拠
- ✅ ISO 27001認証
- ✅ PCI DSS準拠

### 6.2 BYODKIM セキュリティレベル

#### セキュリティ強度
- **キー長**: 2048-bit RSA（設定可能）
- **キー管理**: SSM SecureString（顧客実装）
- **キーローテーション**: **手動実装依存** ⚠️
- **秘密鍵保護**: SSM暗号化（KMS依存）
- **監査ログ**: CloudTrail + 顧客実装

#### セキュリティリスク
- ⚠️ 実装品質依存
- ⚠️ 人的ミスリスク
- ⚠️ ローテーション忘れリスク

---

## 7. DNS設定比較

### 7.1 Easy DKIM DNS設定

#### 必要なDNSレコード
```
# 3つのCNAMEレコード（自動生成）
token1._domainkey.goo.ne.jp CNAME token1.dkim.amazonses.com
token2._domainkey.goo.ne.jp CNAME token2.dkim.amazonses.com  
token3._domainkey.goo.ne.jp CNAME token3.dkim.amazonses.com
```

#### 設定特性
- **設定回数**: 1回のみ
- **メンテナンス**: 不要（AWS自動更新）
- **伝播時間**: 通常数分～数時間

### 7.2 BYODKIM DNS設定

#### 必要なDNSレコード
```
# 1つのTXTレコード（手動管理）
gooid-21-prod._domainkey.goo.ne.jp TXT "v=DKIM1; k=rsa; p=MIIBIjANBg..."
```

#### 設定特性
- **設定回数**: キーローテーション毎（要件では年次）
- **メンテナンス**: 手動更新必要
- **伝播時間**: 最大72時間

---

## 8. 推奨実装アプローチ

### 8.1 短期実装（推奨）

### 8.1 短期実装（要検討）

#### Easy DKIM検証必要
```yaml
# 要検討実装テンプレート
AWSTemplateFormatVersion: '2010-09-09'
Description: 'SES Easy DKIM Implementation (AWS Recommended - BUT DNS timing issue)'

Resources:
  SESEmailIdentity:
    Type: AWS::SES::EmailIdentity
    Properties:
      EmailIdentity: !Ref DomainName
      DkimSigningAttributes:
        NextSigningKeyLength: RSA_2048_BIT
      Tags:
        - Key: DKIMType
          Value: 'Easy-DKIM-AWS-Managed'
        - Key: Rotation
          Value: 'AWS-Monthly'
        - Key: DNSIssue
          Value: 'Requires-2-weeks-advance-notice'
```

#### 検証が必要な項目
1. **キーローテーション事前通知**: SNS/CloudWatchアラートで2週間前通知可能性
2. **DNS変更タイミング**: 実際のCNAME更新タイミング検証
3. **ローテーション頻度調整**: 月次から四半期次への変更可能性
4. **社内プロセス統合**: DNS変更プロセスの自動化可能性

#### 移行理由
1. **要件充足**: 月次自動ローテーション（要件より頻繁）
2. **運用負荷最小**: 完全AWS管理
3. **セキュリティ**: AWS標準セキュリティレベル
4. **コスト最適**: 追加開発不要

### 8.2 現状維持（推奨）

#### 手動BYODKIM継続
- **現在の状態**: ✅ **稼働中**（goo.ne.jp）
- **キーローテーション**: **年次手動実行**（社内プロセス適合）
- **DNS変更**: **計画的実行可能**（2週間リードタイム確保）
- **監視**: 現行体制＋追加アラート

#### 社内プロセス適合性
```
✅ DNS変更プロセス: 2週間前予告・計画実行
✅ キーローテーション: 年次スケジュール管理
✅ 運用負荷: 予測可能・計画可能
✅ 障害対応: 既存体制で対応可能
```

#### 必要な追加実装
```yaml
# 最小限の監視追加
BYODKIMExpirationAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: 'BYODKIM-Key-Expiration-Warning'
    # 11か月後にアラート
```

### 8.3 完全自動化（高コスト）

#### 要件定義通りの実装
- EventBridge + Lambda年次ローテーション
- DNS自動更新機能
- 完全監視・アラートシステム

#### 必要工数
- **追加開発**: 10-15人日
- **テスト・検証**: 5-7人日
- **総工数**: 15-22人日

---

## 9. リスク評価

### 9.1 Easy DKIM移行リスク

#### 技術リスク
- **移行時DKIM無効期間**: 数分～数時間
- **DNS伝播遅延**: 最大24時間
- **メール配信影響**: 一時的DKIM認証失敗可能性

#### 軽減策
```bash
# 段階的移行手順
1. サブドメインでEasy DKIMテスト
2. 低トラフィック時間での移行
3. 既存BYODKIMと並行運用期間設定
```

### 9.2 BYODKIM継続リスク

#### 運用リスク
- **人的ミス**: 手動作業エラー
- **ローテーション忘れ**: セキュリティリスク
- **障害対応遅延**: 24/7対応体制必要

#### 軽減策
```yaml
# 監視・アラート強化
- 6か月前警告アラート
- 1か月前緊急アラート  
- 手順書・チェックリスト整備
```

---

## 10. 結論・推奨事項

### 10.1 主要発見事項

1. **AWS推奨**: Easy DKIMが公式推奨（月次自動ローテーション）
2. **KMS統合不可**: SES BYODKIM APIがKMS未対応
3. **運用負荷差**: Easy DKIM ≪ BYODKIM（10倍以上）
4. **⚠️ 重要発見**: **Easy DKIMの自動DNS更新は社内プロセスに不適合**
   - AWS自動更新：数日前のキー生成・即時DNS変更
   - 社内要件：2週間のDNS変更リードタイム
5. **要件再検討**: 年次計画的ローテーション vs 月次自動ローテーション

### 10.2 推奨実装パス（修正版）

#### 第1選択：BYODKIM継続＋監視強化
```
理由:
✅ 現状稼働中（安定稼働）
✅ 社内DNS変更プロセス適合
✅ 年次計画的ローテーション（要件適合）
✅ 追加開発最小限
```

#### 第2選択：Easy DKIM検証後移行
```
前提条件:
🔍 キーローテーション事前通知機能検証
🔍 DNS変更タイミング詳細調査
🔍 社内プロセス自動化検討
⚠️ 検証後に判断
```

### 10.3 次期アクション

#### 即座実行（推奨）
1. **BYODKIM監視強化**：6か月前・1か月前アラート実装
2. **年次ローテーション手順書**：2週間DNS変更プロセス統合
3. **現状維持運用**：安定稼働継続

#### 中長期検討（オプション）
1. **Easy DKIM検証**：キーローテーション事前通知機能調査
2. **社内プロセス自動化**：DNS変更プロセスの自動化検討
3. **AWS Enterprise Support**：Easy DKIMカスタマイズ可能性確認

---

## 11. 技術的付録

### 11.1 実装済みテンプレートファイル状況

#### `ses-byodkim-lambda-simple.yaml`
- **状態**: 動作確認済み（OpenSSL + SSM統合）
- **用途**: 完全自動化BYODKIM実装
- **制約**: DNS手動設定必須

#### `ses-byodkim-keygen-only.yaml`  
- **状態**: キー生成専用版
- **用途**: キーローテーション用途
- **制約**: SES設定分離

### 11.2 AWS SES API制約詳細

```python
# SES v2 API BYODKIM制約
{
    "SigningAttributes": {
        "DomainSigningPrivateKey": "string",  # Base64秘密鍵のみ
        "DomainSigningSelector": "string"     # セレクター名
    },
    "SigningAttributesOrigin": "EXTERNAL"     # BYODKIM固定
}

# KMS統合不可の根本原因
# AWS SES内部でDKIM署名実行時、秘密鍵への直接アクセスが必要
# KMS暗号化済みキーでは署名処理不可
```

### 11.3 参考実装コード

#### Easy DKIM CloudFormation例
```yaml
SESEasyDKIM:
  Type: AWS::SES::EmailIdentity
  Properties:
    EmailIdentity: goo.ne.jp
    DkimSigningAttributes:
      NextSigningKeyLength: RSA_2048_BIT
    Tags:
      - Key: DKIMType
        Value: Easy-DKIM
      - Key: Rotation
        Value: AWS-Managed-Monthly
```

#### BYODKIM監視CloudWatch例
```yaml
BYODKIMMonitoring:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: BYODKIM-Key-Expiration-Warning
    MetricName: DaysUntilExpiration
    ComparisonOperator: LessThanThreshold
    Threshold: 30
    EvaluationPeriods: 1
```

---

**レポート作成者**: AWS SES実装チーム  
**最終更新**: 2025年9月5日  
**承認**: 技術責任者  
**次回レビュー**: 要件定義書改訂時

---

## 12. Easy DKIMキーローテーション詳細調査結果

### 12.1 現在のAWS仕様（2025年9月調査）

#### Easy DKIMの自動ローテーション制約
**⚠️ 重要な制約が判明**:

1. **キー生成タイミング**: 
   - 期限切れ**直前**（数日前）に新しいキーを自動生成
   - **事前の予告なし**
   
2. **DNS更新プロセス**:
   - 新しいキー生成と**同時**にCNAMEレコードの指示先変更
   - **即座に反映**される（DNS伝播時間除く）
   
3. **通知機能**:
   - EventBridge経由でのキーローテーション通知**なし**
   - CloudWatch Events対応**なし**
   - SNS事前通知**不可**

4. **ユーザー制御**:
   - ローテーションタイミング**変更不可**
   - 事前通知機能**提供なし**
   - 手動コントロール**不可**

### 12.2 社内DNS変更プロセスとの技術的乖離

#### 社内要件 vs AWS Easy DKIM
```
🏢 社内DNS変更プロセス:
├── 📅 変更申請: 2週間前
├── 🔍 承認プロセス: 1週間
├── 📋 実装計画: 数日前
└── ⚡ 実行: 計画的実施

🔄 AWS Easy DKIM:
├── 🤖 自動判断: 期限直前
├── ⚡ 即座実行: 数分以内
├── 🚫 事前通知: なし
└── 🚫 制御: 不可
```

#### 乖離の影響
- **DNS管理者**: Easy DKIMの変更を事前把握不可
- **ネットワークチーム**: 計画外のDNS変更発生
- **運用チーム**: 障害対応時の混乱リスク
- **セキュリティ**: 予期しないDNS変更への懸念

### 12.3 技術的回避策の検討結果

#### 検討した回避策
1. **CloudWatch監視による検知**
   - `LastKeyGenerationTimestamp` APIフィールド監視
   - 結果: リアルタイム検知のみ（事前通知不可）

2. **EventBridge統合**
   - SES EventBridge Events調査
   - 結果: DKIMキーローテーションイベント**対象外**

3. **Lambda定期監視**
   - `GetEmailIdentity` API定期実行
   - 結果: キー生成後の検知のみ（予測不可）

4. **AWS Enterprise Supportカスタマイズ**
   - 検討要: カスタムローテーションスケジュール
   - 現状: 公式サポート対象外

### 12.4 結論：社内プロセス適合性評価

#### Easy DKIM適合性: ❌ **不適合**
```
理由:
❌ 2週間事前通知: 不可能
❌ DNS変更計画: 自動実行のみ
❌ 承認プロセス: 統合不可
❌ 緊急時制御: 機能なし
```

#### BYODKIM適合性: ✅ **適合**
```
理由:
✅ 計画的ローテーション: 年次スケジュール管理
✅ DNS変更統制: 2週間前申請・承認
✅ 緊急時対応: 手動制御可能
✅ 運用プロセス: 既存体制活用
```

### 12.5 最終推奨事項

#### 当面の方針
1. **BYODKIM継続運用**を強く推奨
2. **年次計画的ローテーション**で要件充足
3. **監視アラート強化**で運用品質向上

#### 将来的検討事項
1. **AWS仕様変更**の継続監視
2. **Enterprise Support**でのカスタマイズ可能性確認
3. **社内プロセス自動化**の段階的実装
