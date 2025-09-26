# BYODKIM安全ローテーション手順書

## 問題認識

**危険**: 自動BYODKIMローテーションは、DNS登録ラグ（2週間）により全メールのDKIM認証失敗を引き起こします。

## 安全なBYODKIMローテーション手順

### フェーズ1: 事前準備（2週間前）

1. **新鍵生成**（SESには未登録）
   ```bash
   # Lambda実行
   aws lambda invoke \
     --function-name aws-ses-migration-prod-dkim-manager-v2 \
     --payload '{"action": "create_dkim_certificate", "selector_number": "2"}' \
     response.json
   ```

2. **DNS申請書作成**
   - 生成された公開鍵でDNS TXTレコード申請書を作成
   - 会社のDNS管理部署に提出

### フェーズ2: DNS登録確認（申請後14日目）

3. **DNS登録確認**
   ```bash
   # DNS TXTレコード確認
   nslookup -type=TXT gooid-21-prod-20250918-2._domainkey.goo.ne.jp
   ```

4. **DKIM検証テスト**
   ```bash
   # 新鍵でのDKIM署名テスト（本番適用前）
   aws sesv2 put-email-identity-dkim-signing-attributes \
     --email-identity goo.ne.jp \
     --signing-attributes-origin EXTERNAL \
     --signing-attributes DomainSigningSelector=gooid-21-prod-20250918-2,DomainSigningPrivateKey=（新しい秘密鍵）
   ```

### フェーズ3: 本番適用（DNS確認後）

5. **SES BYODKIM更新**
   ```bash
   # Phase 2 Lambda経由で安全にSES更新
   aws lambda invoke \
     --function-name aws-ses-migration-prod-dkim-manager-v2 \
     --payload '{"action": "update_ses_byodkim_automated", "confirmed_dns_ready": true}' \
     response.json
   ```

6. **切り替え確認**
   - テストメール送信
   - DKIM署名確認
   - 24時間監視

## 緊急ロールバック手順

**問題発生時**: 即座に旧鍵に戻す
```bash
# 旧鍵での緊急復旧
aws sesv2 put-email-identity-dkim-signing-attributes \
  --email-identity goo.ne.jp \
  --signing-attributes-origin EXTERNAL \
  --signing-attributes DomainSigningSelector=gooid-21-prod-20250904-1,DomainSigningPrivateKey=（旧秘密鍵）
```

## システム設定

### テンプレート設定
```yaml
# phase-3-ses-byodkim.yaml
EnableBYODKIMAutomation: "false"         # 自動化無効
BYODKIMRotationMode: "MANUAL"            # 手動制御
BYODKIMDNSConfirmationRequired: "true"   # DNS確認必須
```

### 安全性チェック

- ✅ DNS登録完了確認
- ✅ 旧鍵の保持（ロールバック用）
- ✅ 段階的テスト実施
- ✅ 24時間監視体制

## 年間ローテーション計画

| 月 | フェーズ1（鍵生成） | フェーズ2（DNS確認） | フェーズ3（本番適用） |
|----|-------------------|-------------------|-------------------|
| 4月 | 4/1 鍵生成・申請 | 4/15 DNS確認 | 4/16 本番適用 |
| 10月 | 10/1 鍵生成・申請 | 10/15 DNS確認 | 10/16 本番適用 |

**重要**: 自動化によるメール配信停止リスクを完全に回避し、安定した運用を維持します。
