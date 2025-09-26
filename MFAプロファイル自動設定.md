# AWS STS GetSessionToken方式によるMFA認証手順書

## 概要

この手順書では、AWS STS の `GetSessionToken` API を使用してMFA認証を行い、MFA強制ポリシー下でのAPI操作を可能にする方法を説明します。

## 背景・問題

### 現在の状況
- IAMユーザー `toshimitsu.tomonaga.zd` にMFA強制ポリシーが適用
- Access Key による直接API呼び出しが全て拒否される
- エラー: `explicit deny in an identity-based policy`

### AWS公式の解決方法
AWS公式ドキュメント「Scenario: MFA protection for access to API operations in the current account」に従い、`GetSessionToken` を使用して一時認証情報を取得します。

## 前提条件

- AWS CLI がインストール済み
- MFAデバイス（Google Authenticator等）が設定済み
- `prod` プロファイルが設定済み
- MFAデバイスのシリアル番号: `arn:aws:iam::007773581311:mfa/prod_toshimitsu.tomonaga.zd`

## 手順

### Step 1: GetSessionToken による一時認証情報取得

#### 1.1 基本コマンド
```bash
# prodプロファイルに設定
export AWS_PROFILE=prod

# GetSessionToken でMFA認証実行
aws sts get-session-token \
    --duration-seconds 43200 \
    --serial-number "arn:aws:iam::007773581311:mfa/prod_toshimitsu.tomonaga.zd" \
    --token-code 123456 \
    --no-verify-ssl
```

**パラメータ説明:**
- `duration-seconds`: 43200秒（12時間）の有効期限
- `serial-number`: MFAデバイスのARN
- `token-code`: MFAアプリから取得した6桁のコード
- `no-verify-ssl`: 企業ネットワーク環境対応

#### 1.2 期待される出力
```json
{
    "Credentials": {
        "AccessKeyId": "ASIAXXXXXXXXXXXXXXXX",
        "SecretAccessKey": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
        "SessionToken": "IQoJb3JpZ2luX2VjE...(長いトークン文字列)",
        "Expiration": "2025-09-26T26:00:00+00:00"
    }
}
```

### Step 2: 一時認証情報の環境変数設定

#### 2.1 手動設定
```bash
# Step 1 の出力から以下の値を環境変数に設定
export AWS_ACCESS_KEY_ID="ASIAXXXXXXXXXXXXXXXX"
export AWS_SECRET_ACCESS_KEY="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
export AWS_SESSION_TOKEN="IQoJb3JpZ2luX2VjE..."

# プロファイル設定を削除（一時認証情報を優先）
unset AWS_PROFILE
```

#### 2.2 自動設定スクリプト
```bash
# 一時認証情報を自動で環境変数に設定するスクリプト
export AWS_PROFILE=prod

# GetSessionToken実行とパース（MFAコードは手動入力）
read -p "MFAコードを入力してください: " MFA_CODE

TEMP_CREDENTIALS=$(aws sts get-session-token \
    --duration-seconds 43200 \
    --serial-number "arn:aws:iam::007773581311:mfa/prod_toshimitsu.tomonaga.zd" \
    --token-code $MFA_CODE \
    --no-verify-ssl)

# JSON パースと環境変数設定
export AWS_ACCESS_KEY_ID=$(echo $TEMP_CREDENTIALS | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $TEMP_CREDENTIALS | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $TEMP_CREDENTIALS | jq -r '.Credentials.SessionToken')
unset AWS_PROFILE

echo "一時認証情報が設定されました（有効期限: 12時間）"
```

### Step 3: 動作確認

#### 3.1 認証情報確認
```bash
# 現在の認証情報確認
aws sts get-caller-identity --no-verify-ssl
```

**期待する出力:**
```json
{
    "UserId": "AIDAQDT2XN776YTY5MR5M:session-name",
    "Account": "007773581311",
    "Arn": "arn:aws:sts::007773581311:assumed-role/role-name/session-name"
}
```

