# AWS MFA 簡単ログイン - ワンライナー集

## Bash版（Linux/macOS/Git Bash）
```bash
# 使用方法: MFAコードを123456に置き換えて実行
export AWS_PROFILE=prod && TEMP=$(aws sts get-session-token --duration-seconds 43200 --serial-number "arn:aws:iam::007773581311:mfa/prod_toshimitsu.tomonaga.zd" --token-code 123456 --no-verify-ssl) && export AWS_ACCESS_KEY_ID=$(echo $TEMP | jq -r '.Credentials.AccessKeyId') && export AWS_SECRET_ACCESS_KEY=$(echo $TEMP | jq -r '.Credentials.SecretAccessKey') && export AWS_SESSION_TOKEN=$(echo $TEMP | jq -r '.Credentials.SessionToken') && unset AWS_PROFILE && echo "✅ MFA認証完了" && aws sts get-caller-identity --no-verify-ssl
```

## PowerShell版（Windows）
```powershell
# 使用方法: MFAコードを123456に置き換えて実行  
$env:AWS_PROFILE="prod"; $temp=aws sts get-session-token --duration-seconds 43200 --serial-number "arn:aws:iam::007773581311:mfa/prod_toshimitsu.tomonaga.zd" --token-code 123456 --no-verify-ssl | ConvertFrom-Json; $env:AWS_ACCESS_KEY_ID=$temp.Credentials.AccessKeyId; $env:AWS_SECRET_ACCESS_KEY=$temp.Credentials.SecretAccessKey; $env:AWS_SESSION_TOKEN=$temp.Credentials.SessionToken; $env:AWS_PROFILE=$null; Write-Host "✅ MFA認証完了" -ForegroundColor Green; aws sts get-caller-identity --no-verify-ssl
```

## 最短版（bash - jq不要）
```bash
# jqがない環境向け - 手動で環境変数設定が必要
export AWS_PROFILE=prod && aws sts get-session-token --duration-seconds 43200 --serial-number "arn:aws:iam::007773581311:mfa/prod_toshimitsu.tomonaga.zd" --token-code 123456 --no-verify-ssl
```

## 使用方法の選択肢

### 1. 最も簡単：ワンライナー
- MFAコード部分（123456）を実際のコードに置き換えてコピペ実行
- 1回の操作で認証完了

### 2. スクリプトファイル実行
```bash
# Bash版
chmod +x mfa_login.sh
./mfa_login.sh 123456

# PowerShell版  
.\mfa_login.ps1 123456
```

### 3. 対話型実行
```bash
# MFAコードの入力を求められる
./mfa_login.sh
.\mfa_login.ps1
```

## 認証後の使用例
```bash
# CloudWatch
aws cloudwatch list-dashboards --no-verify-ssl

# Sceptre（Bash）
cd sceptre && PYTHONHTTPSVERIFY=0 uv run sceptre status prod

# Sceptre（PowerShell）
cd sceptre; $env:PYTHONHTTPSVERIFY=0; uv run sceptre status prod
```
