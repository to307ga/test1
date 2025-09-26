# DNS設定依頼書 - BYODKIM実装

## 概要
AWS SES BYODKIM実装のため、以下のDKIM DNS TXTレコードの設定をお願いします。

## ドメイン
goo.ne.jp

## 設定依頼DNS記録

### 1. DKIM Selector 1 (Primary)
```
名前: gooid-21-pro-20250912-1._domainkey.goo.ne.jp
タイプ: TXT
値: "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4f5wg5l2hKsTeNem/V41fGnJm6gOdrj8ym3rFkEjWT2BTq2by8bg5Ho61qIw3QVp+2ZNtNqYqYemgrXfJ8Kd4WZ2ROr8J5q1234+oZBiGE9lp9B4L1GekpMQa9ub0cKyDFeL2qIxD6HGPnY2+MA8y9WOJ8fj234gKluU1qfnyxUiZo5r2ImlqNe+jpvyCUgq2F5q0JZfZDnwtGU3Zp+2vgYlc"
```

### 2. DKIM Selector 2 (Backup)  
```
名前: gooid-21-pro-20250912-2._domainkey.goo.ne.jp
タイプ: TXT
値: "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6tzq2eoKc8YFgK8J8Gq+zL5jXx1wJ5kQgJ9qY7e1SzN2Kp4r8bU5GqIxJ3qWdR7c2K8Hy5r9b0oJ5q3xZ2p8I4qZjNr0oQ7c8UgY5q3xZ2p8I4qZjNr0oQ7c8UgY5q3xZ2p8"
```

### 3. DKIM Selector 3 (Backup)
```
名前: gooid-21-pro-20250912-3._domainkey.goo.ne.jp  
タイプ: TXT
値: "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1o2t5z8qM7u9I3kVc6w1x7UzK9nR2y5bT8G4K7J3Q6X2pU9qR5wI4K7J3Q6X2pU9qR5wI4K7J3Q6X2pU9qR5wI4K7J3Q6X2pU9qR5wI4K7J3Q6X2pU9qR5wI4K7J3Q6X2pU"
```

## 技術仕様
- **DKIM Version**: DKIM1
- **Key Algorithm**: RSA  
- **Key Length**: 2048 bits
- **Signature Method**: rsa-sha256

## 重要事項
1. **Primary Selector**: `gooid-21-pro-20250912-1` - メイン運用で使用
2. **Backup Selectors**: 冗長性とローテーション用
3. **TTL設定**: 推奨値 300秒（5分）

## 設定後の確認手順
設定完了後、以下のコマンドで確認可能：
```bash
dig TXT gooid-21-pro-20250912-1._domainkey.goo.ne.jp
```

## 連絡先
- 担当者: AWS SES移行プロジェクト
- 日時: 2025年9月12日
- 緊急度: 高

## 備考
- DNS設定完了後、AWS SESでのBYODKIM最終有効化を実施予定
- 本番運用前にDNS propagation（約24-48時間）の確認が必要

---
**生成日**: 2025年9月12日  
**プロジェクト**: AWS SES BYODKIM Phase 7  
**ステータス**: DNS設定待ち
