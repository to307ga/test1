# POC環境へのアクセスツール

このリポジトリには、POC環境のGiteaおよびJenkinsサーバーへ安全にアクセスするためのスクリプトが含まれています。
Internalアクセスのみ許可したGiteaおよびJenkinsへのアクセスをSSMでトンネリングすることでインターネット経由でのアクセスを可能にしています。
WEB環境へのアクセスは主にzerospace端末等のWindows環境で実行することになると思うのですがLinux環境での利用（APIを叩くなど）も想定している為スクリプトはSHELLで記載しています。WindowsではGitBashを使った動作確認をしております。


## 📑 目次

- [POC環境へのアクセスツール](#poc環境へのアクセスツール)
  - [📑 目次](#-目次)
  - [📋 前提条件](#-前提条件)
  - [🔐 MFA認証](#-mfa認証)
    - [1. MFAトークン取得スクリプトの実行](#1-mfaトークン取得スクリプトの実行)
    - [2. 認証情報の適用](#2-認証情報の適用)
  - [🌐 Session Manager トンネリング](#-session-manager-トンネリング)
    - [HTTP over SSM（Webアクセス）](#http-over-ssmwebアクセス)
      - [Giteaへの接続](#giteaへの接続)
      - [Jenkinsへの接続](#jenkinsへの接続)
    - [SCP over SSM（ファイル転送）※ 参考](#scp-over-ssmファイル転送-参考)
  - [🌐 EC2への接続](#-ec2への接続)
    - [基本的な使い方](#基本的な使い方)
      - [パラメータ](#パラメータ)
    - [使用例](#使用例)
      - [POC環境への接続（デフォルト）](#poc環境への接続デフォルト)
      - [他の環境への接続](#他の環境への接続)
    - [仕組み](#仕組み)
    - [接続の終了](#接続の終了)
    - [トラブルシューティング](#トラブルシューティング)
      - [インスタンスが見つからない場合](#インスタンスが見つからない場合)
      - [SSMエージェントが応答しない場合](#ssmエージェントが応答しない場合)
  - [🔧 Session Manager Plugin インストール](#-session-manager-plugin-インストール)
    - [1. 事前準備済みファイル](#1-事前準備済みファイル)
    - [2. ポータブル設置](#2-ポータブル設置)
    - [3. PATH設定](#3-path設定)
    - [4. 動作確認](#4-動作確認)
  - [🚨 トラブルシューティング](#-トラブルシューティング)
    - [SSL証明書エラー](#ssl証明書エラー)
    - [MFA認証エラー](#mfa認証エラー)
    - [Session Manager Plugin未検出](#session-manager-plugin未検出)
    - [代替アクセス方法](#代替アクセス方法)
  - [📁 ファイル構成](#-ファイル構成)
  - [🔒 セキュリティ注意事項](#-セキュリティ注意事項)
  - [🤝 サポート](#-サポート)

## 📋 前提条件

- AWS CLI がインストールされていること
- MFAデバイスが設定されていること
- 適切なAWS認証情報が設定されていること（`dev` プロファイルにMFA情報が記載されていること）
  ```
  # ~/.aws/credentialsが以下の様な構成になっていることを想定しています devがidhubの開発環境用
  [default]
  aws_access_key_id = XXXXXXXXXXXX
  aws_secret_access_key = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

  [dev]
  aws_access_key_id = ●●●●●●●●●●●●●●●●●●●●●
  aws_secret_access_key = ●●●●●●●●●●●●●●●●●●●●●
  ```

- Session Manager Plugin インストールが完了していること(インストール方法については後述)

## 🔐 MFA認証

### 1. MFAトークン取得スクリプトの実行

POC環境へのアクセスには、まずMFA認証による一時的なAWS認証情報の取得が必要です。
シェルスクリプトのarn:aws:iam::910230630316:mfa/dev_toshimitsu.tomonaga.zd　の部分は適宜修正してください。
MFAトークンは12時間有効です。AIAgentが別のターミナルを開いたときにはコマンド実行時に表示される指示に従い aws_mfa_credentialsファイルをsourceコマンドで取り込んでください 

```bash
# MFAトークンコードを対話的に入力
./scripts/get_mfa_token_dev.sh

# または、コマンドライン引数で指定
./scripts/get_mfa_token_dev.sh 123456

# 上記コマンド実行時に出力される以下の様なメッセージに従いsourceコマンドを実行する
適用するには: source ./../aws_mfa_credentials

```

### 2. 認証情報の適用

スクリプト実行後、表示される認証情報を環境変数として設定：

```bash
# 自動保存されたファイルを読み込み
source aws_mfa_credentials

# または、表示されたexportコマンドを手動で実行
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
```

## 🌐 Session Manager トンネリング

### HTTP over SSM（Webアクセス）

#### Giteaへの接続
```bash
./scripts/connect-gitea.sh
```
- **ローカルアクセス**: http://localhost:8080
- **用途**: Git WebUI、リポジトリ管理

#### Jenkinsへの接続
```bash
./scripts/connect-jenkins.sh
```
- **ローカルアクセス**: http://localhost:8080
- **用途**: CI/CDパイプライン管理

### SCP over SSM（ファイル転送）※ 参考

EC2インスタンスとの直接ファイル転送：
SCPを使用するのでEC2側ではsshdを動かしておく必要があります
その為参考としての記述にとどめます。
SSMを使用したファイル転送については付録[AppendixFileTransferUsingSSM.md](./AppendixFileTransferUsingSSM.md)を参照してください。

```bash
# EC2インスタンスIDを取得（自動）
EC2_ID=$(aws ec2 describe-instances \
  --filters \
    "Name=tag:Environment,Values=poc" \
    "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --region ap-northeast-1 \
  --no-verify-ssl)

# ファイルをEC2へアップロード
aws ssm start-session \
  --target $EC2_ID \
  --document-name AWS-StartPortForwardingSession \
  --parameters "{\"portNumber\":[\"22\"],\"localPortNumber\":[\"2222\"]}" \
  --region ap-northeast-1 \
  --no-verify-ssl &

# 少し待機してからSCP実行
sleep 3
scp -P 2222 -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" \
  local-file.txt ec2-user@localhost:/home/ec2-user/

# ファイルをEC2からダウンロード
scp -P 2222 -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" \
  ec2-user@localhost:/home/ec2-user/remote-file.txt ./

# 接続終了
kill %1
```

## 🌐 EC2への接続

SSM Session Manager経由で任意のEC2インスタンスに直接接続できます。

### 基本的な使い方

```bash
./scripts/connect-ec2.sh <instance-name> [environment] [region]
```

#### パラメータ
- **instance-name** (必須): EC2インスタンスのNameタグ値
- **environment** (オプション): Environmentタグ値（デフォルト: `poc`）
- **region** (オプション): AWSリージョン（デフォルト: `ap-northeast-1`）

### 使用例

#### POC環境への接続（デフォルト）
```bash
# POC環境のpochub-001に接続
./scripts/connect-ec2.sh pochub-001

# 上記は以下と同じ
./scripts/connect-ec2.sh pochub-001 poc ap-northeast-1
```

#### 他の環境への接続
```bash
# dev環境への接続
./scripts/connect-ec2.sh web-server dev

# prod環境・別リージョンへの接続
./scripts/connect-ec2.sh app-server prod us-east-1
```

### 仕組み

このスクリプトは以下の手順で動作します：

1. 指定されたNameタグとEnvironmentタグでEC2インスタンスを検索
2. 実行中（running状態）のインスタンスのみを対象
3. インスタンスIDを取得
4. SSM Session Managerで接続開始

### 接続の終了

```bash
# セッションを終了するには
exit

# または Ctrl+D
```

### トラブルシューティング

#### インスタンスが見つからない場合
```
Error: Instance not found with the following criteria:
  Name: xxx
  Environment: xxx
  State: running
```

**対処法**:
- インスタンス名が正しいか確認
- インスタンスが実行中（running）か確認
- Environmentタグが正しいか確認
- AWSリージョンが正しいか確認

#### SSMエージェントが応答しない場合
- EC2インスタンスでSSMエージェントが起動しているか確認
- インスタンスに適切なIAMロール（`AmazonSSMManagedInstanceCore`）が付与されているか確認

## 🔧 Session Manager Plugin インストール

企業環境で管理者権限がない場合のポータブル版インストール方法：

### 1. 事前準備済みファイル

このリポジトリには既に `downloads/SessionManagerPlugin.zip` が含まれています。

### 2. ポータブル設置

```bash
# ツールディレクトリ作成
mkdir -p ~/Tools/session-manager-plugin

# プロジェクト内のSessionManagerPlugin.zipを解凍
unzip downloads/SessionManagerPlugin.zip -d ~/Tools/session-manager-plugin/

# package.zipをさらに解凍
cd ~/Tools/session-manager-plugin/SessionManagerPlugin
unzip -o package.zip
```

### 3. PATH設定

```bash
# 一時的な設定（現在のセッションのみ）
export PATH=$PATH:/c/Users/{ユーザー名}/Tools/session-manager-plugin/SessionManagerPlugin/bin

# 永続的な設定（推奨）
echo 'export PATH=$PATH:/c/Users/{ユーザー名}/Tools/session-manager-plugin/SessionManagerPlugin/bin' >> ~/.bashrc
source ~/.bashrc
```

### 4. 動作確認

```bash
session-manager-plugin
```

正常にインストールされていれば、以下のメッセージが表示されます：
```
The Session Manager plugin was installed successfully. Use the AWS CLI to start a session.
```

## 🚨 トラブルシューティング

### SSL証明書エラー
企業環境でSSL証明書エラーが発生する場合、すべてのAWS CLIコマンドに `--no-verify-ssl` オプションを追加済みです。

### MFA認証エラー
- MFAトークンの有効期限（30秒）内に入力してください
- 正しいMFAデバイスが設定されているか確認してください
- `dev` プロファイルが正しく設定されているか確認してください

### Session Manager Plugin未検出
- PATHが正しく設定されているか確認してください
- `session-manager-plugin.exe` の実行権限があることを確認してください
- 新しいターミナルセッションで再試行してください

### 代替アクセス方法
Session Manager Pluginが利用できない場合：
```bash
# 直接ALBのURLを確認
./scripts/connect-gitea-alternative.sh
./scripts/connect-jenkins-alternative.sh
```

## 📁 ファイル構成

```
├── README.md
├── aws_mfa_credentials          # MFA認証情報（自動生成）
├── downloads/
│   └── SessionManagerPlugin.zip # Session Manager Plugin（事前準備済み）
├── scripts/
│   ├── get_mfa_token_dev.sh     # MFA認証スクリプト
│   ├── connect-gitea.sh         # Gitea接続スクリプト
│   ├── connect-jenkins.sh       # Jenkins接続スクリプト
│   ├── connect-all.sh           # 一括接続スクリプト
│   ├── connect-gitea-alternative.sh    # Gitea代替アクセス
│   └── connect-jenkins-alternative.sh  # Jenkins代替アクセス
├── pyproject.toml
└── uv.toml
```

## 🔒 セキュリティ注意事項

- MFA認証情報は一時的なものです（1時間で期限切れ）
- `aws_mfa_credentials` ファイルは機密情報を含むため、共有しないでください
- Session Managerセッションは使用後必ず終了してください（Ctrl+C）
- SSL検証無効化は企業環境の制約によるものです。本番環境では適切な証明書管理を行ってください

## 🤝 サポート

問題が発生した場合は、以下の情報とともにサポートチームに連絡してください：
- エラーメッセージの全文
- 実行したコマンド
- AWS CLI バージョン（`aws --version`）
- Session Manager Plugin バージョン（`session-manager-plugin`）
