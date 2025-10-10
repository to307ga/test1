#!/bin/bash
# httpd mod_authn_otp の設定に必要なユーザーを作成する
#
# 使用方法:
# ./add_otpuser.sh [USERNAME] [PASSWORD]
#
PIN_FILE=/etc/httpd/otp/users.pin
TOKEN_FILE=/etc/httpd/otp/users.token

if [ $# -lt 1 ]; then
    echo "Usage: $0 [USERNAME] [PASSWORD]"
    echo "  USERNAME: 作成するユーザー名（必須）"
    echo "  PASSWORD: ユーザーのパスワード（省略可能、省略した場合はランダムに生成）"
    exit 1
fi
USERNAME=$1
PASSWORD=${2:-$(openssl rand -base64 6)}  # パスワードが指定されない場合はランダムに生成

# ファイルの存在and書き込み権限をチェック
if [ ! -w "$PIN_FILE" ]; then
    echo "Error: '$PIN_FILE' not found or not writable. "
    exit 1
fi
if [ ! -w "$TOKEN_FILE" ]; then
    echo "Error: '$TOKEN_FILE' not found or not writable. "
    exit 1
fi

# ユーザーがすでに存在するか確認
if grep -q "^$USERNAME:" $PIN_FILE; then
    echo "User $USERNAME already exists."
    exit 1
fi
if grep -qP "^\S+\s+$USERNAME\s" $TOKEN_FILE; then
    echo "User $USERNAME already exists."
    exit 1
fi

# パスワードを保存
htpasswd -b $PIN_FILE "$USERNAME" "$PASSWORD"

# OTPのURLを生成
OTP_OUTPUT=$(genotpurl -I "gooid/idhub" -L "$USERNAME" 2>&1)
# generated key (hex): から始まる行でトークンを抽出
TOKEN=$(echo "$OTP_OUTPUT" | grep "generated key (hex):" | cut -d: -f2 | tr -d ' ')
# otpauth://で始まる行でURLを抽出
OTP_URL=$(echo "$OTP_OUTPUT" | grep "^otpauth://")
# トークンを保存
echo "HOTP/T30 $USERNAME + $TOKEN" | sudo tee -a $TOKEN_FILE > /dev/null
# OTP URLからsecret値を抽出
SECRET=$(echo "$OTP_URL" | grep -oP 'secret=\K[^&]+')

# ユーザー表示
echo "認証ユーザーを作成しました"
echo "User: $USERNAME"
echo "Password: $PASSWORD"
echo ""
# echo "OTP URL: $OTP_URL"
echo "認証アプリへの登録は以下のQRコードまたは秘密鍵を利用してください"
echo "秘密鍵: $SECRET"

# QRコードをターミナルに表示
if command -v qrencode >/dev/null 2>&1; then
    echo "================================="
    qrencode "$OTP_URL" -t ansiutf8
else
    echo "qrencode command not found."
    echo "Use secret key to add it to your authenticator app."
fi

