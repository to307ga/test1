# SES BYODKIM手動更新手順書
## Phase 3: DNS設定完了後のSES更新（手動CLI）

### 実行日時
- 2025年9月17日

### 概要
AWS SES BYODKIMのセレクタを手動で更新し、新しいDKIM証明書に切り替える手順

---

## 📋 前提条件

### 必要な準備
1. **新しいDKIM証明書の生成済み**: Lambda V2で証明書が作成されていること
2. **S3への秘密鍵保存済み**: `aws-ses-migration-prod-dkim-certificates` バケットに秘密鍵が保存されていること
3. **Secrets Manager更新済み**: `aws-ses-migration/prod/dkim-config` に新しいセレクタ情報が保存されていること
4. **AWS CLI設定済み**: 適切な権限で認証されていること

### 環境情報
- **ドメイン**: goo.ne.jp
- **リージョン**: ap-northeast-1  
- **旧セレクタ**: gooid-21-pro-20250912-1
- **新セレクタ**: gooid-21-pro-20250917-3

---

## 🔍 Step 1: 現状確認

### 1.1 現在のSES状態確認
```bash
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1
```

**確認項目:**
- `DkimAttributes.Tokens`: 現在使用中のセレクタ
- `DkimAttributes.Status`: DKIMの状態
- `DkimAttributes.SigningAttributesOrigin`: "EXTERNAL"（BYODKIMモード）

### 1.2 最新証明書情報の確認
```bash
aws secretsmanager get-secret-value --secret-id "aws-ses-migration/prod/dkim-config" --region ap-northeast-1 --query SecretString --output text
```

**確認項目:**
- `selector`: 最新のセレクタ名
- `dns_record.value`: 対応するDNS TXTレコード値
- `s3_key_path`: S3での秘密鍵保存パス

### 1.3 S3での秘密鍵確認
```bash
aws s3 ls s3://aws-ses-migration-prod-dkim-certificates/dkim-keys/goo.ne.jp/gooid-21-pro-20250917-3/ --region ap-northeast-1
```

---

## 🔧 Step 2: SES手動更新実行

### 2.1 秘密鍵のダウンロード
```bash
aws s3 cp s3://aws-ses-migration-prod-dkim-certificates/dkim-keys/goo.ne.jp/gooid-21-pro-20250917-3/private_key.pem private_key_gooid-21-pro-20250917-3.pem --region ap-northeast-1
```

### 2.2 DKIM署名属性JSONの作成
ファイル名: `dkim-signing-attributes.json`
DomainSigningPrivateKeyにはダウンロードしたprivate_key_gooid-21-pro-20250917-3.pemファイルの値を張り付ける
```json
{
    "DomainSigningSelector": "gooid-21-pro-20250917-3",
    "DomainSigningPrivateKey": "MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKc..."
}
```

**注意事項:**
- `DomainSigningPrivateKey`: S3から取得したBase64エンコード済み秘密鍵を使用
- `NextSigningKeyLength`: BYODKIMでは使用不可（AWS_SES mode専用）

### 2.3 SESのBYODKIM設定更新
```bash
aws sesv2 put-email-identity-dkim-signing-attributes \
    --email-identity goo.ne.jp \
    --region ap-northeast-1 \
    --signing-attributes-origin EXTERNAL \
    --signing-attributes file://dkim-signing-attributes.json
```

**期待される出力:**
```json
{
    "DkimStatus": "NOT_STARTED",
    "DkimTokens": ["gooid-21-pro-20250917-3"]
}
```

---

## ✅ Step 3: 更新結果の確認

### 3.1 SES設定の確認
```bash
aws sesv2 get-email-identity --email-identity goo.ne.jp --region ap-northeast-1
```

**確認ポイント:**
- `DkimAttributes.Tokens`: 新しいセレクタに更新されていること
- `DkimAttributes.Status`: "PENDING"（DNS設定待ち状態）
- `DkimAttributes.SigningEnabled`: true
- `DkimAttributes.SigningAttributesOrigin`: "EXTERNAL"

### 3.2 変更前後の比較

| 項目 | 変更前 | 変更後 |
|------|---------|---------|
| セレクタ | gooid-21-pro-20250912-1 | gooid-21-pro-20250917-3 |
| DKIM Status | FAILED | PENDING |
| 署名有効化 | true | true |
| 属性起源 | EXTERNAL | EXTERNAL |

---

## ⚠️ 重要な注意事項

### DNS設定について
1. **SESコンソールのCSV問題**: SESからダウンロードしたCSVの `p=customerProvidedPublicKey` は間違ったプレースホルダー
2. **正しいDNS値**: 必ずSecrets Managerから取得した実際の公開鍵を使用する
3. **DNSレコード名**: `gooid-21-pro-20250917-3._domainkey.goo.ne.jp`

### セキュリティ考慮事項
1. **秘密鍵の取り扱い**: ダウンロードした秘密鍵ファイルは作業完了後に削除
2. **権限管理**: 最小権限の原則でAWS CLI実行
3. **ログ保存**: 実行結果を適切に記録・保存

---

## 🔄 次のステップ

### DNS設定依頼
1. **DNSチームへの依頼**: 修正版CSVファイル `dkim-dns-records-corrected.csv` を使用
2. **TXTレコード設定**: `gooid-21-pro-20250917-3._domainkey.goo.ne.jp`
3. **設定完了待ち**: DKIM Status が "SUCCESS" になるまで待機

### Phase-7実行準備
1. **DNS設定完了確認**: `dig` コマンドでTXTレコードを確認
2. **DKIM Status確認**: "SUCCESS" 状態であることを確認
3. **Phase-7実行**: ゼロダウンタイム手順に従い手動実行

---

## 📝 実行ログ

### 実行日時
- 2025年9月17日 13:09頃

### 実行結果
- ✅ SES更新成功
- ✅ セレクタ切り替え完了  
- ✅ DKIM設定更新完了
- ⏳ DNS設定待ち状態

### 作成されたファイル
- `dkim-signing-attributes.json`: DKIM署名属性設定ファイル
- `dkim-dns-records-corrected.csv`: 修正版DNS設定依頼CSV
- `private_key_gooid-21-pro-20250917-3.pem`: 一時的な秘密鍵ファイル（削除推奨）

---

## 📞 連絡先・参照
- **AWS SES公式ドキュメント**: https://docs.aws.amazon.com/ses/latest/dg/send-email-authentication-dkim-bring-your-own.html
- **プロジェクト担当者**: [連絡先情報]
- **DNS設定担当チーム**: [DNSチーム連絡先]
