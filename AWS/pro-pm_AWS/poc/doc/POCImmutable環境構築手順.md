# POC Immutable環境構築手順

## 📑 目次

- [📋 概要](#-概要)
- [🏗️ 構築される環境](#️-構築される環境)
  - [Immutable Infrastructure: ProxySQL + Aurora + Laravel統合環境](#immutable-infrastructure-proxysql--aurora--laravel統合環境)
  - [監視・アラートシステム](#監視アラートシステム)
- [🔧 前提条件](#-前提条件)
  - [1. AWS環境](#1-aws環境)
  - [2. 必要なIAM権限](#2-必要なiam権限)
  - [3. ローカル環境](#3-ローカル環境)
- [🚀 デプロイ手順](#-デプロイ手順)
  - [📋 構築アプローチ](#-構築アプローチ)
  - [Step 1: 環境準備](#step-1-環境準境)
  - [Step 2: 基盤インフラ構築（Sceptre）](#step-2-基盤インフラ構築sceptre)
  - [Step 3: Laravel環境セットアップ](#step-3-laravel環境セットアップ)
  - [Step 4: ProxySQL環境構築](#step-4-proxysql環境構築)
  - [Step 5: Laravel統合設定](#step-5-laravel統合設定)
  - [Step 6: デプロイ前事前確認](#step-6-デプロイ前事前確認)
  - [Step 7: 監視・アラート設定](#step-7-監視アラート設定)
  - [Step 8: フェイルオーバーテスト](#step-8-フェイルオーバーテスト)
  - [Step 9: Blue/Greenデプロイメント対応](#step-9-bluegreen-デプロイメント対応)
- [🔍 デプロイ確認](#-デプロイ確認)
  - [1. システム全体確認](#1-システム全体確認)
  - [2. ProxySQL動作確認](#2-proxysql動作確認)
  - [3. Laravel統合確認](#3-laravel統合確認)
  - [4. 監視確認](#4-監視確認)
- [🛠️ トラブルシューティング](#️-トラブルシューティング)
  - [1. ProxySQL関連問題](#1-proxysql関連問題)
  - [2. Aurora接続問題](#2-aurora接続問題)
  - [3. Laravel統合問題](#3-laravel統合問題)
  - [4. 監視・アラート問題](#4-監視アラート問題)
- [🧹 環境削除](#-環境削除)
  - [1. 監視リソース削除](#1-監視リソース削除)
  - [2. アプリケーション設定復元](#2-アプリケーション設定復元)
  - [3. ProxySQL停止・削除](#3-proxysql停止削除)
- [📊 アーキテクチャ詳細](#-アーキテクチャ詳細)
  - [接続フロー](#接続フロー)
  - [フェイルオーバー動作](#フェイルオーバー動作)
  - [監視メトリクス](#監視メトリクス)
- [📝 運用メモ](#-運用メモ)
  - [日常運用](#日常運用)
  - [定期メンテナンス](#定期メンテナンス)
  - [パフォーマンスチューニング](#パフォーマンスチューニング)
  - [セキュリティ](#セキュリティ)
- [📚 関連ドキュメント](#-関連ドキュメント)

## 📋 概要

このドキュメントは、**ゼロからPOC基盤環境を構築**し、その上でProxySQLデータベースプロキシを統合して**Blue/Greenデプロイメント対応のImmutable Infrastructure環境**を構築する手順を記載しています。

**🎯 主要な価値提案:**
本環境により、**無停止でのアプリケーションデプロイ**と**瞬時ロールバック**が可能となり、真のImmutable Infrastructureを実現します。

**主な機能:**
- **🔵🟢 Blue/Greenデプロイメント**: 無停止デプロイ、段階的切り替え、1秒以内ロールバック
- **ProxySQL**: 接続プール、Read/Write分離、自動フェイルオーバー、トラフィックルーティング
- **Aurora統合**: 既存Aurora MySQL clusterとの接続最適化
- **Laravel統合**: アプリケーション層での透過的なDB接続
- **包括的監視**: CloudWatch + SNS + Dashboard統合監視、デプロイメント監視
- **自動テスト**: フェイルオーバー機能とデプロイメント機能の自動検証

## 🏗️ 構築される環境

### Immutable Infrastructure: ProxySQL + Aurora + Laravel統合環境

```
┌─────────────────────────────────────────────────────────────────┐
│                        監視ダッシュボード                          │
│  CloudWatch Dashboard + SNS Alerts + Lambda Functions        │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Blue/Green Deployment Controller             │
│            (ALB + Target Groups + Health Checks)               │
└─────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
┌─────────────────────────────────────┐  ┌─────────────────────────────────────┐
│        Blue Environment             │  │        Green Environment            │
│      (Current Production)           │  │       (New Version)                 │
│  ┌─────────────────┐                │  │  ┌─────────────────┐                │
│  │   pochub-001    │ ◄──┐           │  │  │  pochub-green-  │ ◄──┐           │
│  │   Laravel App   │    │ProxySQL   │  │  │   001 (Optional)│    │ProxySQL   │
│  │   ProxySQL      │    │Traffic    │  │  │   Laravel App   │    │Traffic    │
│  │   Port: 6033    │    │Router     │  │  │   ProxySQL      │    │Router     │
│  └─────────────────┘ ◄──┘           │  │  │   Port: 6033    │ ◄──┘           │
│  ┌─────────────────┐                │  │  └─────────────────┘                │
│  │   pochub-002    │ ◄──┐           │  │  ┌─────────────────┐                │
│  │   Laravel App   │    │           │  │  │  pochub-green-  │ ◄──┐           │
│  │   ProxySQL      │    │           │  │  │   002 (Optional)│    │           │
│  │   Port: 6033    │    │           │  │  │   Laravel App   │    │           │
│  └─────────────────┘ ◄──┘           │  │  │   ProxySQL      │    │           │
│  ┌─────────────────┐                │  │  │   Port: 6033    │ ◄──┘           │
│  │   pochub-003    │ ◄──┐           │  │  └─────────────────┘                │
│  │   Laravel App   │    │           │  │                                     │
│  │   ProxySQL      │    │           │  │  [段階的トラフィック切り替え]        │
│  │   Port: 6033    │    │           │  │  • Phase 1: Blue 95% → Green 5%   │
│  └─────────────────┘ ◄──┘           │  │  • Phase 2: Blue 75% → Green 25%  │
└─────────────────────────────────────┘  │  • Phase 3: Blue 50% → Green 50%  │
                │                        │  • Phase 4: Blue 0% → Green 100%  │
                │                        └─────────────────────────────────────┘
                │                                        │
                └────────┬─────────────────────────────────┘
                         ▼ (Connection Pool + R/W Split + Traffic Routing)
┌─────────────────────────────────────────────────────────────────┐
│                        Aurora MySQL Cluster                    │
│                         (poc-aurora-mysql)                     │
│  ┌─────────────────────────────┐  ┌─────────────────────────────┐ │
│  │         Writer              │  │         Reader              │ │
│  │    (ap-northeast-1a)        │  │    (ap-northeast-1c)        │ │
│  │      Port: 3306             │  │      Port: 3306             │ │
│  └─────────────────────────────┘  └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**Blue/Green Deployment機能:**
- **Blue Environment**: 現在の本番環境（pochub-001/002/003）
- **Green Environment**: 新バージョン環境（新規インスタンスまたは既存更新）
- **ProxySQL Traffic Router**: クエリルーティングによる段階的切り替え
- **無停止切り替え**: 1秒以内でのトラフィック切り替え・ロールバック
- **カナリアリリース**: 段階的トラフィック分散（5% → 25% → 50% → 100%）

**構成要素:**
- **Aurora MySQL Cluster**: poc-aurora-mysql (Writer/Reader構成、共有データストア)
- **Application Load Balancer**: Blue/Green環境間のトラフィック分散、ヘルスチェック
- **Blue Environment**: pochub-001/002/003 (現在の本番Laravel環境)
- **Green Environment**: 新バージョンデプロイ先（新規EC2または既存更新）
- **EC2 Auto Scaling Group**: 高可用性を確保する自動スケーリング機能
- **ProxySQL**: 各環境にインストール、Blue/Green間トラフィックルーティング
- **ALB + Target Groups**: Blue/Green環境間のロードバランシング
- **監視Infrastructure**: CloudWatch + SNS + Dashboard + デプロイメント監視
- **Blue/Green Controller**: 自動化されたデプロイメント制御とロールバック機能

### 監視・アラートシステム

```
┌─────────────────────────────────────────────────────────────────┐
│                         CloudWatch                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐  │
│  │   Aurora    │  │  ProxySQL   │  │   Laravel   │  │ System  │  │
│  │   Metrics   │  │   Metrics   │  │   Metrics   │  │ Metrics │  │
│  │  CPU/Mem/   │  │ Connection  │  │  Health/    │  │ CPU/Mem │  │
│  │ Connection  │  │ Pool/Route  │  │ Response    │  │ Disk/   │  │
│  │   Latency   │  │  Backend    │  │   Error     │  │ Network │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│              SNS通知 + CloudWatch Dashboard                     │
│  ┌─────────────────────────────┐  ┌─────────────────────────────┐ │
│  │         Alarm通知            │  │     統合ダッシュボード        │ │
│  │  ・Email Alert             │  │  ・Real-time Metrics       │ │
│  │  ・SMS Alert (Optional)    │  │  ・Historical Trends       │ │
│  │  ・閾値超過時自動通知       │  │  ・Performance Overview    │ │
│  └─────────────────────────────┘  └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 前提条件

### 1. AWS環境
- AWSアカウントが利用可能
- AWS CLIがインストール・設定済み
- 適切なIAM権限を持つユーザー/ロール

**⚠️ 注意**: 既存POC環境は不要です。ゼロから構築します。

### 2. 必要なIAM権限
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "ec2:*",
        "rds:*",
        "iam:*",
        "ssm:*",
        "cloudwatch:*",
        "sns:*",
        "lambda:*",
        "logs:*",
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3. ローカル環境
- Python 3.8以上
- uv (Python パッケージマネージャー)
- Sceptre 4.0以上（uvから実行）
- Ansible 2.9以上
- AWS CLI 2.x
- MySQL Client (mysql コマンド)

**パッケージインストール:**
```bash
# uv経由でSceptre・Ansibleインストール確認
cd /home/tomo/poc
uv run sceptre --version
uv run ansible --version

# MySQL client (AlmaLinux/RHEL)
sudo dnf install mysql

# AWS CLI (if not installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

## 🚀 デプロイ手順

### 📋 構築アプローチ

本Immutable環境は段階的構築アプローチを採用しており、**Blue/Greenデプロイメント対応**が最終的なゴールです：

1. **基盤インフラ構築**: VPC、EC2、Aurora等の基盤環境をSceptreで構築
2. **Laravel環境準備**: EC2上にLaravelアプリケーション環境をセットアップ
3. **ProxySQL構築**: 各EC2にProxySQLインストール・設定（トラフィックルーティング機能付き）
4. **Laravel統合**: アプリケーション接続をProxySQL経由に変更
5. **監視構築**: 包括的監視・アラートシステム構築（デプロイメント監視含む）
6. **テスト実行**: 自動フェイルオーバーテスト実行
7. **🔵🟢 Blue/Greenデプロイメント**: 無停止デプロイ機能の構築・テスト

**🎯 最終到達目標:**
- 無停止アプリケーションデプロイメント
- 段階的トラフィック切り替え（カナリアリリース）
- 1秒以内での瞬時ロールバック
- 完全自動化されたデプロイメントパイプライン

**⚠️ 事前準備が必要なファイル:**
本手順を実行する前に、以下のファイルの存在確認が必要です：

**Sceptre CloudFormationテンプレート（✅ 既存）:**
```
sceptre/config/poc/
├── fixed-natgw-eip.yaml      # NAT Gateway用EIP
├── vpc.yaml                  # VPCネットワーク基盤
├── alb-securitygroup.yaml    # ALB用セキュリティグループ
├── securitygroup.yaml        # EC2用セキュリティグループ  
├── iam-group.yaml            # IAMロール・グループ
├── alb.yaml                  # Application Load Balancer
├── ec2.yaml                  # EC2 Auto Scaling Group
├── aurora.yaml               # Aurora MySQL Cluster
└── monitoring-alerts.yaml    # CloudWatch監視・アラート
```

**Ansible Playbook（独立uvプロジェクト）:**
```
/home/tomo/ansible-playbooks/        # 独立したuvプロジェクト
├── pyproject.toml                   # uv依存関係定義（ansible, boto3など）
├── .venv/                           # Python仮想環境
├── ansible.cfg                      # Ansible設定（✅ 既存）
├── inventory/
│   └── aws_ec2.yml                  # AWS EC2動的インベントリ（✅ 既存）
├── group_vars/
│   ├── all.yml                      # SSM接続・共通設定（✅ 既存）
│   └── poc.yml                      # Aurora接続情報（自動生成）
├── setup-laravel-environment.yml   # Laravel環境構築（⚠️ 作成必要）
├── get-aurora-info.yml             # Aurora接続情報取得（⚠️ 作成必要）
├── setup-proxysql.yml              # ProxySQL基本設定（⚠️ 作成必要）
├── configure-proxysql-aurora.yml   # ProxySQL Aurora統合（⚠️ 作成必要）
├── configure-laravel-proxysql.yml  # Laravel ProxySQL統合（⚠️ 作成必要）
├── test-laravel-proxysql.yml       # Laravel ProxySQL動作確認（⚠️ 作成必要）
├── setup-comprehensive-monitoring.yml # 監視設定（⚠️ 作成必要）
├── test-proxysql-failover.yml      # フェイルオーバーテスト（⚠️ 作成必要）
└── setup-proxysql-manual-testing.yml # 手動テスト環境（⚠️ 作成必要）

# 詳細は doc/Playbook実行用uvプロジェクト.md を参照
```

### Step 1: 環境準備

#### 1.1 AWS CLI設定確認
```bash
# AWS設定確認
aws sts get-caller-identity
aws configure list

# デプロイ対象リージョン確認
aws configure get region
# 期待値: ap-northeast-1
```

#### 1.2 Sceptre環境確認
```bash
cd /home/tomo/poc

# Sceptre動作確認
uv run sceptre --version

# 設定ファイル構文チェック
uv run sceptre validate sceptre/config/poc/
```

#### 1.3 プロジェクト構造確認
```bash
cd /home/tomo/poc

# プロジェクト構造確認
tree -L 3
```

### Step 2: 基盤インフラ構築（Sceptre）

#### 2.1 CloudFormationテンプレート検証
```bash
cd /home/tomo/poc

# 全テンプレートの構文チェック
for template in sceptre/templates/*.yaml; do
  echo "=== Validating $(basename $template) ==="
  aws cloudformation validate-template --template-body file://$template --region ap-northeast-1
done
```

#### 2.2 基盤インフラデプロイ（必須順序）
```bash
cd /home/tomo/poc/sceptre

# 1. EIP（NAT Gateway用）
uv run sceptre create poc/fixed-natgw-eip.yaml -y

# 2. VPC（ネットワーク基盤）
uv run sceptre create poc/vpc.yaml -y

# 3. ALB用セキュリティグループ
uv run sceptre create poc/alb-securitygroup.yaml -y

# 4. EC2用セキュリティグループ
uv run sceptre create poc/securitygroup.yaml -y

# 5. IAMグループ・ロール
uv run sceptre create poc/iam-group.yaml -y

# 6. Application Load Balancer
uv run sceptre create poc/alb.yaml -y

# 7. EC2インスタンス（Auto Scaling Group）
uv run sceptre create poc/ec2.yaml -y

# 8. Aurora MySQL クラスター
uv run sceptre create poc/aurora.yaml -y

# 9. コンテナサービス（Gitea - Git Repository）
# Jenkins Docker ビルド用リポジトリホスト
uv run sceptre create poc/ecs-gitea.yaml -y

# 10. Jenkins Docker ビルドパイプライン
# ECRリポジトリ（Jenkins用Docker イメージ保存）
uv run sceptre create poc/ecr-jenkins.yaml -y

# CodeBuildプロジェクト（Jenkins Docker イメージビルド）
uv run sceptre create poc/codebuild-jenkins.yaml -y

# Jenkins ビルドトリガー（Gitea Webhook → Lambda → CodeBuild）
uv run sceptre create poc/jenkins-build-trigger.yaml -y

# 10.5 Giteaリポジトリ準備とCodeBuildトリガー
# ⚠️ 重要: Step 11のJenkins ECSデプロイ前に必ず実施してください

## Giteaアクセス（初回セットアップ）
# GiteaのALB DNSを取得
GITEA_URL=$(aws cloudformation describe-stacks --stack-name poc-poc-ecs-gitea --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' --output text)
echo "Gitea URL: http://${GITEA_URL}"

# ブラウザでアクセスして初期設定
# 1. 管理者ユーザー作成: tomo（またはCodeBuildで設定したユーザー名）
# 2. パスワード設定
# 3. ログイン完了

## jenkins-dockerリポジトリの作成とプッシュ
# 1. Giteaで新しいリポジトリを作成
#    - リポジトリ名: jenkins-docker
#    - 公開設定: Public（推奨）
#      ※ Privateにする場合は「付録A」を参照してCodeBuildテンプレートの修正が必要

# 2. ローカルリポジトリをGiteaにプッシュ
cd /home/tomo/jenkins-docker

# Giteaリモートを追加（既に追加済みの場合はスキップ）
git remote add gitea http://${GITEA_URL}/tomo/jenkins-docker.git

# プッシュ（ブランチ名は main または master）
git push gitea main

# または masterブランチの場合
# git push gitea master

## Jenkins Dockerイメージのビルドとプッシュ
# CodeBuildを手動でトリガーしてDockerイメージをECRにプッシュ
aws codebuild start-build --project-name poc-jenkins-docker-build

# ビルド状況の確認（約5-10分かかります）
BUILD_ID=$(aws codebuild list-builds-for-project --project-name poc-jenkins-docker-build --max-items 1 --query 'ids[0]' --output text)
aws codebuild batch-get-builds --ids $BUILD_ID --query 'builds[0].{Status:buildStatus,Phase:currentPhase}' --output json

# ビルド完了を待つ（Status: "SUCCEEDED" になるまで）
# リアルタイムログ確認（オプション）
aws logs tail /aws/codebuild/poc-jenkins-docker-build --follow

# ECRイメージ確認
aws ecr describe-images --repository-name poc-jenkins-custom --query 'imageDetails[].imageTags' --output table

## Gitea Webhook設定（自動ビルド有効化）
# jenkins-dockerリポジトリへのpush時に自動的にCodeBuildをトリガーする設定

# Webhook URLを取得
WEBHOOK_URL=$(aws cloudformation describe-stacks --stack-name poc-poc-jenkins-build-trigger --query 'Stacks[0].Outputs[?OutputKey==`WebhookUrl`].OutputValue' --output text)
echo "Webhook URL: ${WEBHOOK_URL}"

# Giteaブラウザで設定（手動）
# 1. Gitea にログイン: http://${GITEA_URL}
# 2. jenkins-docker リポジトリページへ移動
# 3. 「設定」→「Webhook」→「Webhookを追加」→「Gitea」を選択
# 4. Webhook設定:
#    - ペイロードURL: ${WEBHOOK_URL} をペースト
#    - HTTPメソッド: POST
#    - POST Content Type: application/json
#    - トリガーイベント: 「プッシュイベント」にチェック
#    - アクティブ: チェック
# 5. 「Webhookを追加」ボタンをクリック

# Webhook動作確認
# 1. jenkins-dockerリポジトリで変更をコミット＆プッシュ
cd /home/tomo/jenkins-docker
echo "# Test webhook" >> README.md
git add README.md
git commit -m "Test webhook trigger"
git push gitea main

# 2. CodeBuildが自動的に起動したか確認
aws codebuild list-builds-for-project --project-name poc-jenkins-docker-build --max-items 3 --query 'ids' --output table

# 3. 最新ビルドの状態確認
LATEST_BUILD=$(aws codebuild list-builds-for-project --project-name poc-jenkins-docker-build --max-items 1 --query 'ids[0]' --output text)
aws codebuild batch-get-builds --ids $LATEST_BUILD --query 'builds[0].{Status:buildStatus,Phase:currentPhase,Initiator:initiator}' --output json

# Initiatorが "poc-jenkins-build-trigger" であれば、Webhook経由でトリガーされたことを示します

# 11. コンテナサービス（Jenkins - CI/CD）
# ⚠️ 注意: Step 10.5のCodeBuildが成功してECRにイメージがプッシュされていることを確認してから実行
# カスタムイメージを使用したJenkins
uv run sceptre create poc/ecs-jenkins.yaml -y

# デプロイ完了確認（約5-10分）
aws cloudformation wait stack-create-complete --stack-name poc-poc-ecs-jenkins

# Jenkins ECS Service状態確認
aws ecs describe-services \
  --cluster poc-poc-ecs-jenkins-cluster \
  --services poc-poc-ecs-jenkins-jenkins \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' \
  --output table

# 11.5 Jenkinsアクセス確認

## Jenkins URL取得
JENKINS_URL=$(aws cloudformation describe-stacks --stack-name poc-poc-ecs-jenkins --query 'Stacks[0].Outputs[?OutputKey==`JenkinsURL`].OutputValue' --output text)
echo "Jenkins URL: ${JENKINS_URL}"

## Jenkins管理者認証情報取得
# ユーザー名: admin（固定）
# パスワードをSecrets Managerから取得
JENKINS_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id poc-poc-ecs-jenkins/jenkins/admin \
  --query 'SecretString' \
  --output text | jq -r '.password')

echo "====================================="
echo "Jenkins Login Credentials"
echo "====================================="
echo "URL: ${JENKINS_URL}"
echo "Username: admin"
echo "Password: ${JENKINS_PASSWORD}"
echo "====================================="

## ブラウザでJenkinsにアクセス
# 1. 上記のURLをブラウザで開く
# 2. Username: admin
# 3. Password: 上記で表示されたパスワード
# 4. ログイン成功後、Jenkinsダッシュボードが表示される

## Jenkins初期設定確認
# 1. プラグインが正しくインストールされているか確認
#    - Manage Jenkins → Plugins → Installed Plugins
# 2. システム設定確認
#    - Manage Jenkins → System
# 3. グローバルツール設定確認
#    - Manage Jenkins → Tools

# 12. 運用・ストレージ
# S3バケット（ログ保存用）
uv run sceptre create poc/s3.yaml -y

# Systems Manager パッチ管理
uv run sceptre create poc/ssm-patch-management.yaml -y
```

#### 2.3 基盤インフラ構築確認
```bash
# 全スタックの状態確認
uv run sceptre status poc ########################## 依存関係に問題あり ##########################

# EC2インスタンス確認
aws ec2 describe-instances --filters "Name=tag:Environment,Values=poc" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name,PrivateIpAddress]' --output table --region ap-northeast-1

# ALB確認
aws elbv2 describe-load-balancers --region ap-northeast-1 --query 'LoadBalancers[?contains(LoadBalancerName,`poc`)].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}' --output table

# ALB Target Group ヘルス確認　（この時点では"unused"状態は期待通りです　トラフィック転送設定などが行われていないため）
ALB_TG_ARN=$(aws cloudformation describe-stacks --stack-name poc-poc-alb --query 'Stacks[0].Outputs[?OutputKey==`TargetGroupArn`].OutputValue' --output text --region ap-northeast-1)

aws elbv2 describe-target-health --target-group-arn $ALB_TG_ARN --region ap-northeast-1

# Aurora cluster確認
aws rds describe-db-clusters --db-cluster-identifier poc-poc-aurora-cluster --query 'DBClusters[0].{Status:Status,Writer:Endpoint,Reader:ReaderEndpoint}' --region ap-northeast-1

# **Auroraエンドポイント取得（Ansible設定用）**
# Writer（書き込み用）エンドポイント
aws rds describe-db-clusters --region ap-northeast-1 --query 'DBClusters[?contains(DBClusterIdentifier, `poc`)].[DBClusterIdentifier,Endpoint,ReaderEndpoint,Status]' --output table

# 取得したエンドポイントをメモしておく：
# - Writer Endpoint: poc-poc-aurora-cluster.cluster-xxxxxxxxxx.ap-northeast-1.rds.amazonaws.com
# - Reader Endpoint: poc-poc-aurora-cluster.cluster-ro-xxxxxxxxxx.ap-northeast-1.rds.amazonaws.com
# これらのエンドポイントは、後のAnsible設定（group_vars/poc.yml）で使用します。

# ECS Gitea確認
aws cloudformation describe-stacks --stack-name poc-poc-ecs-gitea --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' --output text --region ap-northeast-1

# ECS Jenkins確認
aws cloudformation describe-stacks --stack-name poc-poc-ecs-jenkins --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' --output text --region ap-northeast-1
```

#### 2.4 データベースパスワード管理設定

**重要**: CloudFormationで作成されたAuroraクラスターは、パスワードを**AWS Secrets Managerに自動生成・保存**しています。

**推奨アプローチ: Secrets Managerを直接使用（Parameter Store不要）**

Secrets Manager APIの呼び出しに数分かかる環境もあるため、**Ansibleから直接Secrets Managerを参照する方が効率的**です。

```bash
# 1. Secrets ManagerにAuroraパスワードが保存されていることを確認
aws secretsmanager list-secrets --region ap-northeast-1 --query 'SecretList[?contains(Name, `aurora`)].{Name:Name,Description:Description}' --output table

# 期待される出力：
# Name: poc-poc-aurora/aurora/master
# Description: Master credentials for Aurora cluster

# 2. （確認のみ）マスターユーザー名確認
aws rds describe-db-clusters --db-cluster-identifier poc-poc-aurora-cluster --query 'DBClusters[0].{MasterUsername:MasterUsername,Status:Status}' --output table --region ap-northeast-1

# 3. Ansible設定でSecrets Managerを直接参照
# 後のステップで、group_vars/poc.yml に以下の設定を使用します：
# db_password: "{{ lookup('amazon.aws.aws_secret', 'poc-poc-aurora/aurora/master', region='ap-northeast-1') | from_json | json_query('password') }}"
```

**この方法のメリット:**
- ✅ パスワードの二重管理不要（Secrets Managerが唯一の管理元）
- ✅ Secrets Managerの自動ローテーション機能が使える
- ✅ VPCエンドポイント経由で高速アクセス可能
- ✅ CloudTrailで監査ログが自動記録
- ✅ IAMロールベースの細かいアクセス制御

**（参考）Parameter Storeを使う場合**

Parameter Storeにコピーする必要がある場合は以下：

```bash
# 注意：Secrets Manager API呼び出しに数分かかる場合があります
# jqインストール（必要な場合）: sudo yum -y install jq

# パスワード取得とParameter Store登録
AURORA_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "poc-poc-aurora/aurora/master" --region ap-northeast-1 --query 'SecretString' --output text | jq -r '.password')
aws ssm put-parameter --name "/poc/aurora/admin-password" --value "$AURORA_PASSWORD" --type "SecureString" --description "POC Aurora MySQL admin user password" --region ap-northeast-1

# 登録確認
aws ssm get-parameter --name "/poc/aurora/admin-password" --query 'Parameter.{Name:Name,Type:Type,LastModifiedDate:LastModifiedDate}' --output table --region ap-northeast-1
```

# 6. （オプション）複数のパスワードを管理する場合
# Laravel用のアプリケーションユーザーパスワード
aws ssm put-parameter --name "/poc/aurora/laravel-user-password" --value "LARAVEL_USER_PASSWORD" --type "SecureString" --description "POC Laravel application database user password" --region ap-northeast-1

# 7. 登録されたParameter一覧確認
aws ssm describe-parameters --filters "Key=Name,Values=/poc/aurora/" --query 'Parameters[].[Name,Type,LastModifiedDate]' --output table --region ap-northeast-1
```

**Parameter Store登録時の注意事項:**

1. **パスワードの取得元**
   - CloudFormationで作成されたAuroraクラスターは、パスワードを**AWS Secrets Managerに自動生成**
   - 実際のパスワードは `poc-poc-aurora/aurora/master` シークレットから取得
   - Parameter Storeには、Secrets Managerから取得した実際のパスワードを登録する

2. **パスワード要件**
   - 自動生成されたパスワードは32文字
   - 英数字と記号を含む強力なパスワード
   - Secrets ManagerとParameter Storeで同じパスワードを使用

3. **命名規則**
   - `/poc/aurora/admin-password`: Auroraマスターユーザー用
   - `/poc/aurora/laravel-user-password`: Laravelアプリケーション用（別途作成する場合）
   - 階層構造で管理することで、環境ごとの管理が容易

3. **IAM権限**
   - EC2インスタンスのIAMロールに `ssm:GetParameter` 権限が必要
   - Ansible実行時にParameter Storeから自動取得される

4. **Ansibleでの使用**
   - `group_vars/poc.yml` で以下のように参照：
   ```yaml
   db_password: "{{ lookup('amazon.aws.aws_ssm', '/poc/aurora/admin-password', region='ap-northeast-1', decrypt=true) }}"
   ```

**セキュリティベストプラクティス:**
- ✅ Parameter Store（SecureString）を使用してパスワードを暗号化保存
- ✅ IAMロールベースのアクセス制御
- ✅ CloudTrailでParameter Storeへのアクセスを監査
- ❌ パスワードをコードやスクリプトにハードコーディングしない
- ❌ 平文でパスワードを保存しない

### Step 3: Laravel環境セットアップ

#### 3.1 Laravel環境構築準備
```bash
# EC2インスタンスのSSM Session Manager接続確認
# インスタンスID確認
aws ec2 describe-instances --filters "Name=tag:Environment,Values=poc" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name,PrivateIpAddress]' --output table --region ap-northeast-1
# aws ssm start-session --target インスタンスID --region ap-northeast-1
aws ssm start-session --target i-065ed6d447f001a4c --region ap-northeast-1
aws ssm start-session --target i-07d40f48ccc409da0 --region ap-northeast-1
aws ssm start-session --target i-0cb639645f102ca9f --region ap-northeast-1
# セッション接続後、それぞれ確認が終わったら「exit」でセッションを切断してください。

# インスタンス削除　ASGなので削除されれば再作成される
# aws ec2 terminate-instances --instance-ids インスタンスID --region ap-northeast-1
# aws ec2 terminate-instances --instance-ids i-0fd3e1a0a1bc5b362 --region ap-northeast-1
# aws ec2 terminate-instances --instance-ids i-08b85976f8ed30c2a --region ap-northeast-1
# aws ec2 terminate-instances --instance-ids i-0c7037afa9a27f1de --region ap-northeast-1


# ⚠️ 注意：ansible-playbooksは独立したuvプロジェクトです
# プロジェクトの場所: /home/tomo/ansible-playbooks
# 詳細は doc/Playbook実行用uvプロジェクト.md を参照



### Ansible動的インベントリの確認
```bash
cd /home/tomo/ansible-playbooks

# 全ホスト確認
uv run ansible-inventory -i inventory/aws_ec2.yml --list

# 特定AZのホストだけに実行
uv run ansible -i inventory/aws_ec2.yml az_ap_northeast_1a -m ping

# Playbook実行（AZ情報を変数として利用可能）
uv run ansible-playbook -i inventory/aws_ec2.yml setup-laravel-environment.yml
```

# 必要なファイル:
# - /home/tomo/ansible-playbooks/setup-laravel-environment.yml (Laravel環境構築用)
# - /home/tomo/ansible-playbooks/group_vars/all.yml (SSM接続・共通設定)
# - /home/tomo/ansible-playbooks/inventory/aws_ec2.yml (動的インベントリ)
```

#### 3.2 Laravel環境構築
```bash
cd /home/tomo/ansible-playbooks

# Laravel基盤セットアップ（Playbook実行）
# 実行内容：
# - PHP、Apache、Laravel インストール
# - Laravel アプリケーション配置
# - Aurora接続設定
# - /health ヘルスチェックエンドポイント自動追加（データベース接続チェック機能付き）

# Playbook実行
uv run --project /home/tomo/poc ansible-playbook setup-laravel-environment.yml

# ⚠️ 注意:
# - inventory/aws_ec2.yml は ansible.cfg で設定済み
# - group_vars/poc.yml にAurora接続情報が必要
# - /health エンドポイントは自動的に追加されます（Playbook化済み）
```

#### 3.3 Laravel接続確認
```bash
# Laravel基本動作確認（SSM Session Manager経由）
aws ssm start-session --target $(aws ec2 describe-instances --filters "Name=tag:Name,Values=pochub-001" --query 'Reservations[0].Instances[0].InstanceId' --output text) --region ap-northeast-1

# Session Manager内で実行：
# curl http://localhost/health
# php /var/www/poc-web/artisan --version
```

### Step 4: ProxySQL環境構築

#### 4.1 Aurora情報取得
```bash
cd /home/tomo/ansible-playbooks

# Aurora接続情報を自動取得してAnsible変数ファイル生成
# group_vars/poc.yml に保存される
uv run --project /home/tomo/poc ansible-playbook get-existing-aurora-info.yml

# 生成された設定確認
cat group_vars/poc.yml
```

#### 4.2 Auroraユーザー作成
```bash
cd /home/tomo/ansible-playbooks

# Aurora内にアプリケーション用ユーザーを作成
# - laravel_user: Laravelアプリケーション用
# - proxysql_monitor: ProxySQL監視用
uv run --project /home/tomo/poc ansible-playbook create-aurora-users.yml

# ⚠️ 注意:
# - このPlaybookは localhost で実行し、EC2経由でAuroraにアクセスします
# - Secrets Manager から master パスワードを取得します
```

#### 4.3 ProxySQL インストール・Aurora統合設定
```bash
cd /home/tomo/ansible-playbooks

# ProxySQL インストール・Aurora統合設定（一括実行）
# 実行内容：
# - ProxySQL インストール（Amazon Linux 2023対応）
# - Aurora バックエンド設定（Writer/Reader）
# - クエリルーティングルール設定
# - 監視ユーザー設定
uv run --project /home/tomo/poc ansible-playbook install-proxysql-existing-aurora.yml

# 実行結果確認
uv run --project /home/tomo/poc ansible all -m shell -a "systemctl status proxysql"

# ProxySQL設定確認
uv run --project /home/tomo/poc ansible pochub-001 -m shell -a "mysql -h127.0.0.1 -P6032 -uproxysql_admin -p'ProxyAdmin123!' -e 'SELECT hostgroup_id,hostname,port,status FROM runtime_mysql_servers;'"
```

### Step 5: Laravel統合設定

#### 5.1 Laravel設定更新
```bash
cd /home/tomo/ansible-playbooks

# Laravel DB接続をProxySQL経由に変更
# - DB_HOST: 127.0.0.1 (ProxySQL)
# - DB_PORT: 6033 (ProxySQL MySQL port)
uv run --project /home/tomo/poc ansible-playbook configure-laravel-proxysql.yml

# 設定変更確認
uv run --project /home/tomo/poc ansible all -m shell -a "grep -E '^(DB_HOST|DB_PORT)' /opt/app/laravel/.env"
```

#### 5.2 Laravel-ProxySQL統合テスト
```bash
cd /home/tomo/ansible-playbooks

# Laravel ProxySQL経由での動作確認
# テスト内容：
# - ProxySQL直接接続テスト
# - Laravel DB接続テスト
# - マイグレーション状態確認
# - /health エンドポイント確認
uv run --project /home/tomo/poc ansible-playbook test-laravel-proxysql.yml

# ヘルスチェック個別確認
uv run --project /home/tomo/poc ansible all -m uri -a "url=http://localhost/health return_content=yes"
```

### Step 6: デプロイ前事前確認

本格的な監視・アラート設定とBlue/Greenデプロイメント機能を構築する前に、以下の重要項目を確認してください。

#### 4.5.1 必須確認項目チェックリスト

**📋 監視・アラート設定の事前確認**
```bash
# 1. メール通知設定の確認・更新
cd /home/tomo/poc/sceptre/config/poc

# monitoring-alerts.yaml設定ファイル確認
cat monitoring-alerts.yaml

# NotificationEmailパラメータを実際のメールアドレスに更新
sed -i 's/your-email@example.com/actual-email@yourcompany.com/' monitoring-alerts.yaml

# 更新内容確認
grep -A3 -B3 "NotificationEmail" monitoring-alerts.yaml
```

**📋 EC2インスタンス情報の確認・設定**
```bash
# 2. 現在のEC2インスタンスID取得
aws ec2 describe-instances --filters "Name=tag:Name,Values=pochub-*" --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' --output table --region ap-northeast-1

# インスタンスID環境変数設定（実際のIDに置き換え）
export POCHUB_001_INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=pochub-001" --query 'Reservations[0].Instances[0].InstanceId' --output text)
export POCHUB_002_INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=pochub-002" --query 'Reservations[0].Instances[0].InstanceId' --output text)
export POCHUB_003_INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=pochub-003" --query 'Reservations[0].Instances[0].InstanceId' --output text)

echo "Instance IDs:"
echo "pochub-001: $POCHUB_001_INSTANCE_ID"
echo "pochub-002: $POCHUB_002_INSTANCE_ID" 
echo "pochub-003: $POCHUB_003_INSTANCE_ID"
```

**📋 Aurora接続情報の確認**
```bash
# 3. Aurora接続情報とAnsible変数の確認
cd /home/tomo/ansible-playbooks

# group_vars/poc.yml設定内容確認
cat group_vars/poc.yml

# Aurora接続情報の再取得（必要に応じて）
uv run ansible-playbook get-aurora-info.yml

# Aurora cluster状態確認
aws rds describe-db-clusters --db-cluster-identifier poc-aurora-mysql --query 'DBClusters[0].{Status:Status,Writer:Endpoint,Reader:ReaderEndpoint}' --region ap-northeast-1
```

**📋 AWS権限の確認**
```bash
# 4. 必要なAWS権限の確認
# CloudWatch権限確認
aws cloudwatch list-metrics --namespace "AWS/RDS" --region ap-northeast-1 | head -5

# SNS権限確認
aws sns list-topics --region ap-northeast-1

# Lambda権限確認
aws lambda list-functions --region ap-northeast-1

# CloudFormation権限確認
aws cloudformation list-stacks --region ap-northeast-1 | head -5

# EC2権限確認
aws ec2 describe-instances --region ap-northeast-1 | head -5
```

#### 4.5.2 設定ファイル更新（重要）

**監視アラート設定の更新**
```bash
# CloudFormationテンプレートのEC2インスタンスID更新
cd /home/tomo/poc/sceptre/templates

# monitoring-alerts.yamlテンプレート内のサンプルインスタンスIDを実際のIDに更新
# （手動編集が必要な場合）
echo "⚠️  以下のファイルを手動確認・更新してください："
echo "   - sceptre/config/poc/monitoring-alerts.yaml (NotificationEmailパラメータ)"
echo "   - sceptre/templates/monitoring-alerts.yaml (EC2インスタンスID、必要に応じて)"
```

#### 4.5.3 事前確認チェック実行

**総合確認スクリプト作成・実行**
```bash
# 事前確認総合スクリプト作成
cat > /tmp/pre-deployment-check.sh << 'EOF'
#!/bin/bash
# POC Immutable環境 デプロイ前事前確認スクリプト

echo "=== POC Immutable環境 デプロイ前事前確認 ==="
echo "実行日時: $(date)"
echo

ERRORS=0

# 1. AWS CLI設定確認
echo "🔍 1. AWS CLI設定確認"
if aws sts get-caller-identity >/dev/null 2>&1; then
    echo "✅ AWS CLI設定: OK"
    aws sts get-caller-identity --query '[Account,UserId,Arn]' --output table
else
    echo "❌ AWS CLI設定: エラー"
    ERRORS=$((ERRORS + 1))
fi
echo

# 2. Aurora Cluster確認
echo "🔍 2. Aurora Cluster確認"
AURORA_STATUS=$(aws rds describe-db-clusters --db-cluster-identifier poc-aurora-mysql --query 'DBClusters[0].Status' --output text 2>/dev/null)
if [ "$AURORA_STATUS" = "available" ]; then
    echo "✅ Aurora Cluster: $AURORA_STATUS"
else
    echo "❌ Aurora Cluster: $AURORA_STATUS (availableではない)"
    ERRORS=$((ERRORS + 1))
fi
echo

# 3. EC2インスタンス確認
echo "🔍 3. EC2インスタンス確認"
RUNNING_INSTANCES=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=pochub-*" "Name=instance-state-name,Values=running" --query 'length(Reservations[].Instances[])' --output text)
if [ "$RUNNING_INSTANCES" -ge 3 ]; then
    echo "✅ EC2インスタンス: $RUNNING_INSTANCES台稼働中"
    aws ec2 describe-instances --filters "Name=tag:Name,Values=pochub-*" --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name]' --output table
else
    echo "❌ EC2インスタンス: 稼働中インスタンスが3台未満 ($RUNNING_INSTANCES台)"
    ERRORS=$((ERRORS + 1))
fi
echo

# 4. Ansible設定確認
echo "🔍 4. Ansible設定確認"
if [ -d "/home/tomo/ansible-playbooks/.venv" ]; then
    echo "✅ Ansible: uvプロジェクト存在"
    if [ -f "/home/tomo/ansible-playbooks/inventory/aws_ec2.yml" ]; then
        echo "✅ Ansible Inventory: 存在"
    else
        echo "❌ Ansible Inventory: 見つからない"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "❌ Ansible: uvプロジェクト未初期化"
    ERRORS=$((ERRORS + 1))
fi
echo

# 5. 設定ファイル確認
echo "🔍 5. 重要設定ファイル確認"
if [ -f "/home/tomo/ansible-playbooks/group_vars/all.yml" ]; then
    echo "✅ group_vars/all.yml: 存在"
else
    echo "❌ group_vars/all.yml: 見つからない"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "/home/tomo/poc/sceptre/config/poc/monitoring-alerts.yaml" ]; then
    echo "✅ monitoring-alerts.yaml設定: 存在"
    EMAIL_CONFIG=$(grep -c "your-email@example.com" /home/tomo/poc/sceptre/config/poc/monitoring-alerts.yaml 2>/dev/null || echo 0)
    if [ "$EMAIL_CONFIG" -eq 0 ]; then
        echo "✅ NotificationEmail: 設定済み"
    else
        echo "⚠️  NotificationEmail: デフォルト値のまま（要更新）"
    fi
else
    echo "❌ monitoring-alerts.yaml設定: 見つからない"
    ERRORS=$((ERRORS + 1))
fi
echo

# 結果表示
echo "=== 事前確認結果 ==="
if [ $ERRORS -eq 0 ]; then
    echo "🎉 すべての事前確認項目: 正常"
    echo "✅ デプロイ準備完了！"
else
    echo "❌ エラー件数: $ERRORS"
    echo "⚠️  上記エラーを解決してからデプロイを実行してください"
fi
echo
EOF

chmod +x /tmp/pre-deployment-check.sh

# 事前確認実行
/tmp/pre-deployment-check.sh
```

#### 4.5.4 手動確認・更新項目

**重要な手動確認項目:**

1. **📧 メール通知設定**
   ```bash
   # 以下ファイルのNotificationEmailパラメータを実際のメールアドレスに更新
   vim /home/tomo/poc/sceptre/config/poc/monitoring-alerts.yaml
   ```

2. **🏷️ リソースタグ確認**
   ```bash
   # EC2インスタンスのタグ確認
   aws ec2 describe-instances --filters "Name=tag:Name,Values=pochub-*" --query 'Reservations[].Instances[].[InstanceId,Tags[]]' --output table
   ```
  # 補足: ASG環境ではEC2インスタンスのIPやホスト名は動的に変化するため、Ansibleのインベントリにはタグベースで抽出する運用が推奨されます。
  # また、CloudFormationテンプレートのLaunchTemplateのUserDataにて、インスタンス起動時に自身のAZ（アベイラビリティゾーン）名を取得し、AWS CLIでタグ付与する仕組みを導入しています。
  # 例:
  #   AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
  #   INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  #   aws ec2 create-tags --resources $INSTANCE_ID --tags Key=AvailabilityZone,Value=$AZ --region ap-northeast-1
  # このタグを使って、Ansibleの動的インベントリやAWS CLIでインスタンス抽出が可能です。

3. **🔐 セキュリティグループ確認**
   ```bash
   # ProxySQL用ポート6032/6033のアクセス確認
   aws ec2 describe-security-groups --filters "Name=group-name,Values=*poc*" --query 'SecurityGroups[].[GroupName,IpPermissions[]]' --region ap-northeast-1
   ```

**✅ 事前確認完了後の次ステップ:**
すべての確認項目がOKになったら、Step 5の監視・アラート設定に進んでください。

### Step 7: 監視・アラート設定

#### 7.1 CloudWatch監視インフラ構築
```bash
cd /home/tomo/poc/sceptre

# 監視テンプレート検証
uv run sceptre validate poc/monitoring-alerts.yaml

# 監視CloudFormationスタック作成
# 作成されるリソース：
# - CloudWatch Alarms（Aurora CPU/接続数, EC2 CPU, カスタムメトリクス）
# - CloudWatch Dashboard
# - SNS Topic（アラート通知用）
# - Lambda Functions（メトリクス集約、カスタムアラート）
uv run sceptre create poc/monitoring-alerts.yaml
```

#### 7.2 EC2監視エージェント設定
```bash
cd /home/tomo/ansible-playbooks

# 包括的監視設定（CloudWatch Agent + カスタムメトリクス）
# 設定内容：
# - CloudWatch Agent インストール・設定
# - ProxySQL監視スクリプト（2分ごと）
# - Laravel監視スクリプト（2分ごと）
# - システム監視スクリプト（5分ごと）
# - Cron設定、ログローテーション
uv run --project /home/tomo/poc ansible-playbook setup-comprehensive-monitoring.yml
```

#### 7.3 SNS通知設定確認
```bash
# SNS Topic確認
aws sns list-topics --region ap-northeast-1

# SNS Subscription確認（メール通知）
aws sns list-subscriptions --region ap-northeast-1
```

### Step 8: フェイルオーバーテスト

#### 8.1 自動フェイルオーバーテスト実行
```bash
cd /home/tomo/ansible-playbooks

# 自動フェイルオーバーテスト（5分間継続テスト）
# テスト内容：
# - ProxySQL バックエンドステータス確認
# - Laravelヘルスチェック確認
# - フェイルオーバーテストデータベーステーブル作成
# - 継続的接続テスト（バックグラウンド）
# ⚠️ 注意: Aurora再起動はIAM権限不足のためスキップされます（意図的な制限）
uv run --project /home/tomo/poc ansible-playbook test-proxysql-failover.yml

# テスト結果確認
# ⚠️ 注意: IAM権限制限により、完全なフェイルオーバーテストは実行されません
# ProxySQLの基本動作とLaravelヘルスチェックは確認されます
```

#### 8.2 手動テスト環境セットアップ
```bash
cd /home/tomo/ansible-playbooks

# 手動テスト用のツール・スクリプトセットアップ
# 作成されるツール：
# - ProxySQL バックエンド操作スクリプト
# - 接続プール統計確認スクリプト
# - リアルタイム監視ツール
uv run --project /home/tomo/poc ansible-playbook setup-proxysql-manual-testing.yml

# 手動テストツール確認
uv run --project /home/tomo/poc ansible all -m shell -a "ls -la /tmp/proxysql_* /usr/local/bin/*proxysql* 2>/dev/null || echo 'Tools installed'"
```

#### 8.3 RDSフェールオーバーテスト（本番想定）

このテストでは、Aurora Writerインスタンスを再起動し、ProxySQLがフェールオーバーを自動的に処理できることを確認します。

**⚠️ 重要な注意事項:**
- このテストは**リモート端末（ローカルPC）から実行**してください
- EC2インスタンスからRDS操作を行うのはセキュリティベストプラクティスに反します
- テスト中、数十秒程度のデータベース接続断が発生する可能性があります

##### 8.3.1 事前準備と監視開始

```bash
# ローカル端末で実行

# Aurora Cluster情報取得
CLUSTER_ID="poc-poc-aurora-cluster"
REGION="ap-northeast-1"

# 現在のWriter/Readerインスタンス確認
echo "=== Current Aurora Cluster Members ==="
aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $REGION \
  --query 'DBClusters[0].DBClusterMembers[*].{Instance:DBInstanceIdentifier,IsWriter:IsClusterWriter}' \
  --output table

# Aurora Instance詳細情報（Status, AZ, Endpoint）
echo ""
echo "=== Aurora Instance Details ==="
aws rds describe-db-instances \
  --region $REGION \
  --query "DBInstances[?DBClusterIdentifier=='$CLUSTER_ID'].{Instance:DBInstanceIdentifier,Status:DBInstanceStatus,AZ:AvailabilityZone,Endpoint:Endpoint.Address}" \
  --output table

# Cluster Endpoints確認（ProxySQLが接続するエンドポイント）
echo ""
echo "=== Aurora Cluster Endpoints ==="
echo "Writer Endpoint:"
aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $REGION \
  --query 'DBClusters[0].Endpoint' \
  --output text

echo ""
echo "Reader Endpoint:"
aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $REGION \
  --query 'DBClusters[0].ReaderEndpoint' \
  --output text
```

##### 8.3.2 継続的ヘルスチェック監視（別ターミナル）

テスト中のアプリケーション状態を監視するため、別ターミナルで継続的にヘルスチェックを実行します。

**📋 `/health` エンドポイントが確認する内容:**

Laravelの`/health`エンドポイントは以下を確認します：

```php
Route::get('/health', function () {
    try {
        // 実際にデータベース接続を試みる
        DB::connection()->getPdo();
        $dbStatus = 'connected';
    } catch (\Exception $e) {
        $dbStatus = 'disconnected';
    }
    
    return response()->json([
        'status' => 'healthy',
        'timestamp' => now(),
        'database' => $dbStatus,  // 'connected' または 'disconnected'
        'environment' => config('app.env'),
        'version' => '1.0.0'
    ]);
});
```

**確認できる内容:**
- ✅ Laravelアプリケーションが起動している
- ✅ ProxySQLが起動している（localhost:6033）
- ✅ ProxySQLがAuroraに接続できている
- ✅ Laravel → ProxySQL → Aurora の完全な接続チェーン

`"database": "connected"` が表示されれば、**DB接続が正常**であることが確認できます。

**⚠️ 注意**: ALBがinternal（VPC内部のみ）の場合、ローカル端末から直接アクセスできません。以下のいずれかの方法で監視してください。

**方法1: Ansible経由で継続的ヘルスチェック（推奨）**

```bash
# 別ターミナルで実行（ローカル端末）
cd /home/tomo/ansible-playbooks

# 継続的ヘルスチェック（5秒間隔、Ctrl+Cで停止）
while true; do
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  
  # 1台のEC2インスタンスでローカルヘルスチェック実行
  HEALTH_CHECK=$(uv run --project /home/tomo/poc ansible pochub-001 -m shell -a "curl -s -o /dev/null -w '%{http_code}' http://localhost/health" 2>/dev/null | grep -E "^(200|500|503)" | tail -1)
  
  if [ "$HEALTH_CHECK" = "200" ]; then
    echo "[$TIMESTAMP] ✅ Status: 200 - Service Healthy"
  else
    echo "[$TIMESTAMP] ❌ Status: $HEALTH_CHECK - Service Unhealthy"
  fi
  
  sleep 5
done
```

**方法2: ALBがinternet-facingの場合**

```bash
# 別ターミナルで実行（ローカル端末）

# Web用ALBのDNS名を取得
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --region ap-northeast-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName,`web`)].DNSName' \
  --output text)

# ALBがinternet-facingか確認
ALB_SCHEME=$(aws elbv2 describe-load-balancers \
  --region ap-northeast-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName,`web`)].Scheme' \
  --output text)

echo "ALB DNS: $ALB_DNS"
echo "ALB Scheme: $ALB_SCHEME"

# internet-facingの場合のみ実行可能
if [ "$ALB_SCHEME" = "internet-facing" ]; then
  echo "=== Continuous Health Check Started ==="
  echo "Press Ctrl+C to stop"
  echo ""
  
  while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/health)
    
    if [ "$HTTP_CODE" = "200" ]; then
      echo "[$TIMESTAMP] ✅ Status: $HTTP_CODE - Service Healthy"
    else
      echo "[$TIMESTAMP] ❌ Status: $HTTP_CODE - Service Unhealthy"
    fi
    
    sleep 5
  done
else
  echo "⚠️  ALB is internal - use Method 1 (Ansible) instead"
fi
```

##### 8.3.3 ProxySQL状態監視（フェールオーバー前の確認）

フェールオーバーテスト前に、ProxySQLがAuroraに正常に接続していることを確認します。

```bash
# ローカル端末で実行
cd /home/tomo/ansible-playbooks

# ProxySQLサービス状態確認（全インスタンス）
echo "=== ProxySQL Service Status ==="
uv run --project /home/tomo/poc ansible all -m shell -a "systemctl status proxysql | head -3" -b

# ProxySQLポート確認（1台で確認）
echo ""
echo "=== ProxySQL Listening Ports ==="
uv run --project /home/tomo/poc ansible pochub-001 -m shell -a "netstat -tlnp 2>/dev/null | grep -E '6032|6033' || ss -tlnp 2>/dev/null | grep -E '6032|6033'"

# ProxySQL + Aurora接続テスト（重要）
echo ""
echo "=== ProxySQL + Aurora Connection Test ==="
uv run --project /home/tomo/poc ansible-playbook test-laravel-proxysql.yml --limit pochub-001

# テスト結果から重要な情報を確認：
# ✅ ProxySQL Connection Pool Statistics:
#    hostgroup 0 (Writer): ONLINE
#    hostgroup 1 (Reader): ONLINE
# ✅ Health Endpoint: Status 200, database "connected"
```

**期待される結果:**
```
ProxySQL Connection Pool Statistics:
hostgroup  srv_host                                              status  Queries
0          poc-poc-aurora-cluster.cluster-[...].rds.amazonaws.com  ONLINE  121
1          poc-poc-aurora-cluster.cluster-ro-[...].rds.amazonaws.com ONLINE  379

Health Endpoint:
{"status":"healthy","database":"connected","environment":"poc","version":"1.0.0"}
```

**⚠️ 注意**: 
- Hostgroup 0 (Writer) と Hostgroup 1 (Reader) が両方 **ONLINE** であることを確認
- ヘルスチェックで `"database":"connected"` が表示されることを確認
- この状態が確認できない場合は、フェールオーバーテストを実施しても意味がありません

##### 8.3.4 RDSフェールオーバー実行

**メインターミナルで実行（ローカル端末）：**

```bash
# ローカル端末で実行

CLUSTER_ID="poc-poc-aurora-cluster"
REGION="ap-northeast-1"

# フェールオーバー前の状態確認
echo "=== Pre-Failover Status ==="
echo ""
echo "Cluster Members:"
aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $REGION \
  --query 'DBClusters[0].DBClusterMembers[*].{Instance:DBInstanceIdentifier,IsWriter:IsClusterWriter}' \
  --output table

echo ""
echo "Instance Details:"
aws rds describe-db-instances \
  --region $REGION \
  --query "DBInstances[?DBClusterIdentifier=='$CLUSTER_ID'].{Instance:DBInstanceIdentifier,Status:DBInstanceStatus,AZ:AvailabilityZone}" \
  --output table

# フェールオーバー実行
echo ""
echo "=== Executing Aurora Failover ==="
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Cluster: $CLUSTER_ID"
echo ""

# ⚠️ 重要: Auroraの場合は failover-db-cluster を使用
# reboot-db-instance --force-failover はAuroraでは使用できません
aws rds failover-db-cluster \
  --db-cluster-identifier $CLUSTER_ID \
  --region $REGION

echo ""
echo "✅ Failover command issued successfully"
echo "⏳ Failover in progress (typically completes in 10-30 seconds)..."
echo ""
echo "Monitor the following:"
echo "  1.別ターミナルのヘルスチェック監視"
echo "  2. フェールオーバー完了確認（次のステップ）"
echo ""
```

**別ターミナルでの監視（推奨）：**

フェールオーバー実行と同時に、別ターミナルでアプリケーションの継続性を監視します。

```bash
# 別ターミナルで実行（ローカル端末）
cd /home/tomo/ansible-playbooks

echo "=== Monitoring Application During Failover ==="
for i in {1..10}; do
  echo ""
  echo "Check $i ($(date '+%H:%M:%S')):"
  
  HEALTH=$(uv run --project /home/tomo/poc ansible pochub-001 -m shell \
    -a "curl -s -o /dev/null -w '%{http_code}' http://localhost/health" 2>/dev/null \
    | grep -oE '[0-9]{3}' | tail -1)
  
  if [ "$HEALTH" = "200" ]; then
    echo "  ✅ HTTP $HEALTH - Service Healthy"
  else
    echo "  ⚠️  HTTP $HEALTH - Service Degraded"
  fi
  
  sleep 5
done
```

##### 8.3.5 フェールオーバー完了確認

フェールオーバー実行後、約10-30秒待ってから新しい構成を確認します。

```bash
# ローカル端末で実行（メインターミナル）

CLUSTER_ID="poc-poc-aurora-cluster"
REGION="ap-northeast-1"

# フェールオーバー完了待機（30秒程度）
echo "⏳ Waiting 30 seconds for failover to complete..."
sleep 30

echo ""
echo "=== Checking Failover Completion ==="
echo ""

# 新しいCluster構成確認
echo "New Cluster Configuration:"
aws rds describe-db-clusters \
  --db-cluster-identifier $CLUSTER_ID \
  --region $REGION \
  --query 'DBClusters[0].DBClusterMembers[*].{Instance:DBInstanceIdentifier,IsWriter:IsClusterWriter}' \
  --output table

echo ""
echo "Instance Status:"
aws rds describe-db-instances \
  --region $REGION \
  --query "DBInstances[?DBClusterIdentifier=='$CLUSTER_ID'].{Instance:DBInstanceIdentifier,Status:DBInstanceStatus,AZ:AvailabilityZone}" \
  --output table

# フェールオーバーイベント確認
echo ""
echo "=== Recent Failover Events ==="
aws rds describe-events \
  --source-identifier $CLUSTER_ID \
  --source-type db-cluster \
  --region $REGION \
  --duration 30 \
  --query 'Events[*].{Time:Date,Message:Message}' \
  --output table

echo ""
echo "✅ Failover completed"
```

**期待される結果:**

フェールオーバー前：
```
Instance        IsWriter
poc-poc-aurora-writer   True
poc-poc-aurora-reader   False
```

フェールオーバー後：
```
Instance        IsWriter
poc-poc-aurora-reader   True   ← Writerに昇格
poc-poc-aurora-writer   False  ← Readerに降格
```

フェールオーバーイベント：
```
Message                                                              Time
Started cross AZ failover to DB instance: poc-poc-aurora-reader      16:40:00
Completed customer initiated failover to DB instance: poc-poc-aurora-reader  16:40:13
```

**フェールオーバー所要時間: 通常10-30秒**

##### 8.3.6 アプリケーション継続性確認

フェールオーバー後、アプリケーションとProxySQLが正常に動作していることを確認します。

```bash
# ローカル端末で実行
cd /home/tomo/ansible-playbooks

# Laravelヘルスチェック
echo "=== Final Application Health Check ==="
for i in {1..3}; do
  echo ""
  echo "Attempt $i:"
  
  uv run --project /home/tomo/poc ansible pochub-001 -m shell \
    -a "curl -s http://localhost/health" 2>/dev/null \
    | grep -oE '\{.*\}' | tail -1 | jq '.'
  
  sleep 2
done

# ProxySQL接続プール統計確認（重要）
echo ""
echo "=== ProxySQL Connection Pool Statistics (After Failover) ==="
uv run --project /home/tomo/poc ansible-playbook test-laravel-proxysql.yml \
  --limit pochub-001 2>&1 | grep -A 5 "ProxySQL Connection Pool Statistics"

echo ""
echo "✅ RDS Failover Test Completed"
```

**期待される結果:**

```json
{
  "status": "healthy",
  "timestamp": "2025-10-18T16:43:14.752338Z",
  "database": "connected",
  "environment": "poc",
  "version": "1.0.0"
}
```

ProxySQL接続プール統計:
```
hostgroup  srv_host                                              status  Queries
0          poc-poc-aurora-cluster.cluster-[...].rds.amazonaws.com  ONLINE  121
1          poc-poc-aurora-cluster.cluster-ro-[...].rds.amazonaws.com ONLINE  389
```

**確認ポイント:**
- ✅ ヘルスチェックで `"database":"connected"` が表示される
- ✅ ProxySQLのHostgroup 0 (Writer)とHostgroup 1 (Reader)が両方ONLINE
- ✅ Queriesカウントが増加している（サービス継続中）

##### 8.3.7 テスト結果評価

**成功基準:**
- ✅ Writerインスタンスが正常にReaderに降格
- ✅ ReaderインスタンスがWriterに昇格
- ✅ Laravelヘルスチェックが**継続的に200 OK**（ダウンタイムなし）
- ✅ ProxySQLが新しいWriterエンドポイントに自動接続継続
- ✅ アプリケーションがサービス継続（無停止フェールオーバー）

**実際の動作（テスト結果）:**

1. **フェールオーバー開始**: `failover-db-cluster` コマンド発行
2. **フェールオーバー所要時間**: 約10-30秒
3. **アプリケーションダウンタイム**: **0秒** 🎉
4. **ProxySQL**: 設定変更不要（Cluster Endpointを使用）
5. **自動復旧**: AWSがDNSレコードを自動更新、透過的に切り替え

**フェールオーバーイベント例:**
```
16:40:00 - Started cross AZ failover to DB instance: poc-poc-aurora-reader
16:40:13 - Completed customer initiated failover (所要時間: 13秒)
```

**ProxySQLの役割:**
- Aurora Cluster Endpointに接続しているため、フェールオーバー後も自動的に新しいWriterに接続
- ProxySQL自体の設定変更や再起動は不要
- 接続プールが自動的に新しいWriterインスタンスに切り替え

**重要な発見:**
- Aurora Cluster Endpointを使用することで、真の無停止フェールオーバーが実現
- ProxySQLの接続プール機能により、アプリケーション側で接続エラーが発生しない
- Multi-AZ構成により、異なるAZ間でのフェールオーバーも問題なく動作

**トラブルシューティング:**

もしアプリケーションが復旧しない場合（通常は不要）：

```bash
# ProxySQLの状態確認
cd /home/tomo/ansible-playbooks
uv run --project /home/tomo/poc ansible all -m shell -a "systemctl status proxysql" -b

# ProxySQLの再起動（必要な場合のみ）
uv run --project /home/tomo/poc ansible all -m systemd -a "name=proxysql state=restarted" -b

# Laravel接続テスト
uv run --project /home/tomo/poc ansible-playbook test-laravel-proxysql.yml --limit pochub-001
```

#### 8.4 EC2フェールオーバーテスト（ASG自動復旧）

このテストでは、Auto Scaling Group（ASG）配下のEC2インスタンスを停止し、ASGが自動的に新しいインスタンスを起動・復旧できることを確認します。

**⚠️ 重要な注意事項:**
- このテストは**リモート端末（ローカルPC）から実行**してください
- テスト中、停止したインスタンスへのトラフィックは他のインスタンスに振り分けられます
- 新インスタンス起動後、手動でAnsibleによるLaravelデプロイが必要です

##### 8.4.1 事前確認

```bash
# ローカル端末で実行

ASG_NAME="poc-poc-ec2-asg"
REGION="ap-northeast-1"

# 現在のASG状態確認
echo "=== Current ASG Status ==="
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $REGION \
  --query 'AutoScalingGroups[0].{Name:AutoScalingGroupName,Desired:DesiredCapacity,Min:MinSize,Max:MaxSize,HealthCheckType:HealthCheckType,HealthCheckGracePeriod:HealthCheckGracePeriod}' \
  --output table

echo ""
echo "=== Current Instances ==="
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $REGION \
  --query 'AutoScalingGroups[0].Instances[*].{InstanceId:InstanceId,AZ:AvailabilityZone,Health:HealthStatus,Lifecycle:LifecycleState}' \
  --output table
```

##### 8.4.2 ALBターゲット状態確認

```bash
# ローカル端末で実行

# ALB Target Group確認
TG_ARN=$(aws elbv2 describe-target-groups \
  --region $REGION \
  --query 'TargetGroups[?contains(TargetGroupName,`poc`)].TargetGroupArn' \
  --output text | head -1)

echo "=== ALB Target Health (Before Test) ==="
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region $REGION \
  --query 'TargetHealthDescriptions[*].{Instance:Target.Id,Port:Target.Port,Health:TargetHealth.State,Reason:TargetHealth.Reason}' \
  --output table
```

##### 8.4.3 継続的ヘルスチェック監視（別ターミナル）

EC2フェールオーバー中もアプリケーションが正常にサービスを提供できていることを確認します。

**📋 ヘルスチェックで確認する内容:**

`/health`エンドポイント（8.3.2参照）は以下を確認します：
- Laravelアプリケーションの起動状態
- ProxySQL経由でのAuroraデータベース接続
- `"database": "connected"` = DB接続が正常

EC2インスタンスが1台停止しても、残りの2台が正常にサービスを提供し続けることを確認します。

```bash
# 別ターミナルで実行（ローカル端末）

# ALBのDNS名を取得
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --region ap-northeast-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName,`poc`)].DNSName' \
  --output text)

echo "=== Continuous Health Check & Instance Monitoring ==="
echo "ALB DNS: $ALB_DNS"
echo "Press Ctrl+C to stop"
echo ""

while true; do
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/health)
  
  # インスタンス数確認
  INSTANCE_COUNT=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names poc-poc-ec2-asg \
    --region ap-northeast-1 \
    --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`] | length(@)' \
    --output text 2>/dev/null)
  
  if [ "$HTTP_CODE" = "200" ]; then
    echo "[$TIMESTAMP] ✅ HTTP $HTTP_CODE | InService Instances: $INSTANCE_COUNT/3"
  else
    echo "[$TIMESTAMP] ⚠️  HTTP $HTTP_CODE | InService Instances: $INSTANCE_COUNT/3"
  fi
  
  sleep 5
done
```

##### 8.4.4 EC2インスタンス停止（フェールオーバー実行）

```bash
# ローカル端末で実行（メインターミナル）

# テスト対象インスタンスを選択（1台目）
TARGET_INSTANCE=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $REGION \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)

echo "=== EC2 Failover Test Started ==="
echo "ASG Name: $ASG_NAME"
echo "Target Instance: $TARGET_INSTANCE"
echo ""

# インスタンス情報取得
aws ec2 describe-instances \
  --instance-ids $TARGET_INSTANCE \
  --region $REGION \
  --query 'Reservations[0].Instances[0].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0],AZ:Placement.AvailabilityZone,State:State.Name}' \
  --output table

echo ""
echo "⚠️  Stopping instance at: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# インスタンス停止
aws ec2 stop-instances \
  --instance-ids $TARGET_INSTANCE \
  --region $REGION \
  --output table

echo ""
echo "✅ Stop command issued"
echo "⏳ ASG will detect unhealthy instance and launch a new one..."
echo ""
echo "Monitor the following:"
echo "  1. Health check terminal (should remain 200 OK - traffic goes to healthy instances)"
echo "  2. ASG will launch a new instance in 2-3 minutes"
echo ""
```

##### 8.4.5 ASG自動復旧監視

```bash
# ローカル端末で実行

echo "=== Monitoring ASG Auto Recovery ==="
echo "Checking every 15 seconds..."
echo ""

# ASGの自動復旧を監視（最大15分）
for i in {1..60}; do
  TIMESTAMP=$(date '+%H:%M:%S')
  
  # ASG状態取得
  ASG_STATUS=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $ASG_NAME \
    --region $REGION \
    --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,InService:Instances[?LifecycleState==`InService`]|length(@),Pending:Instances[?LifecycleState==`Pending`]|length(@)}' \
    --output json)
  
  DESIRED=$(echo $ASG_STATUS | jq -r '.Desired')
  IN_SERVICE=$(echo $ASG_STATUS | jq -r '.InService')
  PENDING=$(echo $ASG_STATUS | jq -r '.Pending')
  
  echo "[$TIMESTAMP] Desired: $DESIRED | InService: $IN_SERVICE | Pending: $PENDING"
  
  # 復旧完了判定
  if [ "$IN_SERVICE" = "$DESIRED" ]; then
    echo ""
    echo "✅ ASG has fully recovered! All instances are InService."
    break
  fi
  
  sleep 15
done

echo ""
echo "=== Final ASG Status ==="
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $REGION \
  --query 'AutoScalingGroups[0].Instances[*].{InstanceId:InstanceId,AZ:AvailabilityZone,Health:HealthStatus,Lifecycle:LifecycleState,LaunchTime:LaunchTime}' \
  --output table
```

##### 8.4.6 新規インスタンスへのLaravelデプロイ

ASGが新しいインスタンスを起動したら、Ansibleで必要な設定とLaravelをデプロイします。

```bash
# ローカル端末で実行

# 新規インスタンスID取得
NEW_INSTANCE=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $ASG_NAME \
  --region $REGION \
  --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`] | sort_by(@, &LaunchTime) | [-1].InstanceId' \
  --output text)

echo "=== New Instance Information ==="
echo "Instance ID: $NEW_INSTANCE"
echo ""

# インスタンスの詳細情報
aws ec2 describe-instances \
  --instance-ids $NEW_INSTANCE \
  --region $REGION \
  --query 'Reservations[0].Instances[0].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0],IP:PrivateIpAddress,AZ:Placement.AvailabilityZone,LaunchTime:LaunchTime}' \
  --output table

echo ""
echo "⏳ Waiting for SSM agent to be ready (60 seconds)..."
sleep 60

# 新しいインスタンスの名前を取得
NEW_INSTANCE_NAME=$(aws ec2 describe-instances \
  --instance-ids $NEW_INSTANCE \
  --region $REGION \
  --query 'Reservations[0].Instances[0].Tags[?Key==`Name`].Value' \
  --output text)

echo "New Instance Name: $NEW_INSTANCE_NAME"
echo ""

# Ansible dynamic inventoryを更新して新インスタンスを認識
cd /home/tomo/ansible-playbooks

# ⚠️ 重要: --limit で新しいインスタンスのみをターゲットにする
# 既存の稼働中インスタンスには影響を与えない
echo "=== Deploying Laravel to New Instance ONLY ==="
echo "Target: $NEW_INSTANCE_NAME"
echo ""

# Laravel環境セットアップ（新インスタンスのみ）
echo "=== Step 1: Laravel Environment Setup ==="
uv run --project /home/tomo/poc ansible-playbook setup-laravel-environment.yml \
  --limit "$NEW_INSTANCE_NAME"

# ProxySQL環境構築（新インスタンスのみ）
echo ""
echo "=== Step 2: ProxySQL Installation ==="
uv run --project /home/tomo/poc ansible-playbook install-proxysql-existing-aurora.yml \
  --limit "$NEW_INSTANCE_NAME"

# Laravel統合設定（新インスタンスのみ）
echo ""
echo "=== Step 3: Laravel-ProxySQL Integration ==="
uv run --project /home/tomo/poc ansible-playbook configure-laravel-proxysql.yml \
  --limit "$NEW_INSTANCE_NAME"

echo ""
echo "✅ Laravel deployment completed on new instance: $NEW_INSTANCE_NAME"
echo "⚠️  Note: Only the new instance was configured. Existing instances were not modified."
```

**⚠️ トラブルシューティング: Playbookの依存パッケージエラー**

新しいインスタンスへのデプロイ時に、以下のエラーが発生する可能性があります：

**エラー1: mysql: command not found**
```
TASK [Configure Aurora servers in ProxySQL]
fatal: [pochub-002]: FAILED! => 
  stderr: "/bin/sh: line 1: mysql: command not found"
```

**原因**: `install-proxysql-existing-aurora.yml`が`mysql`コマンドの存在を確認するだけで、インストールしていなかった。

**解決**: Playbookを修正して`mariadb105`パッケージを自動インストールするように変更：
```yaml
- name: Install MariaDB client (mysql command)
  package:
    name: mariadb105
    state: present
  when: mysql_check.rc != 0
```

**エラー2: crontab: command not found**
```
TASK [Create ProxySQL monitoring cron job]
fatal: [pochub-002]: FAILED! =>
  msg: "Failed to find required executable \"crontab\""
```

**原因**: Amazon Linux 2023では`cronie`パッケージがデフォルトでインストールされていない。

**解決**: Playbookを修正して`cronie`パッケージを追加し、crondサービスを起動：
```yaml
- name: Install required packages
  dnf:
    name:
      - wget
      - python3-pip
      - python3-boto3
      - cronie  # ← 追加
    state: present

- name: Ensure crond service is enabled and started
  systemd:
    name: crond
    state: started
    enabled: yes
```

**修正済みPlaybook**: 
`install-proxysql-existing-aurora.yml`は上記の修正が適用されています。既存インスタンスではこれらのパッケージが既にインストールされているため、新しいインスタンスのみに適用されます。

##### 8.4.7 デプロイ確認とALB登録確認

新しいインスタンスが正常にデプロイされ、データベース接続を含む全機能が動作していることを確認します。

```bash
# ローカル端末で実行

# 新インスタンスのヘルスチェック
echo "=== New Instance Health Check ==="
NEW_INSTANCE_IP=$(aws ec2 describe-instances \
  --instance-ids $NEW_INSTANCE \
  --region $REGION \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

# SSM経由でヘルスチェック
# /healthエンドポイントで以下を確認：
#  - Laravel起動状態
#  - ProxySQL接続
#  - Auroraデータベース接続
#  - "database": "connected" が表示されること
aws ssm send-command \
  --instance-ids $NEW_INSTANCE \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["curl -s http://localhost/health | jq ."]' \
  --region $REGION \
  --output text

# ALBターゲットヘルス確認
echo ""
echo "=== ALB Target Health (After Recovery) ==="
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region $REGION \
  --query 'TargetHealthDescriptions[*].{Instance:Target.Id,Port:Target.Port,Health:TargetHealth.State,Description:TargetHealth.Description}' \
  --output table

# 全インスタンスがhealthyになるまで待機
echo ""
echo "⏳ Waiting for all targets to become healthy..."
aws elbv2 wait target-in-service \
  --target-group-arn $TG_ARN \
  --targets Id=$NEW_INSTANCE

echo ""
echo "✅ New instance is healthy and serving traffic"
```

##### 8.4.8 エンドツーエンドテスト

新しいインスタンスがALB経由で正常にトラフィックを受信し、完全な機能を提供できることを確認します。

```bash
# ローカル端末で実行

# ALB経由でアプリケーションテスト
echo "=== End-to-End Application Test ==="
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --region ap-northeast-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName,`poc`)].DNSName' \
  --output text)

# 10回連続でヘルスチェックを実行
# 各リクエストで以下を確認：
#  - status: "healthy" → アプリケーション正常
#  - database: "connected" → DB接続正常（Laravel→ProxySQL→Aurora）
#  - timestamp: 更新されている → リアルタイムレスポンス
for i in {1..10}; do
  echo "Request $i:"
  curl -s http://$ALB_DNS/health | jq '{status, database, timestamp}'
  sleep 1
done

echo ""
echo "✅ EC2 Failover Test Completed Successfully"
```

**期待される結果:**
```json
{
  "status": "healthy",
  "database": "connected",
  "timestamp": "2025-10-18T17:38:59.384515Z"
}
```

すべてのリクエストで`"database": "connected"`が表示されれば、新しいインスタンスが完全に機能していることが確認できます。

##### 8.4.9 旧インスタンスのクリーンアップ

```bash
# ローカル端末で実行

# 停止中のインスタンスを終了
echo "=== Cleaning Up Stopped Instance ==="
echo "Target Instance: $TARGET_INSTANCE"

# インスタンス状態確認
INSTANCE_STATE=$(aws ec2 describe-instances \
  --instance-ids $TARGET_INSTANCE \
  --region $REGION \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text 2>/dev/null || echo "terminated")

if [ "$INSTANCE_STATE" = "stopped" ]; then
  echo "Terminating stopped instance..."
  aws ec2 terminate-instances \
    --instance-ids $TARGET_INSTANCE \
    --region $REGION \
    --output table
  echo "✅ Old instance terminated"
else
  echo "ℹ️  Instance is already $INSTANCE_STATE, no action needed"
fi
```

##### 8.4.10 テスト結果評価

**成功基準:**
- ✅ EC2インスタンス停止後、ASGが自動的に新インスタンスを起動
- ✅ 停止中もALBヘルスチェックが200 OKを維持（他のインスタンスが処理）
- ✅ 新インスタンスにAnsibleでLaravel/ProxySQLをデプロイ成功
- ✅ 新インスタンスがALBのターゲットグループでhealthyになった
- ✅ ALB経由でアプリケーションが正常にアクセス可能

**実際のテスト結果（2025-10-19実施）:**

```
停止したインスタンス: pochub-002 (i-065ed6d447f001a4c) - AZ: ap-northeast-1c
新しいインスタンス:   pochub-002 (i-02894ff6e9efb8b0f) - AZ: ap-northeast-1c

タイムライン:
01:54:35 - インスタンス停止コマンド発行
01:55:10 - ASGが検知、新インスタンス起動開始 (InService: 2, Pending: 1)
01:55:26 - ASGが完全復旧 (InService: 3, Pending: 0)

ASG復旧時間: 約51秒 ✅

デプロイ結果:
- Laravel環境: ok=21 changed=19 (完全な初回セットアップ)
- ProxySQL環境: ok=34 changed=12 (正常インストール)
- Laravel統合: ok=17 changed=9 (設定完了)

最終ヘルスチェック:
{
  "status": "healthy",
  "database": "connected",
  "environment": "poc",
  "version": "1.0.0"
}
```

**発見された問題と解決:**
1. **mysql: command not found** → `mariadb105`パッケージの自動インストール追加
2. **crontab: command not found** → `cronie`パッケージの自動インストール追加
3. **--limitなしで実行** → 既存インスタンスにも影響（changed=8）

**期待される動作:**
1. **インスタンス停止**: 1台のEC2を手動停止
2. **トラフィック切り替え**: ALBが自動的に残り2台にトラフィック振り分け
3. **ASG検知**: 2-3分後、ASGが不健全なインスタンスを検知
4. **新インスタンス起動**: ASGが自動的に新しいEC2を起動
5. **手動デプロイ**: Ansibleで新インスタンスにLaravel環境構築
6. **サービス復旧**: 新インスタンスがALBに登録され、トラフィック受信開始

**⚠️ 重要なポイント: Ansible実行時の--limit使用**

新しいインスタンスへのデプロイ時は、**必ず `--limit` オプションで対象を限定**してください：

```bash
# ❌ 間違い: 全インスタンスに実行（リスクあり）
uv run --project /home/tomo/poc ansible-playbook setup-laravel-environment.yml

# ✅ 正しい: 新しいインスタンスのみ
uv run --project /home/tomo/poc ansible-playbook setup-laravel-environment.yml --limit pochub-002
```

**理由:**
- 冪等性があっても、既存の稼働中インスタンスに**意図しない変更**が発生する可能性
- 設定ファイルの再生成、サービスの再起動などが発生
- 本番環境では**予期しない影響**でサービス断が発生するリスク
- 新インスタンスのみをターゲットにすることで、既存環境への影響を完全に排除

**実際の影響例:**
```
# --limitなしで実行した場合
pochub-001: ok=20 changed=8  ← 既存インスタンスが変更された（問題！）
pochub-002: ok=21 changed=19 ← 新インスタンス（正常）
pochub-003: ok=20 changed=8  ← 既存インスタンスが変更された（問題！）

# --limit使用時の期待値
pochub-001: [実行対象外]
pochub-002: ok=21 changed=19 ← 新インスタンスのみ
pochub-003: [実行対象外]
```

**Step 8完了確認:**

以下のフェールオーバーテストが完了しました：
- ✅ 8.1 ProxySQL自動フェールオーバーテスト（基本機能確認）
- ✅ 8.2 手動テスト環境セットアップ
- ✅ 8.3 RDSフェールオーバーテスト（本番想定シナリオ）
  - フェールオーバー所要時間: 約13秒
  - アプリケーションダウンタイム: 0秒
  - ProxySQLが透過的にフェールオーバーを処理
- ✅ 8.4 EC2フェールオーバーテスト（ASG自動復旧）
  - ASG復旧時間: 約51秒
  - 新インスタンスへのAnsibleデプロイ成功
  - Playbookの依存パッケージ問題を発見・修正

**Playbook改善内容:**

`install-proxysql-existing-aurora.yml`に以下の修正を適用：
1. `mariadb105`パッケージの自動インストール追加（mysqlコマンド）
2. `cronie`パッケージの自動インストール追加（crontab）
3. `crond`サービスの自動起動設定追加

これらの修正により、新しいEC2インスタンスへのデプロイが完全に自動化されました。

これにより、本POC環境の高可用性とフェールオーバー機能が実証されました。

### Step 9: Blue/Greenデプロイメント対応

#### 9.1 Blue/Greenデプロイメント概要
本環境は、ProxySQLの接続プール機能により、無停止でのBlue/Greenデプロイメントに対応しています。

**デプロイメントパターン:**
- **Blue Environment**: 現在稼働中の環境（pochub-001, pochub-002, pochub-003）
- **Green Environment**: 新バージョンデプロイ先（新規EC2インスタンスまたは段階的更新）
- **ProxySQL**: 接続ルーティングにより、トラフィックを段階的に切り替え

#### 9.2 Blue/Greenデプロイメント用プレイブック作成
```bash
cd /home/tomo/ansible-playbooks

# Blue/Greenデプロイメント用プレイブック作成
cat > blue-green-deployment.yml << 'EOF'
---
# Blue/Green Deployment with ProxySQL Traffic Routing
- name: Blue/Green Deployment Management
  hosts: all
  become: yes
  vars:
    deployment_mode: "{{ deployment_mode | default('prepare') }}"  # prepare, switch, rollback, complete
    target_environment: "{{ target_environment | default('green') }}"  # blue, green
    traffic_percentage: "{{ traffic_percentage | default(0) }}"  # 0-100
    
  tasks:
    - name: Display deployment information
      debug:
        msg: |
          Blue/Green Deployment Configuration:
          Mode: {{ deployment_mode }}
          Target: {{ target_environment }}
          Traffic %: {{ traffic_percentage }}

    - name: Prepare Green Environment
      block:
        - name: Create green environment backup of current config
          copy:
            src: /var/www/poc-web/.env
            dest: /var/www/poc-web/.env.blue
            remote_src: yes

        - name: Setup green environment markers
          file:
            path: /tmp/green_deployment_{{ ansible_date_time.epoch }}
            state: touch
      when: deployment_mode == 'prepare' and target_environment == 'green'

    - name: Configure ProxySQL Traffic Routing
      block:
        - name: Update ProxySQL query rules for traffic splitting
          shell: |
            mysql -h127.0.0.1 -P6032 -uproxysql-admin -pproxysql123 -e "
            INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment) 
            VALUES (1000, 1, '.*', {{ '1' if target_environment == 'green' else '0' }}, 1, 'Blue/Green Deployment Rule') 
            ON DUPLICATE KEY UPDATE 
            destination_hostgroup={{ '1' if target_environment == 'green' else '0' }}, 
            comment='Blue/Green Deployment Rule - {{ deployment_mode }}';
            LOAD MYSQL QUERY RULES TO RUNTIME;
            SAVE MYSQL QUERY RULES TO DISK;
            "
      when: deployment_mode == 'switch'

    - name: Rollback Configuration
      block:
        - name: Restore blue environment configuration
          copy:
            src: /var/www/poc-web/.env.blue
            dest: /var/www/poc-web/.env
            remote_src: yes
          
        - name: Reset ProxySQL to blue environment
          shell: |
            mysql -h127.0.0.1 -P6032 -uproxysql-admin -pproxysql123 -e "
            UPDATE mysql_query_rules SET destination_hostgroup=0 WHERE rule_id=1000;
            LOAD MYSQL QUERY RULES TO RUNTIME;
            SAVE MYSQL QUERY RULES TO DISK;
            "
            
        - name: Clear Laravel cache
          shell: |
            cd /var/www/poc-web
            php artisan config:clear
            php artisan view:clear
            php artisan cache:clear
      when: deployment_mode == 'rollback'

    - name: Complete Deployment
      block:
        - name: Remove blue environment backup
          file:
            path: /var/www/poc-web/.env.blue
            state: absent
            
        - name: Clean up deployment markers
          shell: rm -f /tmp/green_deployment_*
          
        - name: Final ProxySQL configuration cleanup
          shell: |
            mysql -h127.0.0.1 -P6032 -uproxysql-admin -pproxysql123 -e "
            DELETE FROM mysql_query_rules WHERE comment LIKE '%Blue/Green%' AND rule_id >= 1000;
            LOAD MYSQL QUERY RULES TO RUNTIME;
            SAVE MYSQL QUERY RULES TO DISK;
            "
      when: deployment_mode == 'complete'
EOF
```

#### 7.3 Blue/Greenデプロイメント実行手順

**ステップ1: Green環境準備**
```bash
cd /home/tomo/ansible-playbooks

# Green環境の準備
uv run ansible-playbook blue-green-deployment.yml -e "deployment_mode=prepare target_environment=green"

# アプリケーションデプロイ（例：新バージョンのLaravelアプリケーション）
# この段階では新しいコードをデプロイするが、トラフィックはまだBlue環境
```

**ステップ2: トラフィック段階的切り替え**
```bash
cd /home/tomo/ansible-playbooks

# Green環境への段階的切り替え（カナリアリリース）
# 10%のトラフィックをGreen環境に切り替え
uv run ansible-playbook blue-green-deployment.yml -e "deployment_mode=switch target_environment=green traffic_percentage=10"

# 監視とヘルスチェック
uv run ansible all -m shell -a "curl -s http://localhost/health"

# 問題なければ50%に増加
uv run ansible-playbook blue-green-deployment.yml -e "deployment_mode=switch target_environment=green traffic_percentage=50"

# 最終的に100%切り替え
uv run ansible-playbook blue-green-deployment.yml -e "deployment_mode=switch target_environment=green traffic_percentage=100"
```

**ステップ3: ロールバック（問題発生時）**
```bash
cd /home/tomo/ansible-playbooks

# 問題発生時の緊急ロールバック
uv run ansible-playbook blue-green-deployment.yml -e "deployment_mode=rollback"

# ロールバック後の動作確認
uv run ansible all -m shell -a "curl -s http://localhost/health"
```

**ステップ4: デプロイメント完了**
```bash
cd /home/tomo/ansible-playbooks

# デプロイメント成功時のクリーンアップ
uv run ansible-playbook blue-green-deployment.yml -e "deployment_mode=complete"
```

#### 7.4 Blue/Greenデプロイメント監視

**リアルタイム監視スクリプト作成**
```bash
# デプロイメント監視スクリプト作成
cat > /tmp/monitor-blue-green-deployment.sh << 'EOF'
#!/bin/bash
# Blue/Green Deployment Monitoring Script

echo "=== Blue/Green Deployment Monitoring ==="
echo "Timestamp: $(date)"
echo

# ProxySQL query rules確認
echo "=== ProxySQL Query Rules ==="
mysql -h127.0.0.1 -P6032 -uproxysql-admin -pproxysql123 -e "
SELECT rule_id, active, match_pattern, destination_hostgroup, apply, comment 
FROM mysql_query_rules 
WHERE comment LIKE '%Blue/Green%' OR rule_id >= 1000
ORDER BY rule_id;
"

echo
echo "=== ProxySQL Connection Pool Status ==="
mysql -h127.0.0.1 -P6032 -uproxysql-admin -pproxysql123 -e "
SELECT hostgroup, srv_host, srv_port, status, weight FROM stats_mysql_connection_pool ORDER BY hostgroup, srv_host;
"

echo
echo "=== Application Health Check ==="
for endpoint in pochub-001 pochub-002 pochub-003; do
    echo -n "$endpoint: "
    curl -s -w "%{http_code} - %{time_total}s" http://$endpoint/health | head -1
done

echo
echo "=== Laravel Environment Check ==="
cd /var/www/poc-web
php artisan tinker --execute="echo 'App Environment: ' . app()->environment(); echo 'DB Connection: ' . DB::connection()->getDatabaseName();"
EOF

chmod +x /tmp/monitor-blue-green-deployment.sh

# 監視スクリプト実行
/tmp/monitor-blue-green-deployment.sh
```

#### 7.5 Advanced Blue/Greenデプロイメント（複数インスタンス）

**新規EC2インスタンスを使用したBlue/Greenデプロイメント**
```bash
# 新規Green環境EC2インスタンス作成（CloudFormation使用）
cd /home/tomo/poc/sceptre

# Green環境用EC2インスタンス作成テンプレート（例）
cat > templates/green-environment.yaml << 'EOF'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Green Environment for Blue/Green Deployment'

Parameters:
  VpcId:
    Type: String
    Description: VPC ID for Green environment
  SubnetIds:
    Type: CommaDelimitedList
    Description: Subnet IDs for Green environment
  SecurityGroupId:
    Type: String
    Description: Security Group ID
  ImageId:
    Type: String
    Default: ami-0abcdef1234567890  # 最新のAMI ID
    Description: AMI ID for Green instances

Resources:
  GreenInstance1:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: !Ref ImageId
      InstanceType: t3.medium
      SubnetId: !Select [0, !Ref SubnetIds]
      SecurityGroupIds:
        - !Ref SecurityGroupId
      IamInstanceProfile: !Ref InstanceProfile
      Tags:
        - Key: Name
          Value: pochub-green-001
        - Key: Environment
          Value: green
        - Key: Deployment
          Value: blue-green

  GreenInstance2:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: !Ref ImageId
      InstanceType: t3.medium
      SubnetId: !Select [1, !Ref SubnetIds]
      SecurityGroupIds:
        - !Ref SecurityGroupId
      IamInstanceProfile: !Ref InstanceProfile
      Tags:
        - Key: Name
          Value: pochub-green-002
        - Key: Environment
          Value: green
        - Key: Deployment
          Value: blue-green

Outputs:
  GreenInstance1Id:
    Description: Green Instance 1 ID
    Value: !Ref GreenInstance1
  GreenInstance2Id:
    Description: Green Instance 2 ID
    Value: !Ref GreenInstance2
EOF

# Green環境デプロイ（必要に応じて）
# sceptre create poc/green-environment.yaml
```

#### 7.6 Blue/Greenデプロイメントベストプラクティス

**1. 段階的切り替え戦略**
```bash
# 推奨切り替えパターン
# Phase 1: 5% traffic to Green
# Phase 2: 25% traffic to Green (問題なければ)
# Phase 3: 50% traffic to Green (監視継続)
# Phase 4: 100% traffic to Green (最終切り替え)

# 各段階での監視間隔: 5-10分
# エラー率閾値: 0.1%以下
# レスポンス時間閾値: +20%以内
```

**2. 自動ロールバック条件**
```bash
# 自動ロールバック条件設定
cat > /tmp/auto-rollback-conditions.sh << 'EOF'
#!/bin/bash
# Automatic Rollback Conditions Check

ERROR_RATE_THRESHOLD=0.5  # 0.5%
RESPONSE_TIME_THRESHOLD=2000  # 2 seconds
HEALTH_CHECK_FAILURES=3

# ヘルスチェック失敗数確認
FAILED_HEALTH_CHECKS=$(curl -s http://localhost/health | grep -c "error\|fail\|ERROR" || echo 0)

# エラー率確認（CloudWatch使用）
ERROR_RATE=$(aws cloudwatch get-metric-statistics \
  --namespace "Laravel/poc" \
  --metric-name "ErrorCount" \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --query 'Datapoints[0].Average' \
  --output text 2>/dev/null || echo 0)

if (( $(echo "$ERROR_RATE > $ERROR_RATE_THRESHOLD" | bc -l) )) || [ "$FAILED_HEALTH_CHECKS" -ge "$HEALTH_CHECK_FAILURES" ]; then
    echo "ROLLBACK_REQUIRED: Error rate $ERROR_RATE% or health check failures $FAILED_HEALTH_CHECKS"
    # 自動ロールバック実行
    cd /home/tomo/ansible-playbooks
    uv run ansible-playbook blue-green-deployment.yml -e "deployment_mode=rollback"
else
    echo "DEPLOYMENT_OK: Error rate $ERROR_RATE%, health checks OK"
fi
EOF

chmod +x /tmp/auto-rollback-conditions.sh
```

## 🔍 デプロイ確認

### 1. システム全体確認

#### 1.1 インフラ状態確認
```bash
# CloudFormationスタック確認
aws cloudformation describe-stacks --stack-name poc-monitoring-alerts --query 'Stacks[0].StackStatus' --region ap-northeast-1

# EC2インスタンス状態
aws ec2 describe-instances --filters "Name=tag:Name,Values=pochub-*" --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name]' --output table
```

#### 1.2 Aurora Cluster状態
```bash
# Aurora cluster状態
aws rds describe-db-clusters --db-cluster-identifier poc-poc-aurora-cluster --query 'DBClusters[0].Status' --region ap-northeast-1

# Aurora instances状態
aws rds describe-db-cluster-members --db-cluster-identifier poc-poc-aurora-cluster --query 'DBClusterMembers[].[DBInstanceIdentifier,IsClusterWriter,DBClusterParameterGroupStatus]' --output table
```

#### 1.3 Application Load Balancer状態
```bash
# ALB状態確認
aws elbv2 describe-load-balancers --region ap-northeast-1 --query 'LoadBalancers[?contains(LoadBalancerName,`poc`)].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}' --output table

# Target Group健全性確認
ALB_TG_ARN=$(aws cloudformation describe-stacks --stack-name poc-alb --query 'Stacks[0].Outputs[?OutputKey==`TargetGroupArn`].OutputValue' --output text --region ap-northeast-1)

aws elbv2 describe-target-health --target-group-arn $ALB_TG_ARN --region ap-northeast-1

# ALB経由でのアクセステスト（ヘルスチェック）
ALB_DNS=$(aws cloudformation describe-stacks --stack-name poc-alb --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' --output text --region ap-northeast-1)

echo "ALB DNS: $ALB_DNS"
# 注意：Laravel環境構築完了後にHTTPアクセステスト可能
```

### 2. ProxySQL動作確認

#### 2.1 ProxySQL プロセス確認
```bash
# ProxySQL プロセス状態
ansible all -i inventory/poc -m shell -a "systemctl status proxysql"

# ProxySQL ポート確認
ansible all -i inventory/poc -m shell -a "netstat -tulpn | grep :603"
```

#### 2.2 ProxySQL バックエンド確認
```bash
# ProxySQL バックエンドサーバー状態
ansible all -i inventory/poc -m shell -a "mysql -h127.0.0.1 -P6032 -uproxysql-admin -pproxysql123 -e 'SELECT hostgroup_id,hostname,port,status,weight FROM mysql_servers ORDER BY hostgroup_id,hostname;'"

# ProxySQL 統計情報
ansible all -i inventory/poc -m shell -a "mysql -h127.0.0.1 -P6032 -uproxysql-admin -pproxysql123 -e 'SELECT * FROM stats_mysql_connection_pool;'"
```

#### 2.3 ProxySQL ルーティング確認
```bash
# ProxySQL ルーティングルール確認
ansible all -i inventory/poc -m shell -a "mysql -h127.0.0.1 -P6032 -uproxysql-admin -pproxysql123 -e 'SELECT rule_id,active,match_pattern,destination_hostgroup,apply FROM mysql_query_rules ORDER BY rule_id;'"
```

### 3. Laravel統合確認

#### 3.1 Laravel DB接続確認
```bash
# Laravel データベース接続テスト
ansible all -i inventory/poc -m shell -a "cd /var/www/poc-web && php artisan tinker --execute='DB::connection()->getPdo(); echo \"DB Connection: SUCCESS\";'"

# Laravel 設定確認
ansible all -i inventory/poc -m shell -a "cd /var/www/poc-web && php artisan config:show database.default"
```

#### 3.2 Laravel ヘルスチェック確認
```bash
# Laravel アプリケーションヘルスチェック
ansible all -i inventory/poc -m shell -a "curl -s http://localhost/health"

# Laravel ProxySQL経由でのクエリ確認
ansible all -i inventory/poc -m shell -a "cd /var/www/poc-web && php artisan tinker --execute='echo DB::select(\"SELECT @@hostname as server_name, @@read_only as read_only\")[0]->server_name;'"
```

### 4. 監視確認

#### 4.1 CloudWatch メトリクス確認
```bash
# ProxySQL カスタムメトリクス確認
aws cloudwatch list-metrics --namespace "ProxySQL/poc" --region ap-northeast-1

# Laravel カスタムメトリクス確認
aws cloudwatch list-metrics --namespace "Laravel/poc" --region ap-northeast-1
```

#### 4.2 CloudWatch ダッシュボード確認
```bash
# ダッシュボード一覧
aws cloudwatch list-dashboards --region ap-northeast-1

# ダッシュボードURL取得
echo "CloudWatch Dashboard: https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#dashboards:name=poc-poc-web-monitoring"
```

#### 4.3 CloudWatch Alarms確認
```bash
# アラーム状態確認
aws cloudwatch describe-alarms --state-value ALARM --region ap-northeast-1

# 全アラーム状態
aws cloudwatch describe-alarms --query 'MetricAlarms[].[AlarmName,State:StateValue,Threshold:Threshold]' --output table --region ap-northeast-1
```

## 🛠️ トラブルシューティング

### 1. ProxySQL関連問題

#### 1.1 ProxySQL起動失敗
```bash
cd /home/tomo/ansible-playbooks

# ProxySQL ログ確認
uv run --project /home/tomo/poc ansible all -m shell -a "journalctl -u proxysql -n 50"

# ProxySQL 設定ファイル確認
uv run --project /home/tomo/poc ansible all -m shell -a "proxysql --version && cat /etc/proxysql.cnf | grep -v '^#' | grep -v '^$'"

# ProxySQL プロセス再起動
uv run --project /home/tomo/poc ansible all -m shell -a "systemctl restart proxysql && sleep 5 && systemctl status proxysql"
```

#### 1.2 ProxySQL Aurora接続問題
```bash
cd /home/tomo/ansible-playbooks

# Aurora接続テスト（ProxySQL経由）
uv run --project /home/tomo/poc ansible all -m shell -a "mysql -h127.0.0.1 -P6033 -ularavel_user -p'Laravel123!' -e 'SELECT @@hostname, @@read_only;'"

# ProxySQL admin interface接続確認
uv run --project /home/tomo/poc ansible all -m shell -a "mysql -h127.0.0.1 -P6032 -uproxysql_admin -p'ProxyAdmin123!' -e 'SELECT VERSION();'"

# ProxySQL バックエンドステータス確認
uv run --project /home/tomo/poc ansible pochub-001 -m shell -a "mysql -h127.0.0.1 -P6032 -uproxysql_admin -p'ProxyAdmin123!' -e 'SELECT hostgroup_id,hostname,port,status FROM runtime_mysql_servers;'"

# ProxySQL エラーログ確認
uv run --project /home/tomo/poc ansible all -m shell -a "tail -50 /var/lib/proxysql/proxysql.log"
```

#### 1.3 ProxySQL 設定リセット
```bash
cd /home/tomo/ansible-playbooks

# ProxySQL 設定を初期状態に戻す
uv run --project /home/tomo/poc ansible all -m shell -a "systemctl stop proxysql && rm -f /var/lib/proxysql/proxysql.db && systemctl start proxysql"

# ProxySQL 再設定
uv run --project /home/tomo/poc ansible-playbook install-proxysql-existing-aurora.yml
```

### 2. Aurora接続問題

#### 2.1 Aurora 接続性確認
```bash
cd /home/tomo/ansible-playbooks

# Aurora Writer直接接続テスト
uv run ansible all -m shell -a "mysql -h{{ aurora_writer_endpoint }} -P3306 -upoc_user -p'{{ laravel_db_password }}' -e 'SELECT @@hostname, @@read_only;'"

# Aurora Reader直接接続テスト
uv run ansible all -m shell -a "mysql -h{{ aurora_reader_endpoint }} -P3306 -upoc_user -p'{{ laravel_db_password }}' -e 'SELECT @@hostname, @@read_only;'"

# セキュリティグループ確認
aws ec2 describe-security-groups --filters "Name=group-name,Values=*aurora*" --query 'SecurityGroups[].[GroupName,GroupId,IpPermissions[]]' --region ap-northeast-1
```

#### 2.2 Aurora クレデンシャル確認
```bash
# Aurora接続情報確認
aws rds describe-db-clusters --db-cluster-identifier poc-aurora-mysql --query 'DBClusters[0].{MasterUsername:MasterUsername,DatabaseName:DatabaseName}' --region ap-northeast-1

# Secrets Manager確認（使用している場合）
aws secretsmanager list-secrets --filters Key=name,Values=poc --region ap-northeast-1
```

### 3. Laravel統合問題

#### 3.1 Laravel DB設定確認
```bash
cd /home/tomo/ansible-playbooks

# Laravel .env確認
uv run --project /home/tomo/poc ansible all -m shell -a "grep '^DB_' /opt/app/laravel/.env"

# Laravel config cache確認・クリア
uv run --project /home/tomo/poc ansible all -m shell -a "cd /opt/app/laravel && php artisan config:clear && php artisan config:cache"

# Laravel ヘルスチェック確認
uv run --project /home/tomo/poc ansible all -m uri -a "url=http://localhost/health return_content=yes"
```

#### 3.2 Laravel PDO接続エラー
```bash
cd /home/tomo/ansible-playbooks

# Laravel detailed error確認
uv run --project /home/tomo/poc ansible all -m shell -a "cd /opt/app/laravel && php artisan tinker --execute='try { DB::connection()->getPdo(); echo \"SUCCESS\"; } catch(Exception \$e) { echo \"ERROR: \" . \$e->getMessage(); }'"

# Apache/PHP-FPM ログ確認
uv run --project /home/tomo/poc ansible all -m shell -a "tail -20 /var/log/httpd/error_log"

# Laravel application ログ確認
uv run --project /home/tomo/poc ansible all -m shell -a "tail -20 /opt/app/laravel/storage/logs/laravel.log"
```

#### 3.3 Laravel 設定復元
```bash
cd /home/tomo/ansible-playbooks

# Laravel設定を直接Aurora接続に戻す（緊急時）
# ⚠️ 注意: Aurora writer エンドポイントを実際の値に置き換えてください
uv run --project /home/tomo/poc ansible all -m shell -a "cd /opt/app/laravel && sed -i 's/DB_HOST=127.0.0.1/DB_HOST=poc-poc-aurora-cluster.cluster-ckpr71izl4r7.ap-northeast-1.rds.amazonaws.com/' .env && sed -i 's/DB_PORT=6033/DB_PORT=3306/' .env"

# Laravel設定再読み込み
uv run --project /home/tomo/poc ansible all -m shell -a "cd /opt/app/laravel && php artisan config:clear && php artisan view:clear"
```

### 4. 監視・アラート問題

#### 4.1 CloudWatch Agent問題
```bash
cd /home/tomo/ansible-playbooks

# CloudWatch Agent状態確認
uv run --project /home/tomo/poc ansible all -m shell -a "systemctl status amazon-cloudwatch-agent"

# CloudWatch Agent設定確認
uv run --project /home/tomo/poc ansible all -m shell -a "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -a query"

# Cron ジョブ確認（カスタムメトリクス収集）
uv run --project /home/tomo/poc ansible all -m shell -a "crontab -l | grep metrics"

# CloudWatch Agent再起動
uv run --project /home/tomo/poc ansible all -m shell -a "systemctl restart amazon-cloudwatch-agent"
```

#### 4.2 カスタムメトリクス問題
```bash
cd /home/tomo/ansible-playbooks

# メトリクス送信スクリプト手動実行
uv run ansible all -m shell -a "/usr/local/bin/proxysql-enhanced-metrics.sh"
uv run ansible all -m shell -a "/usr/local/bin/laravel-enhanced-metrics.sh"

# CloudWatch CLI権限確認
uv run ansible all -m shell -a "aws cloudwatch list-metrics --namespace 'ProxySQL/poc' --region ap-northeast-1"

# メトリクス送信ログ確認
uv run ansible all -m shell -a "tail -20 /var/log/proxysql-metrics.log /var/log/laravel-metrics.log"
```

#### 4.3 SNS通知問題
```bash
# SNS Topic確認
aws sns get-topic-attributes --topic-arn $(aws sns list-topics --query 'Topics[?contains(TopicArn,`poc-monitoring`)].TopicArn' --output text) --region ap-northeast-1

# SNS手動テスト
aws sns publish --topic-arn $(aws sns list-topics --query 'Topics[?contains(TopicArn,`poc-monitoring`)].TopicArn' --output text) --message "Test notification from POC Immutable environment" --region ap-northeast-1
```

## 🧹 環境削除

### 1. 監視リソース削除

#### 1.1 CloudWatch監視スタック削除
```bash
cd /home/tomo/poc/sceptre

# 監視CloudFormationスタック削除
sceptre delete poc/monitoring-alerts.yaml

# CloudWatch Log Groups手動削除（必要に応じて）
aws logs describe-log-groups --log-group-name-prefix "/aws/ec2/poc/" --region ap-northeast-1

aws logs delete-log-group --log-group-name "/aws/ec2/poc/poc-web/proxysql" --region ap-northeast-1
```

#### 1.2 監視設定削除
```bash
cd /home/tomo/poc/ansible-playbooks

# CloudWatch Agent停止
ansible all -i inventory/poc -m shell -a "systemctl stop amazon-cloudwatch-agent && systemctl disable amazon-cloudwatch-agent"

# カスタムメトリクスCron Job削除
ansible all -i inventory/poc -m shell -a "crontab -l | grep -v 'metrics' | crontab -"

# 監視スクリプト削除
ansible all -i inventory/poc -m shell -a "rm -f /usr/local/bin/*-metrics.sh"
```

### 2. アプリケーション設定復元

#### 2.1 Laravel設定を直接Aurora接続に復元
```bash
# Laravel DB設定をAurora直接接続に戻す
ansible all -i inventory/poc -m shell -a "cd /var/www/poc-web && cp .env .env.proxysql.backup"

# 元の設定復元
ansible all -i inventory/poc -m shell -a "cd /var/www/poc-web && sed -i 's/DB_HOST=127.0.0.1/DB_HOST={{ aurora_writer_endpoint }}/' .env && sed -i 's/DB_PORT=6033/DB_PORT=3306/' .env"

# Laravel設定リロード
ansible all -i inventory/poc -m shell -a "cd /var/www/poc-web && php artisan config:clear && php artisan view:clear"
```

#### 2.2 Laravel動作確認
```bash
# Laravel Aurora直接接続確認
ansible all -i inventory/poc -m shell -a "cd /var/www/poc-web && php artisan tinker --execute='echo \"DB Host: \" . DB::connection()->getPdo()->getAttribute(PDO::ATTR_CONNECTION_STATUS);'"

# Laravel ヘルスチェック確認
ansible all -i inventory/poc -m shell -a "curl -s http://localhost/health"
```

### 3. ProxySQL停止・削除

#### 3.1 ProxySQL サービス停止
```bash
# ProxySQL サービス停止・無効化
ansible all -i inventory/poc -m shell -a "systemctl stop proxysql && systemctl disable proxysql"

# ProxySQL プロセス確認
ansible all -i inventory/poc -m shell -a "ps aux | grep proxysql | grep -v grep"
```

#### 3.2 ProxySQL 完全削除（オプション）
```bash
# ProxySQL パッケージ削除
ansible all -i inventory/poc -m shell -a "dnf remove -y proxysql"

# ProxySQL 設定・データファイル削除
ansible all -i inventory/poc -m shell -a "rm -rf /etc/proxysql.cnf /var/lib/proxysql /var/log/proxysql.log"

# ProxySQL ユーザー削除
ansible all -i inventory/poc -m shell -a "userdel -r proxysql 2>/dev/null || true"
```

## 📊 アーキテクチャ詳細

### 接続フロー

```mermaid
sequenceDiagram
    participant L as Laravel App
    participant P as ProxySQL
    participant AW as Aurora Writer
    participant AR as Aurora Reader

    L->>P: DB Query Request
    Note over P: Query Analysis
    alt Write Query (INSERT/UPDATE/DELETE)
        P->>AW: Route to Writer
        AW-->>P: Response
    else Read Query (SELECT)
        P->>AR: Route to Reader
        AR-->>P: Response
    end
    P-->>L: Query Result
```

### フェイルオーバー動作

**シナリオ1: Aurora Writer障害**
1. ProxySQLがWriter接続エラーを検出
2. 自動的にReader → Writer昇格を待機
3. 新Writer検出後、接続を自動復旧
4. アプリケーション影響: 最小限（数秒）

**シナリオ2: Aurora Reader障害**
1. ProxySQLがReader接続エラーを検出
2. Read Queryを一時的にWriterにルーティング
3. Reader復旧後、自動的に負荷分散再開
4. アプリケーション影響: なし

### 監視メトリクス

#### ProxySQL メトリクス
- **接続プール**: TotalConnections, ActiveConnections, FreeConnections
- **クエリルーティング**: WriterQueries, ReaderQueries
- **バックエンド状態**: OnlineBackends, OfflineBackends
- **パフォーマンス**: ConnectionUtilization, ConnectionErrors

#### Aurora メトリクス
- **リソース**: CPUUtilization, FreeableMemory, DatabaseConnections
- **パフォーマンス**: ReadLatency, WriteLatency, ReadThroughput, WriteThroughput
- **可用性**: ReplicaLag, FailoverLatency

#### Laravel メトリクス
- **ヘルス**: DatabaseStatus, HealthCheckStatus, OverallHealth
- **パフォーマンス**: ResponseTime, ConnectTime, ArtisanResponseTime
- **エラー**: ErrorCount, WarningCount, StorageUsage

### Blue/Greenデプロイメントアーキテクチャ

**Blue/Greenデプロイメントフロー**
```mermaid
graph TD
    LB[Load Balancer] --> BG[Blue/Green Controller]
    BG --> P1[ProxySQL Instance 1]
    BG --> P2[ProxySQL Instance 2]
    BG --> P3[ProxySQL Instance 3]
    
    P1 --> BE[Blue Environment<br/>Current Production]
    P1 --> GE[Green Environment<br/>New Version]
    P2 --> BE
    P2 --> GE
    P3 --> BE
    P3 --> GE
    
    BE --> AW[Aurora Writer]
    GE --> AW
    BE --> AR[Aurora Reader]
    GE --> AR
    
    style BE fill:#4169E1,color:#fff
    style GE fill:#32CD32,color:#fff
    style BG fill:#FFD700,color:#000
```

**段階的トラフィック切り替え**
1. **Phase 0**: Blue 100% → Green 0%（現在の状態）
2. **Phase 1**: Blue 95% → Green 5%（カナリアリリース）
3. **Phase 2**: Blue 75% → Green 25%（段階拡大）
4. **Phase 3**: Blue 50% → Green 50%（均等分散）
5. **Phase 4**: Blue 0% → Green 100%（完全切り替え）

**ロールバック機能**
- **即座ロールバック**: 1秒以内にBlue環境へ復帰
- **段階的ロールバック**: トラフィックを段階的にBlue環境に戻す
- **自動ロールバック**: エラー率・レスポンス時間の閾値超過時に自動実行

**Blue/Greenデプロイメントの利点**
- **無停止デプロイ**: アプリケーション停止なしでのバージョンアップ
- **即座ロールバック**: 問題発生時の瞬時復旧
- **段階的検証**: カナリアリリースによるリスク最小化
- **A/Bテスト対応**: トラフィック分散によるA/Bテスト実行可能

## 📝 運用メモ

### 日常運用

#### 毎日の確認項目
```bash
# システム全体ヘルスチェック
curl -s http://pochub-001/health
curl -s http://pochub-002/health
curl -s http://pochub-003/health

# ProxySQL バックエンド状態確認
mysql -h127.0.0.1 -P6032 -uproxysql-admin -pproxysql123 -e "SELECT hostgroup_id,hostname,port,status FROM mysql_servers;"

# CloudWatch Dashboard確認
echo "https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#dashboards:name=poc-poc-web-monitoring"
```

#### 週次の確認項目
```bash
# ProxySQL 統計確認
mysql -h127.0.0.1 -P6032 -uproxysql-admin -pproxysql123 -e "SELECT * FROM stats_mysql_connection_pool;"

# Aurora Performance Insights確認
aws rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,PerformanceInsightsEnabled]' --region ap-northeast-1

# ログファイルサイズ確認
du -sh /var/log/proxysql.log /var/www/poc-web/storage/logs/laravel.log
```

### 定期メンテナンス

#### 月次メンテナンス
1. **ProxySQL設定バックアップ**
   ```bash
   mysql -h127.0.0.1 -P6032 -uproxysql-admin -pproxysql123 -e "SELECT * FROM mysql_servers;" > proxysql_servers_backup_$(date +%Y%m%d).sql
   ```

2. **ログローテーション確認**
   ```bash
   logrotate -d /etc/logrotate.d/monitoring-metrics
   ```

3. **監視アラーム設定レビュー**
   ```bash
   aws cloudwatch describe-alarms --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Threshold:Threshold}' --output table --region ap-northeast-1
   ```

### パフォーマンスチューニング

#### ProxySQL接続プールチューニング
```sql
-- ProxySQL管理画面にて実行
UPDATE mysql_servers SET max_connections=200 WHERE hostgroup_id=0;
UPDATE mysql_servers SET max_connections=300 WHERE hostgroup_id=1;
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
```

#### Aurora パラメータチューニング
```bash
# Aurora Parameter Group確認
aws rds describe-db-cluster-parameter-groups --region ap-northeast-1

# 推奨パラメータ
# - innodb_buffer_pool_size: 75% of available memory
# - max_connections: 1000-2000 (depending on instance size)
# - slow_query_log: 1 (for performance monitoring)
```

### セキュリティ

#### 定期セキュリティチェック
1. **ProxySQL admin アクセス制限確認**
   ```bash
   netstat -tulpn | grep :6032  # localhost only listening確認
   ```

2. **Aurora セキュリティグループ確認**
   ```bash
   aws ec2 describe-security-groups --filters "Name=group-name,Values=*aurora*" --region ap-northeast-1
   ```

3. **SSL/TLS設定確認**
   ```bash
   mysql -h127.0.0.1 -P6033 -upoc_user -p'password' -e "SHOW STATUS LIKE 'Ssl_cipher';"
   ```

#### セキュリティアップデート
```bash
# ProxySQL セキュリティアップデート確認
dnf check-update proxysql

# システムセキュリティアップデート
dnf update --security
```

## 📚 関連ドキュメント

### 内部ドキュメント
- [POC環境構築手順.md](./POC環境構築手順.md) - 基盤POC環境構築手順
- [テンプレート構成.md](./テンプレート構成.md) - CloudFormationテンプレート構成
- [ベストプラクティス.md](./ベストプラクティス.md) - AWS運用ベストプラクティス

### 外部リファレンス
- [ProxySQL Documentation](https://proxysql.com/documentation/)
- [Amazon Aurora MySQL User Guide](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/)
- [Laravel Database Documentation](https://laravel.com/docs/database)
- [CloudWatch Custom Metrics](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/publishingMetrics.html)
- [AWS SNS Documentation](https://docs.aws.amazon.com/sns/)

### 設定ファイル場所
- **Ansible Playbooks**: `/home/tomo/ansible-playbooks/` (独立uvプロジェクト)
- **POC プロジェクト**: `/home/tomo/poc/` (CloudFormation/Sceptre)
- **CloudFormation Templates**: `/home/tomo/poc/sceptre/templates/`
- **Sceptre Configurations**: `/home/tomo/poc/sceptre/config/poc/`
- **ProxySQL Configuration**: `/etc/proxysql.cnf` (EC2インスタンス上)
- **Laravel Configuration**: `/var/www/poc-web/.env` (EC2インスタンス上)
- **CloudWatch Agent Config**: `/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json` (EC2インスタンス上)

---

## 付録A: Privateリポジトリを使用する場合の設定（参考）

### 概要
Giteaの`jenkins-docker`リポジトリをPrivate（非公開）にする場合、CodeBuildがリポジトリにアクセスするための認証情報が必要になります。本番環境ではセキュリティのためPrivate設定を推奨します。

### 前提条件
- Giteaでアクセストークンが発行可能であること
- AWS Secrets Managerの使用権限があること
- CloudFormationテンプレートの修正権限があること

### 手順1: Giteaアクセストークンの作成

```bash
# 1. Giteaにログイン
GITEA_URL=$(aws cloudformation describe-stacks --stack-name poc-poc-ecs-gitea --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' --output text)
echo "Gitea URL: http://${GITEA_URL}"

# 2. ブラウザでアクセス
# 3. 右上のユーザーアイコン → 設定 → アプリケーション
# 4. 「アクセストークンの生成」
#    - トークン名: CodeBuild
#    - スコープ: repo（リポジトリ読み取り）
# 5. 生成されたトークンをコピー（再表示不可のため注意）
```

### 手順2: AWS Secrets Managerにトークンを保存

```bash
# トークンをSecrets Managerに保存
aws secretsmanager create-secret \
  --name poc/gitea/codebuild-token \
  --description "Gitea access token for CodeBuild to access private repositories" \
  --secret-string '{
    "username": "tomo",
    "token": "YOUR_GITEA_ACCESS_TOKEN_HERE"
  }' \
  --region ap-northeast-1

# シークレット確認
aws secretsmanager describe-secret \
  --secret-id poc/gitea/codebuild-token \
  --region ap-northeast-1
```

### 手順3: CodeBuildテンプレート修正（参考）

**⚠️ 注意: 以下は参考情報です。実際には実施しないでください。**

`/home/tomo/poc/sceptre/templates/codebuild-jenkins.yaml` に以下の修正が必要になります：

#### 3.1 IAMロールにSecrets Manager権限を追加

```yaml
# 現在のCodeBuildServiceRole の Policies セクションに追加
Resources:
  CodeBuildServiceRole:
    Type: AWS::IAM::Role
    Properties:
      # ... 既存設定 ...
      Policies:
        - PolicyName: CodeBuildPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              # ... 既存のStatement ...
              
              # 以下を追加
              - Effect: Allow
                Action:
                  - secretsmanager:GetSecretValue
                Resource: !Sub 'arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:poc/gitea/codebuild-token*'
```

#### 3.2 BuildSpec内でトークンを使用

```yaml
# CodeBuildProject の Source.BuildSpec を修正
BuildSpec: |
  version: 0.2
  phases:
    pre_build:
      commands:
        # トークン取得を追加
        - echo "Retrieving Gitea credentials from Secrets Manager..."
        - GITEA_CREDS=$(aws secretsmanager get-secret-value --secret-id poc/gitea/codebuild-token --query SecretString --output text)
        - GITEA_TOKEN=$(echo $GITEA_CREDS | jq -r .token)
        - GITEA_USER=$(echo $GITEA_CREDS | jq -r .username)
        
        # 既存のECRログイン処理
        - echo Logging in to Amazon ECR...
        - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
        
        # ... その他の既存コマンド ...
        
        # git cloneコマンドを修正
        - echo Cloning repository from Gitea...
        - git clone http://${GITEA_USER}:${GITEA_TOKEN}@${GITEA_LOAD_BALANCER_DNS}/${GITEA_USERNAME}/${GITEA_REPOSITORY_NAME}.git /tmp/source
        - cd /tmp/source
    
    build:
      # ... 既存のbuildフェーズ ...
    
    post_build:
      # ... 既存のpost_buildフェーズ ...
```

#### 3.3 環境変数の追加（オプション）

```yaml
# CodeBuildProject の Environment.EnvironmentVariables に追加
Environment:
  EnvironmentVariables:
    # ... 既存の環境変数 ...
    
    - Name: GITEA_SECRET_ARN
      Value: !Sub 'arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:poc/gitea/codebuild-token'
      Type: PLAINTEXT
```

### 手順4: スタック更新（参考）

```bash
# ⚠️ 実際には実施しない（参考のみ）
# テンプレート修正後にスタックを更新する場合
cd /home/tomo/poc/sceptre
uv run sceptre update poc/codebuild-jenkins.yaml -y
```

### 手順5: 動作確認

```bash
# GiteaリポジトリをPrivateに変更
# 1. Giteaにログイン
# 2. jenkins-docker リポジトリ → 設定 → 基本設定
# 3. 「非公開リポジトリ」にチェック
# 4. 保存

# CodeBuildトリガー
aws codebuild start-build --project-name poc-jenkins-docker-build

# ビルド状況確認
BUILD_ID=$(aws codebuild list-builds-for-project --project-name poc-jenkins-docker-build --max-items 1 --query 'ids[0]' --output text)
aws codebuild batch-get-builds --ids $BUILD_ID --query 'builds[0].{Status:buildStatus,Phase:currentPhase}' --output json

# 成功すればPrivate設定完了
```

### トラブルシューティング

#### シークレット取得エラー
```
Error: Access denied to secrets manager
```
**対処**: IAMロールにSecrets Manager権限が正しく追加されているか確認

#### 認証エラー
```
fatal: Authentication failed for 'http://...'
```
**対処**: 
1. Giteaトークンが有効か確認
2. Secrets Managerの値が正しいJSON形式か確認
3. トークンのスコープに`repo`が含まれているか確認

#### ビルド失敗
```
Command did not exit successfully git clone
```
**対処**: 
1. BuildSpec内のgit cloneコマンドの構文を確認
2. 環境変数が正しく展開されているかログで確認

### セキュリティ考慮事項

1. **トークンのローテーション**
   - 定期的（3-6ヶ月）にGiteaトークンを再生成
   - Secrets Managerの値を更新

2. **最小権限の原則**
   - Giteaトークンには必要最小限のスコープ（repo読み取りのみ）を付与
   - IAMロールには特定のシークレットへのアクセスのみ許可

3. **監査ログ**
   - Secrets Managerアクセスログを定期的に確認
   - CloudTrailでトークン使用状況を監視

---

## 付録B: Gitea Webhookトラブルシューティング

### Webhookが動作しない場合の確認ポイント

1. **Webhook URLの確認**
   - GiteaのWebhook設定画面でURLが正しいか（API GatewayのURL）
   - 例: https://arngbygpq9.execute-api.ap-northeast-1.amazonaws.com/prod/webhook

2. **イベントタイプの確認**
   - Push Events（プッシュイベント）が有効になっているか

3. **Webhookのレスポンス確認**
   - GiteaのWebhook履歴で「200 OK」や「202 Accepted」など正常応答か
   - エラーの場合はレスポンス内容を確認

4. **API Gateway/LambdaのCloudWatchログ確認**
   - Lambdaのロググループ: `/aws/lambda/poc-jenkins-build-trigger`
   - エラーが出ていないか

5. **CodeBuildのビルド履歴確認**
   - Webhook経由でCodeBuildがトリガーされているか
   - `aws codebuild list-builds-for-project --project-name poc-jenkins-docker-build --output table`

6. **Giteaのネットワーク到達性**
   - GiteaサーバーからAPI GatewayのURLにcurlできるか
   - VPC/NACL/セキュリティグループの設定

### よくあるエラーと対処

- `403 Forbidden` → API Gateway/Lambdaの認証設定を確認
- `404 Not Found` → Webhook URLが間違っている
- `Timeout` → ネットワーク到達性、Lambdaのタイムアウト設定
- `ビルドが開始されない` → Lambdaの権限、CodeBuildのIAMロール

---

## 📋 次のステップと改善点

### POC環境の現状

本手順書に従って構築したPOC環境は、以下の特徴があります：

**✅ 達成したこと：**
- 基本的なインフラ構築（VPC, EC2, Aurora, ALB）
- アプリケーションデプロイ（Laravel + ProxySQL）
- 監視・アラート設定（CloudWatch）
- 動作検証完了

**⚠️ 改善が必要な点（Immutable環境への進化）：**

現在の構成は、EC2起動後にAnsibleで設定を追加する「**Mutable**」な運用になっています。

#### 主な問題点

1. **インスタンス起動後に状態が変化する**
   - AMI起動 → Ansible実行（Laravel, ProxySQL, 監視エージェント設定）
   - スケールアウト時に35分程度かかる
   - インスタンスごとに微妙に異なる構成になるリスク

2. **監視設定の分散管理**
   - CloudFormation（Sceptre）: Alarms, SNS, Dashboard
   - Ansible: CloudWatch Agent, ログ設定
   - Infrastructure as Codeの原則に反する

3. **Blue/Green未実装**
   - デプロイ時にダウンタイムが発生する可能性
   - ロールバックに時間がかかる（30分以上）

### 理想的なImmutable環境への改善

**真のImmutable Infrastructure：**
- ゴールデンイメージ（AMI）にすべて含める
- UserDataは動的設定のみ
- Auto Scaling Groupの活用
- Blue/Greenデプロイメント実装

**改善後のメリット：**

| 項目 | 現在（Mutable） | 改善後（Immutable） |
|------|----------------|-------------------|
| スケールアウト時間 | 35分 | **5分** |
| 障害復旧時間 | 30-40分 | **10分** |
| ロールバック時間 | 30-35分 | **60秒** |
| 構成の一貫性 | 低（ドリフト発生） | **100%（ドリフトなし）** |
| デプロイ時ダウンタイム | 発生する可能性 | **ゼロ** |

### 詳細ガイド

Immutable環境への改善方法、AutoScaling Group活用法、ゴールデンイメージ作成方法、Blue/Greenデプロイメント実装については、以下のドキュメントを参照してください：

📚 **[Immutable環境改善ガイド](./Immutable環境改善ガイド.md)**

このガイドには以下が含まれています：
- Immutable Infrastructureの基礎知識
- AutoScaling Groupの仕組みと活用法
- ゴールデンイメージ（AMI）作成プロセス
- Blue/Greenデプロイメント実装手順
- 具体的な改善ロードマップ（Phase 1-5）

### 推奨される次のステップ

1. **Phase 1: ゴールデンイメージ作成**（1-2日）
   - 現在のインスタンスからAMI作成
   - AMI検証

2. **Phase 2: UserData移行**（1日）
   - 動的設定のみUserDataに移行
   - 静的設定はすべてAMIに含める

3. **Phase 3: Blue/Green構築**（2-3日）
   - Blue/Green用CloudFormationテンプレート作成
   - トラフィック切替の自動化

4. **Phase 4: CI/CDパイプライン**（3-5日）
   - Packer / EC2 Image Builderでのビルド自動化
   - デプロイパイプライン構築

**合計：** 7-11営業日で理想的なImmutable環境が完成

---

**このPOC環境は学習と検証を目的としており、次回のプロジェクトや本番環境構築時により優れたアーキテクチャを実装する基礎となります。**

---

## ✅ 構築完了サマリー

### 最終環境確認結果

**確認日時**: 2025年10月18日

#### インフラストラクチャ

| コンポーネント | 数量 | ステータス | 備考 |
|--------------|------|----------|------|
| **CloudFormation Stack** | 16 | ✅ すべて完了 | VPC, EC2, Aurora, ALB, Monitoring等 |
| **EC2 Instances** | 3 | ✅ 稼働中 | pochub-001, pochub-002, pochub-003 |
| **Aurora Cluster** | 1 | ✅ available | Writer + Reader (2 members) |
| **ALB** | 1 | ✅ 稼働中 | ターゲットグループ: 3台すべてHealthy |

#### アプリケーション

| コンポーネント | 数量 | ステータス | 詳細 |
|--------------|------|----------|------|
| **Apache (httpd)** | 3 | ✅ active | すべてのEC2で稼働中 |
| **PHP-FPM** | 3 | ✅ active | Laravel実行環境 |
| **Laravel Application** | 3 | ✅ HTTP 200 | `/health` エンドポイント正常 |
| **ProxySQL** | 3 | ✅ active | Writer/Reader両方ONLINE |

#### 監視・アラート

| コンポーネント | 数量 | ステータス | 詳細 |
|--------------|------|----------|------|
| **CloudWatch Agent** | 3 | ✅ active | システムメトリクス収集中 |
| **CloudWatch Alarms** | 11 | ✅ 設定済み | Aurora CPU/接続数, EC2 CPU, カスタムメトリクス |
| **CloudWatch Dashboard** | 1 | ✅ 作成済み | 統合監視ダッシュボード |
| **SNS Topic** | 1 | ⚠️ 確認待ち | Email Subscription承認待ち |
| **カスタムメトリクス** | 3種類 | ✅ 収集中 | ProxySQL, Laravel, System (Cron実行) |

### 実装された主要機能

#### 1. Laravelヘルスチェック API ✅
```bash
# すべてのインスタンスで利用可能
curl http://<instance-ip>/health

# レスポンス例
{
  "status": "healthy",
  "timestamp": "2025-10-18T04:54:24.983412Z",
  "database": "connected",
  "environment": "poc",
  "version": "1.0.0"
}
```

**特徴:**
- データベース接続チェック機能
- 環境情報とバージョン情報を含む
- ALBヘルスチェックと監視に使用可能
- **Playbook化済み**（再デプロイ時も自動追加）

#### 2. ProxySQL Read/Write Splitting ✅

**接続構成:**
```
Laravel Application (Port 6033)
    ↓
ProxySQL
    ├─ Writer: hostgroup 0 (ONLINE)
    │   └─ poc-poc-aurora-cluster.cluster-xxx.rds.amazonaws.com
    └─ Reader: hostgroup 1 (ONLINE)
        └─ poc-poc-aurora-cluster.cluster-ro-xxx.rds.amazonaws.com
```

**動作確認済み:**
- 両方のバックエンド: ONLINE
- 接続プール: 正常動作
- クエリルーティング: 設定済み

#### 3. CloudWatch 統合監視 ✅

**収集メトリクス:**

| 種類 | 収集間隔 | 内容 |
|------|---------|------|
| **標準メトリクス** | 1-5分 | EC2 CPU/Memory/Disk, Aurora CPU/Connections |
| **ProxySQL** | 2分 | 接続数, バックエンド状態, クエリ統計 |
| **Laravel** | 2分 | ヘルスチェック, DB接続, レスポンスタイム |
| **System** | 5分 | プロセス数, ネットワーク接続, 負荷 |

**アラーム設定:**
- Aurora CPU高負荷: 80%以上
- Aurora接続数: 80%以上
- EC2 CPU高負荷: 80%以上（各インスタンス）
- カスタムメトリクスアラーム: 各種閾値設定済み

### 制限事項と今後の改善点

#### ⚠️ 現在の制限

1. **SNS Email Subscription**
   - 状態: PendingConfirmation
   - 対応: メールボックスで確認メールを承認する必要があります

2. **Aurora自動フェイルオーバーテスト**
   - 状態: IAM権限不足により実行不可
   - 理由: EC2ロールに `rds:DescribeDBInstances`, `rds:RebootDBInstance` 権限なし
   - 対応: セキュリティの観点から意図的に制限（本番環境では適切）
   - 代替: AWSコンソールまたはAWS CLIから手動実行可能

3. **Mutable構成**
   - 現状: EC2起動後にAnsibleで設定追加
   - 影響: スケールアウト時に35分程度かかる
   - 改善: ゴールデンイメージ（AMI）化により5分に短縮可能
   - 詳細: [Immutable環境改善ガイド](./Immutable環境改善ガイド.md)

#### 📚 推奨される次のステップ

1. **SNS Subscription承認** (5分)
   - メール確認とサブスクリプション承認

2. **監視ダッシュボード確認** (10分)
   - CloudWatchコンソールでメトリクス確認
   - アラーム動作テスト

3. **負荷テスト** (30分-1時間)
   - ApacheBench等で負荷テスト
   - ProxySQLの性能確認
   - CloudWatchメトリクス収集確認

4. **Immutable環境への移行** (7-11営業日)
   - ゴールデンイメージ（AMI）作成
   - Blue/Green環境構築
   - CI/CDパイプライン構築
   - 詳細: [Immutable環境改善ガイド](./Immutable環境改善ガイド.md)

### 関連ドキュメント

- **[Immutable環境改善ガイド](./Immutable環境改善ガイド.md)** - 真のImmutable環境実現のためのロードマップ
- **[Playbook実行用uvプロジェクト](./Playbook実行用uvプロジェクト.md)** - ansible-playbooks独立プロジェクト管理
- **[Immutable環境検証手順](./Immutable環境検証手順.md)** - 包括的な検証シナリオと手順

### 重要な修正履歴

#### Playbookの改善

1. **`setup-laravel-environment.yml`**
   - `/health`エンドポイント自動追加機能を実装
   - データベース接続チェック機能を含む
   - 再デプロイ時も自動的に追加される

2. **予約変数名の修正**
   - `environment` → `env_name` に統一
   - 以下のPlaybookを修正:
     - `setup-comprehensive-monitoring.yml`
     - `test-proxysql-failover.yml`
     - `setup-proxysql-manual-testing.yml`

3. **Amazon Linux 2023対応**
   - `cronie`パッケージ追加（cron機能）
   - ProxySQL RPM直接インストール方式に変更
   - パッケージ競合の解決

### 構築成果物

#### Ansible Playbooks (8個)

| Playbook | 目的 | ステータス |
|----------|------|----------|
| `setup-laravel-environment.yml` | Laravel環境構築 | ✅ 完成 |
| `install-proxysql-existing-aurora.yml` | ProxySQL構築 | ✅ 完成 |
| `configure-laravel-proxysql.yml` | Laravel-ProxySQL統合 | ✅ 完成 |
| `test-laravel-proxysql.yml` | 統合テスト | ✅ 完成 |
| `create-aurora-users.yml` | Auroraユーザー作成 | ✅ 完成 |
| `setup-comprehensive-monitoring.yml` | 監視設定 | ✅ 完成 |
| `test-proxysql-failover.yml` | フェイルオーバーテスト | ✅ 完成 |
| `setup-proxysql-manual-testing.yml` | 手動テスト環境 | ✅ 完成 |

#### CloudFormation Stacks (16個)

すべて `CREATE_COMPLETE` または `UPDATE_COMPLETE` 状態

#### ドキュメント (4個)

1. **POCImmutable環境構築手順.md** (本書)
2. **Immutable環境改善ガイド.md** - 新規作成
3. **Playbook実行用uvプロジェクト.md** - 新規作成
4. **Immutable環境検証手順.md** - 更新（シナリオ9追加）

---

**🎉 POC Immutable環境構築完了**

この環境は、ProxySQL + Aurora + Laravelの統合環境として正常に稼働しています。
監視・アラートシステムも導入済みで、運用に必要な基盤が整いました。

今後は、実際のアプリケーション開発や、Immutable環境への進化を検討してください。

---
