# AWS MFA認証 - 3つの簡単な方法

MFA認証が面倒だったので、3つの方法を用意しました。お好みに合わせて選んでください。

## 🚀 方法1: 超高速ワンライナー（推奨）
**最も簡単！** MFAコードを指定するだけで一瞬でログイン完了

```bash
./mfa_quick.sh 123456
```

**特徴:**
- ✅ 1コマンドで完了
- ✅ エラーメッセージも親切
- ✅ 認証確認も自動
- ⚡ **所要時間: 3秒**

## 🛠️ 方法2: 丁寧なスクリプト
詳細な進捗表示とエラーハンドリングが欲しい場合

```bash
./mfa_simple.sh 123456
# または対話的に入力
./mfa_simple.sh
```

**特徴:**  
- ✅ 詳細な進捗表示
- ✅ 丁寧なエラーメッセージ
- ✅ 有効期限の表示
- 🕐 **所要時間: 5秒**

## 📋 方法3: 手動コピペ
スクリプトを信頼せず、手動でコントロールしたい場合

1. 認証情報取得:
```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
export AWS_PROFILE=prod
aws sts get-session-token --duration-seconds 43200 --serial-number "arn:aws:iam::007773581311:mfa/prod_toshimitsu.tomonaga.zd" --token-code 123456 --no-verify-ssl
```

2. 出力された値を手動で環境変数に設定:
```bash
export AWS_ACCESS_KEY_ID="ASIA..."  
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="IQoJ..."
unset AWS_PROFILE
```

**特徴:**
- ✅ 完全手動制御
- ✅ 何が起こっているか完全理解
- 🕐 **所要時間: 30秒**

## 🎯 推奨フロー

### 普段使い
```bash
./mfa_quick.sh 123456
```

### トラブル時
```bash  
./mfa_simple.sh 123456
```

### 認証後の作業
```bash
# CloudWatch
aws cloudwatch list-dashboards --no-verify-ssl

# Sceptre
cd sceptre && PYTHONHTTPSVERIFY=0 uv run sceptre status prod
```

## 💡 Tips

- **MFAコードの有効時間**: 30秒なので素早く入力
- **認証の有効期間**: 12時間（43200秒）
- **同時実行不可**: 既にセッションがある場合は自動でクリア
- **環境変数スコープ**: 現在のターミナルセッションのみ

## ❓ トラブルシューティング

### "MultiFactorAuthentication failed"
→ MFAコードが期限切れ。新しいコードで再実行

### "Cannot call GetSessionToken with session credentials"  
→ 既存セッションが残っている。スクリプトが自動でクリア

### SSL警告
→ 正常動作。`--no-verify-ssl`で企業ネットワーク対応済み

---

**結論: `./mfa_quick.sh 123456` が最も簡単です！**
