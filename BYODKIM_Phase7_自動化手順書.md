# BYODKIM Phase-7 自動化手順書

## 概要

Phase-7では、DNS TXTレコードの完了確認後、SESのBYODKIM設定を自動で更新します。
従来の7ステップ手動プロセスが1つのLambda関数呼び出しに自動化されました。

## 前提条件

1. Phase-1からPhase-6までが正常に完了していること
2. DNS TXTレコードがDNSサーバーに設定され、伝播が完了していること
3. DKIM証明書がS3に保存されていること
4. DKIM Manager V2でDNS情報がS3の `dns_records/{domain}/` に保存されていること

## 自動化の流れ

### Step 1: DNS完了通知の受信

DNS担当者から「DNS TXTレコード設定完了」の通知を受信します。

**Note**: Phase-5でDKIM証明書を生成した際、DKIM Manager V2が自動的にDNS情報をS3に保存し、DNSNotifier関数がDNS担当者に通知メールを送信しています。

### Step 2: 自動化されたSES更新の実行

以下のコマンドでLambda関数を呼び出し、自動でSES BYODKIM設定を更新します：

```bash
# テストスクリプトを使用
uv run python test_ses_automated_update.py

# または直接Lambda呼び出し
aws lambda invoke \
  --function-name aws-ses-migration-prod-dkim-manager-v2 \
  --payload '{
    "action": "update_ses_byodkim_automated",
    "domain": "your-domain.com",
    "selector": "selector1"
  }' \
  --output text \
  response.json && cat response.json | jq .
```

### Step 3: 実行結果の確認

#### 成功例:
```json
{
  "statusCode": 200,
  "message": "SES BYODKIM update completed successfully",
  "domain": "your-domain.com",
  "selector": "selector1", 
  "final_dkim_status": "SUCCESS",
  "signing_origin": "EXTERNAL",
  "timestamp": "2025-09-17T10:30:00.000Z",
  "automation_type": "lambda_extension"
}
```

#### DNS未完了エラー:
```json
{
  "statusCode": 400,
  "error": "DNS_TXT_NOT_READY",
  "message": "DNS TXT record for selector1._domainkey.your-domain.com is not yet available. Please wait for DNS propagation."
}
```

## 自動化された処理内容

### Phase 1: DNS TXT レコード検証
- `nslookup -type=TXT selector1._domainkey.your-domain.com` でDNS確認
- DKIM形式（v=DKIM1, p=...）の妥当性確認
- DNS未完了の場合はエラーで停止（安全措置）

### Phase 2: 証明書取得
- S3から秘密鍵を取得: `s3://bucket/dkim-certificates/{domain}/selector1/private_key.pem`
- DNS情報をS3から取得: `s3://bucket/dns_records/{domain}/`
- 証明書が存在しない場合はエラーで停止

### Phase 3: SES BYODKIM 更新プロセス
1. 現在のDKIM設定確認
2. BYODKIM署名属性の設定
3. DKIM有効化
4. 最終設定の検証

### エラー処理とロールバック
- SES更新中にエラーが発生した場合、自動でDKIM無効化によるロールバックを実行
- 全ての処理ログがCloudWatch Logsに記録

## 従来の手動プロセスとの比較

### 従来（7ステップ手動）:
1. AWS CLIでDKIM設定確認
2. S3から証明書ダウンロード
3. 証明書フォーマット変換
4. SES署名属性設定
5. DKIM有効化
6. 設定確認
7. 結果検証

### 自動化後（1ステップ）:
1. Lambda関数呼び出し → 全て自動実行

## トラブルシューティング

### DNS_TXT_NOT_READY エラー
- **原因**: DNS TXTレコードがまだ伝播していない
- **対処**: DNS伝播を待ってから再実行（通常24-48時間）

### CERTIFICATE_NOT_FOUND エラー
- **原因**: S3に証明書またはDNS情報が存在しない
- **対処**: Phase-5でDKIM Manager V2を使用してDKIM証明書を再生成し、DNS情報をS3に保存

### SES_UPDATE_FAILED エラー
- **原因**: SES API呼び出しエラー
- **対処**: IAM権限確認、SES設定確認後に再実行

## 手動フォールバック

自動化が失敗した場合は、従来の手動プロセスに戻すことができます：

```bash
# 1. 現在のDKIM設定確認
aws sesv2 get-email-identity-dkim-attributes --email-identity your-domain.com

# 2. DKIM無効化（リセット）
aws sesv2 put-email-identity-dkim-attributes \
  --email-identity your-domain.com \
  --dkim-enabled false

# 3. 手動での証明書設定...（従来手順に従う）
```

## 監視とアラート

- **CloudWatch Logs**: 全ての実行ログが記録
- **EventBridge**: 月次証明書監視は継続動作（456日有効期限、60日前アラート）
- **成功/失敗通知**: Lambda実行結果をSNSで通知（オプション）

## DNS通知プロセスの詳細

### Phase-5での自動通知
DKIM Manager V2で証明書生成時に以下が自動実行されます：

1. **DNS情報保存**: 生成されたDNS TXTレコード情報をS3の `dns_records/{domain}/` に保存
2. **SNS通知**: DNSNotifier関数がSNS経由でDNS担当者に通知メール送信
3. **S3連携**: DNSNotifier関数は保存されたDNS情報を取得してメール内容を構成

### 修正された実装
- **正しい関数**: `aws-ses-migration-prod-dns-notifier` を使用
- **サポートされていないアクション**: `phase_manager` アクションは実装されていません
- **S3パス**: DNS情報は `dns_records/{domain}/` に保存されます

## セキュリティ考慮事項

1. **DNS検証**: SES更新前に必ずDNS TXT完了を確認
2. **証明書保護**: S3証明書は暗号化済み
3. **DNS情報保護**: S3のDNS情報も暗号化され、適切なIAM権限で保護
4. **権限最小化**: Lambda実行ロールは必要最小限の権限
5. **監査ログ**: 全操作がCloudTrailに記録

## 実行チェックリスト

- [ ] DNS TXTレコード設定完了通知を受信
- [ ] ドメインと選択子を確認
- [ ] Lambda関数実行
- [ ] 実行結果確認（statusCode: 200）
- [ ] SES設定最終確認
- [ ] Phase-7完了報告

---

**更新日**: 2025-09-18  
**バージョン**: 2.1（DNS通知プロセス修正版）

### 変更履歴
- **v2.1 (2025-09-18)**: DKIM Manager V2のDNS情報保存機能を追記、DNSNotifier関数の正しい実装を明記
- **v2.0 (2025-09-17)**: Phase-7自動化対応
