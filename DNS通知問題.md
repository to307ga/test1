# DNS通知問題の原因と対処内容

## 問題の概要

AWS SES BYODKIM開発環境のDNS通知機能で、複数の問題が段階的に発生しました：

### 主要な問題
1. **DNS通知の送信失敗** - SNS通知が正常に送信されない
2. **DKIMセレクタ形式の不整合** - メールに含まれるセレクタ形式が期待と異なる
3. **パラメータ設定の冗長性** - Phase-6での設定重複

### 期待される形式
```
gooid-21-dev._domainkey.goo.ne.jp
```

### 実際に通知された形式（修正前）
```
dkim-20250901-1.domainkey.goo.ne.jp
```

## 問題の詳細分析

### 問題1: DNS通知の送信失敗

#### 発生箇所
- **ファイル**: `sceptre/templates_dev/dkim-manager-lambda.yaml`
- **関数**: `execute_phase_5()`
- **エラー**: SNS権限・設定問題

#### 根本原因
1. **SNS Topic ARN構築エラー**: 動的なアカウントID取得での問題
2. **SNS購読設定**: DNSチームメールアドレスの購読設定不備
3. **権限設定**: Lambda関数のSNS発行権限の設定問題

#### 対処内容
1. **DNSチームメールアドレス変更**: `goo-idpay-sys@ml.nttdocomo.com`に設定
2. **SNS購読手動設定**: 開発環境用SNSトピックへの購読追加
3. **Phase-6パラメータ中央化**: Phase-1からの参照に変更

### 問題2: DKIMセレクタ形式の不整合

#### 発生箇所
- **ファイル**: `sceptre/templates_dev/dkim-manager-lambda.yaml`
- **関数**: `execute_phase_4()`
- **行数**: 367行目

#### 根本原因
Lambda関数の`execute_phase_4`関数で、`dkim_separator`のデフォルト値が本番環境用（`gooid-21-pro`）のままになっていました。

```yaml
# 問題のあったコード（修正前）
dkim_separator = config.get('dkim_separator', 'gooid-21-pro')
```

開発環境では以下のようになるべきでした：
```yaml
# 正しいコード（修正後）
dkim_separator = config.get('dkim_separator', 'gooid-21-dev')
```

### 問題3: パラメータ設定の冗長性

#### 発生箇所
- **ファイル**: `sceptre/config/dev/phase-6-dns-setup.yaml`
- **問題**: DNSTeamEmailパラメータが重複定義

#### 対処内容
Phase-6の設定をPhase-1の出力参照に変更：
```yaml
# 修正前（冗長な設定）
DNSTeamEmail: "個別設定"

# 修正後（中央管理）
DNSTeamEmail: !stack_output dev/phase-1-infrastructure-foundation.yaml::DNSTeamEmail
```

### 影響範囲
1. **DKIM証明書生成**: Phase-4でのDKIMセレクタ生成時
2. **DNS通知**: Phase-5でのDNSチームへの通知メール内容
3. **S3保存**: DNS記録ファイルの保存内容
4. **Secrets Manager**: DKIM設定情報の更新
5. **パラメータ管理**: 複数フェーズでの設定一貫性

## 技術的詳細

### DKIMセレクタ生成ロジック
```python
# create_dkim_certificate関数内（621行目〜）
for i in range(3):
    if dkim_separator:
        custom_selector = f"{dkim_separator}-{today}-{i+1}"
    else:
        custom_selector = f"dkim-{today}-{i+1}"
```

### 問題発生と解決のタイムライン
1. **2025-09-08**: 初期デプロイ完了、DNS通知機能の実装開始
2. **2025-09-09**: 
   - DNS通知送信失敗（SNS権限・設定問題）
   - DNSチームメールアドレス変更要求
   - 初回DNS通知で `dkim-20250909-N` 形式が生成（セレクタ形式問題発見前）
3. **2025-09-10**: 
   - SNS設定問題解決、通知送信成功
   - DKIMセレクタ形式問題発見
   - Lambda関数修正・再デプロイ
   - 正しい `gooid-21-dev-20250910-N` 形式で再生成・再通知

## 実施した対処内容

### 段階1: DNS通知送信機能の修復

#### 1.1 DNSチームメールアドレス変更
**ファイル**: `sceptre/config/dev/phase-1-infrastructure-foundation.yaml`
```yaml
# Phase-1でのDNSTeamEmailパラメータ設定
DNSTeamEmail: goo-idpay-sys@ml.nttdocomo.com
```

#### 1.2 SNS購読設定
```bash
# 開発環境用SNSトピックへの手動購読追加
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-northeast-1:007773581311:aws-ses-migration-dev-dns-team-notifications \
  --protocol email \
  --notification-endpoint goo-idpay-sys@ml.nttdocomo.com
```

#### 1.3 パラメータ中央化
**ファイル**: `sceptre/config/dev/phase-6-dns-setup.yaml`
```yaml
# Phase-6の設定をPhase-1参照に変更
DNSTeamEmail: !stack_output dev/phase-1-infrastructure-foundation.yaml::DNSTeamEmail
```

### 段階2: DKIMセレクタ形式の修正

#### 2.1 コード修正
**ファイル**: `sceptre/templates_dev/dkim-manager-lambda.yaml`

```yaml
# 修正前（367行目）
dkim_separator = config.get('dkim_separator', 'gooid-21-pro')

# 修正後（367行目）
dkim_separator = config.get('dkim_separator', 'gooid-21-dev')
```

