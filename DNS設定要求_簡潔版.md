# DNS設定要求（簡潔版）

**依頼日**: 2025年09月12日
**対象**: goo.ne.jp ドメイン
**目的**: AWS SES BYODKIM設定

## 設定内容

**TXTレコード追加**:
```
名前: gooid-21-pro-20250912-1._domainkey.goo.ne.jp
タイプ: TXT
値: v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4f5wg5l2hKsTeNem/V41fGnJm6gOdrj8ym3rFkEjWT2BTq2by8bg5Ho61qIw3QVp+2ZNtNqYqYemgrXfJ8Kd4WZ2ROr8J5q1234+oZBiGE9lp9B4L1GekpMQa9ub0cKyDFeL2qIxD6HGPnY2+MA8y9WOJ8fj234gKluU1qfnyxUiZo5r2ImlqNe+jpvyCUgq2F5q0JZfZDnwtGU3Zp+2vgYlc
TTL: 3600
```

**緊急度**: 中（本番稼働に必要）
**連絡先**: AWS SES移行プロジェクトチーム
**設定完了通知**: 必要

---
設定完了後、AWS SES DKIM検証が自動的に完了し、メール送信が可能になります。