#### 3.2 各種サービスアクセステスト
```bash
# CloudWatch アクセス
aws cloudwatch list-dashboards --region ap-northeast-1 --no-verify-ssl

# S3 アクセス
aws s3 ls --no-verify-ssl

# CloudFormation アクセス
aws cloudformation list-stacks --region ap-northeast-1 --no-verify-ssl
```

### Step 4: Sceptre での使用

#### 4.1 基本的な使用方法
```bash
# 一時認証情報設定後、通常通り Sceptre 実行
cd sceptre
uv run sceptre status prod
uv run sceptre list outputs prod
uv run sceptre launch prod/phase-8-monitoring --yes
```

#### 4.2 認証情報の有効性確認
```bash
# Sceptre実行前の認証確認
aws sts get-caller-identity --no-verify-ssl

# エラーが出た場合は Step 1-2 を再実行
```

## 日常運用パターン

### 朝の作業開始時
```bash
# 1. MFA認証で一時認証情報取得
export AWS_PROFILE=prod
aws sts get-session-token \
    --duration-seconds 43200 \
    --serial-number "arn:aws:iam::007773581311:mfa/prod_toshimitsu.tomonaga.zd" \
    --token-code [MFAコード] \
    --no-verify-ssl

# 2. 環境変数設定（出力をコピペ）
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
unset AWS_PROFILE

# 3. 以降12時間は通常作業可能
aws cloudwatch list-dashboards --region ap-northeast-1 --no-verify-ssl
cd sceptre
uv run sceptre status prod
```

### セッション期限切れ時
```bash
# 12時間経過後、認証情報をクリアして再取得
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

# Step 1-2 を再実行
```

## トラブルシューティング

### 問題1: GetSessionToken が失敗する
**症状:** `MultiFactorAuthentication failed with invalid MFA one time pass code`

**対処法:**
1. MFAコードのタイミング確認（30秒で更新）
2. スマートフォンの時刻同期確認
3. 新しいMFAコードで再実行

### 問題2: 一時認証情報の設定エラー
**症状:** `Unable to locate credentials`

**対処法:**
```bash
# 環境変数確認
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY
echo $AWS_SESSION_TOKEN

# プロファイル設定削除確認
echo $AWS_PROFILE  # 空であること
```

### 問題3: SSL証明書エラー
**症状:** `SSL: CERTIFICATE_VERIFY_FAILED`

**対処法:**
```bash
# 全コマンドに --no-verify-ssl フラグを追加
# または環境変数で無効化
export AWS_CA_BUNDLE=""
```

## セキュリティベストプラクティス

1. **一時認証情報の適切な管理**: 12時間後の自動期限切れ
2. **MFAコードの使い回し禁止**: 各認証で新しいコードを使用
3. **作業完了後のクリーンアップ**: 環境変数の明示的削除
4. **最小権限の原則**: 必要な操作のみ実行

## まとめ

この方式により、MFA強制ポリシー下でも以下が実現されます:
- **一時的なフルアクセス**: 12時間有効な管理者権限
- **セキュリティ維持**: MFA認証必須
- **運用効率**: 認証後は通常のAWS CLI/Sceptre操作が可能
- **AWS公式準拠**: ドキュメント化されたベストプラクティス


## スクリプト化

cd c:/Temp/AWS_SES_BYODKIM && ./mfa_quick.sh 123456[MFAツールの値]

## 確認方法

aws configure list

```
$ aws configure list
      Name                    Value             Type    Location
      ----                    -----             ----    --------
   profile                <not set>             None    None
access_key     ****************CZUT shared-credentials-file
secret_key     ****************UAS9 shared-credentials-file
    region           ap-northeast-1      config-file    ~/.aws/config

```
profileが以下の様に切り替わっていればOK	
profile                <not set>	# default  nttdocomo-iam-tomonaga　IAMで作成したアクセスキーを使用	まもなく削除予定
profile                prod			# prod のアクセスキー
profile                dev 			# dev のアクセスキー