#### 2.2 Lambda関数バージョン更新
```yaml
# UPDATE_VERSIONを更新
UPDATE_VERSION: "v2.2" → "v2.3"
```

#### 2.3 デプロイ実行
```bash
uv run sceptre update dev/phase-2-dkim-system.yaml -y
```

### 段階3: 正しいデータでの再実行

#### 3.1 Phase-4の再実行
正しいDKIMセレクタを生成するため、Phase-4を再実行：
```python
# invoke_phase4_corrected.py
payload = {
    "action": "phase_manager",
    "phase": "4",
    "domain": "goo.ne.jp",
    "environment": "dev",
    "projectName": "aws-ses-migration",
    "dkimSeparator": "gooid-21-dev"
}
```

#### 3.2 Phase-5の再実行
修正されたDKIMセレクタでDNS通知を再送信：
```python
# invoke_phase5_corrected.py
payload = {
    "action": "phase_manager",
    "phase": "5",
    "domain": "goo.ne.jp",
    "environment": "dev",
    "projectName": "aws-ses-migration",
    "dkimSeparator": "gooid-21-dev"
}
```

## 修正結果の検証

### 1. Lambda実行ログ確認
```
Generated custom DKIM selector 1: gooid-21-dev-20250910-1
Generated custom DKIM selector 2: gooid-21-dev-20250910-2
Generated custom DKIM selector 3: gooid-21-dev-20250910-3
```

### 2. S3格納データ確認
**ファイル**: `s3://aws-ses-migration-dev-dkim-certificates/dns_records/goo.ne.jp/dns_records_20250910_033026.json`

```json
[
  {
    "name": "gooid-21-dev-20250910-1._domainkey.goo.ne.jp",
    "type": "TXT",
    "value": "k=rsa; p=...",
    "selector": "gooid-21-dev-20250910-1"
  },
  {
    "name": "gooid-21-dev-20250910-2._domainkey.goo.ne.jp",
    "type": "TXT",
    "value": "k=rsa; p=...",
    "selector": "gooid-21-dev-20250910-2"
  },
  {
    "name": "gooid-21-dev-20250910-3._domainkey.goo.ne.jp",
    "type": "TXT",
    "value": "k=rsa; p=...",
    "selector": "gooid-21-dev-20250910-3"
  }
]
```

### 3. DNS通知成功確認
```
# 最初の成功例（セレクタ形式は間違っていたが通知は送信された）
DNS notification sent successfully. MessageId: 5d4b6d30-32b5-5121-8b4e-0c0ac2a4e039

# 修正後の成功例（正しいセレクタ形式で通知送信）
DNS notification sent successfully. MessageId: 693fd9d9-a37f-502b-9e63-b8e35054601d
```

### 4. 段階別解決確認
#### 段階1解決: DNS通知送信機能の修復
- ✅ SNS購読設定完了
- ✅ 通知送信成功（MessageId: 5d4b6d30-32b5-5121-8b4e-0c0ac2a4e039）
- ❌ セレクタ形式は依然として不正

#### 段階2解決: DKIMセレクタ形式の修正
- ✅ Lambda関数コード修正
- ✅ 正しいセレクタ生成確認
- ✅ 最終通知送信成功（MessageId: 693fd9d9-a37f-502b-9e63-b8e35054601d）

## 学習ポイントと今後の対策

### 1. DNS通知システムの信頼性
- SNS設定とLambda権限の事前検証が重要
- 通知送信成功と通知内容の正確性は別々に検証が必要

### 2. 環境別設定の重要性
- 開発環境と本番環境で異なる設定値を持つ場合は、環境変数での制御が重要
- デフォルト値は環境に応じて適切に設定する必要がある

### 3. パラメータ管理の一元化
- 複数フェーズで使用される設定は中央管理することで重複と不整合を防ぐ
- Phase-1からの出力参照により設定の一貫性を保つ

### 4. テスト・検証プロセス
- DNS通知の内容は実際にメールを確認することが重要
- ログだけでなく、実際の出力結果の検証が必要
- 段階的な問題解決では各段階での検証が重要

### 5. ドキュメント化
- 環境別の設定違いは明確にドキュメント化する
- 問題が発生した場合の対処手順も記録しておく
- 複数の問題が重複する場合は、問題の関連性と解決順序を明確にする

### 4. 推奨改善案
```yaml
# 環境変数での制御を推奨
environment = config.get('environment', 'dev')
if environment == 'prod':
    default_separator = 'gooid-21-pro'
elif environment == 'dev':
    default_separator = 'gooid-21-dev'
else:
    default_separator = f'gooid-21-{environment}'

dkim_separator = config.get('dkim_separator', default_separator)
```

## まとめ

これらの問題は段階的に発生し、それぞれ異なる原因によるものでした：

1. **DNS通知送信失敗**: SNS設定とパラメータ管理の問題
2. **DKIMセレクタ形式不整合**: 環境別設定の不備

適切な修正により両方の問題が解決され、DNS通知システムは正常に動作し、正しいDKIMセレクタ形式でDNSチームに通知が送信されるようになりました。

重要な学習点として、複数の問題が重複する場合は、それぞれの問題を独立して特定・解決することが重要であり、一つの問題が解決されても他の問題が残存する可能性があることを認識する必要があります。

今後は以下の点を注意深く管理します：
- 環境別設定の管理
- パラメータの中央管理
- 段階的検証プロセス
- 同様の問題の再発防止

---
**作成日**: 2025年9月10日  
**最終更新**: 2025年9月10日  
**ステータス**: 解決済み
