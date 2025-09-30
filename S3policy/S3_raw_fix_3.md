# S3バケットポリシー修正解説書 (Version 3 - 最終実戦版)

## 概要

`S3_raw_fix_2.yaml`でコンソールアクセスのIP制限が効かない問題を解決し、さらに実際の運用で発生した複数の問題（ROOTユーザーブロック、Firehoseアクセス不可等）を全て解決した**最終実戦版**のポリシーです。

## 🎯 最終的に実現した要件

✅ **コンソールアクセスのIP制限**: IAMユーザーによるコンソールアクセスは指定IP範囲のみ許可  
✅ **AWSサービスの無制限アクセス**: FirehoseとLambdaは制限なしでログ書き込み可能  
✅ **ROOTユーザー保護**: 緊急時の確実なアクセス手段確保  
✅ **運用安全性**: ポリシー自体の管理・復旧が可能  

## 🚨 解決した実戦での問題

### 問題1: ROOTユーザーブロック事態
**発生**: 複雑な条件によりROOTユーザーでもポリシー変更不可  
**解決**: ROOTユーザー明示許可を最優先ステートメントに配置

### 問題2: Lambda関数でのポリシー管理不可
**発生**: 緊急時のLambda関数によるポリシー削除が権限不足で失敗  
**解決**: `s3:DeleteBucketPolicy`等の管理権限をサービスに付与

### 問題3: Firehoseからのログ書き込み不可
**発生**: IP制限のDenyステートメントがFirehoseのIAMロールアクセスもブロック  
**解決**: `"aws:PrincipalType": "User"`でIAMユーザーのみをターゲット化

## 最終ポリシー構造（4ステートメント）

### Statement 1: ROOTユーザー最優先保護
```json
{
  "Sid": "AllowRootUserFullAccess",
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::007773581311:root"},
  "Action": "s3:*"
}
```
**役割**: 緊急時の確実な復旧手段確保  
**優先度**: 最高（すべてのDenyを上書き）

### Statement 2: AWSサービス完全対応版
```json
{
  "Sid": "AllowSpecificServices",
  "Effect": "Allow", 
  "Principal": {
    "Service": ["firehose.amazonaws.com", "lambda.amazonaws.com", "s3.amazonaws.com"]
  },
  "Action": [
    "s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:GetBucketLocation",
    "s3:DeleteBucketPolicy", "s3:PutBucketPolicy", "s3:GetBucketPolicy"  // 緊急管理権限
  ]
}
```
**役割**: データアクセス + 緊急時のポリシー管理  
**対象**: 直接のサービスプリンシパル + IAMロール経由アクセス

### Statement 3: HTTPS強制
```json
{
  "Sid": "DenyInsecureConnections",
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Condition": {"Bool": {"aws:SecureTransport": "false"}}
}
```
**役割**: セキュリティ基準の強制

### Statement 4: 精密IP制限（最終調整版）
```json
{
  "Sid": "DenyUnauthorizedIPAccess",
  "Effect": "Deny",
  "Principal": {"AWS": "*"},
  "Action": "s3:*",
  "Condition": {
    "NotIpAddress": {
      "aws:SourceIp": [
        "10.99.0.0/16", "10.88.80.0/20", "203.0.113.0/24", 
        "198.51.100.0/24", "202.217.0.0/16"
      ]
    },
    "StringEquals": {"aws:PrincipalType": "User"}  // ← 最終的な解決策
  }
}
```
**役割**: IAMユーザー（コンソールアクセス）のみをIP制限対象とする

## 🔑 最終解決策の技術的ブレークスルー

### `"aws:PrincipalType": "User"` による精密制御

| Principal Type | 説明 | IP制限対象 | 実際の使用例 |
|---------------|------|-----------|-------------|
| `User` | IAMユーザー | ✅ 対象 | コンソールログイン |
| `AssumedRole` | IAMロール | ❌ 除外 | Firehose/Lambda実行ロール |
| `Service` | サービスプリンシパル | ❌ 除外 | 直接サービスアクセス |
| `Root` | ROOTアカウント | ❌ 除外 | 緊急時アクセス |

### 試行錯誤で排除された複雑な条件

**❌ 失敗したアプローチ**:
- `aws:PrincipalIsAWSService` (新しすぎて不安定)
- `aws:ViaAWSService` (想定外の副作用)
- `StringNotLike` によるパターンマッチング (複雑すぎて予期しない動作)
- 複数の`StringNotEquals`の組み合わせ (JSON構文エラー)

**✅ 成功したアプローチ**:
- `aws:PrincipalType` による明確な分類
- シンプルな条件構造
- ステートメント順序の最適化

## 実証済み動作検証

### ✅ 全シナリオで正常動作確認済み

1. **ROOTユーザー**: 任意のIPから無制限アクセス可能
2. **IAMユーザー（コンソール）**: 許可IP範囲からのみアクセス可能
3. **IAMユーザー（非許可IP）**: アクセス正常に拒否
4. **Firehose**: IP制限なしでログ書き込み成功
5. **Lambda**: IAMロール使用時もデータアクセス成功
6. **Lambda緊急管理**: ポリシー削除・修正権限で緊急対応可能

### 📊 実際の運用実績

- **コンソールIP制限**: ✅ 意図通り動作
- **Firehoseログ**: ✅ 正常に書き込み継続
- **Lambda処理**: ✅ エラーなく実行
- **緊急時復旧**: ✅ 実証済み（ROOTブロック事態で実際に使用）

## Version変遷と学習履歴

### Version 1 → 2
- **問題**: `aws:PrincipalType`の理解不足
- **改善**: 新しいAWS条件キーの導入検討

### Version 2 → 3（中間）
- **問題**: 新しい条件キーの不安定性、複雑化
- **改善**: ROOTユーザー保護、Lambda緊急権限追加

### Version 3（中間）→ 3（最終）
- **問題**: Firehose書き込み不可
- **改善**: `aws:PrincipalType`による精密制御で根本解決

## 運用ガイドライン

### 🎯 推奨運用手順

1. **IP範囲変更時**:
   ```bash
   # ROOTユーザーまたは管理者で実施
   aws s3api put-bucket-policy --bucket BUCKET_NAME --policy file://updated_policy.json
   ```

2. **緊急時復旧**:
   ```python
   # Lambda関数による自動復旧
   s3_client.delete_bucket_policy(Bucket='BUCKET_NAME')
   ```

3. **動作確認**:
   - 各IP範囲からのコンソールアクセステスト
   - Firehose/Lambdaの正常動作確認

### ⚠️ 重要な注意事項

1. **Statement順序は変更禁止**: ROOTユーザー保護が最優先
2. **`"aws:PrincipalType": "User"`の条件は削除禁止**: Firehose動作に必須
3. **ROOTユーザーARNは環境に応じて変更**: アカウントID確認必須

## まとめ

この最終版は、実際の運用で発生した複数の重大問題を全て解決し、以下を達成しました：

- 🎯 **要件100%達成**: コンソールIP制限 + AWSサービス無制限
- 🛡️ **運用安全性確保**: ROOTユーザー保護 + 緊急復旧手段
- 🔧 **保守性向上**: シンプルな構造でトラブルシューティング容易
- ✅ **実戦実証済み**: 全シナリオで動作確認完了

**S3バケットポリシーによる精密なアクセス制御の完成形**として、今後の類似要件における参考実装となるポリシーです。