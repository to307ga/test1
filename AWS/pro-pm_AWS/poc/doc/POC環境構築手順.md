# POC環境構築手順

## � 目次

- [📋 概要](#-概要)
- [🏗️ 構築される環境](#️-構築される環境)
  - [Stage 1: 基本インフラ構成](#stage-1-基本インフラ構成)
  - [Stage 2: アプリケーション層（今後追加予定）](#stage-2-アプリケーション層今後追加予定)
- [🔧 前提条件](#-前提条件)
  - [1. AWS環境](#1-aws環境)
  - [2. 必要なIAM権限](#2-必要なiam権限)
  - [3. ローカル環境](#3-ローカル環境)
- [🚀 デプロイ手順](#-デプロイ手順)
  - [📋 構築アプローチ](#-構築アプローチ)
  - [Step 1: 環境準備](#step-1-環境準備)
  - [Step 2: テンプレート検証](#step-2-テンプレート検証)
  - [Step 3: Stage 1 - 基本インフラデプロイ](#step-3-stage-1---基本インフラデプロイ)
  - [Step 4: Stage 2 - アプリケーション層（今後実装）](#step-4-stage-2---アプリケーション層今後実装)
  - [Step 5: 一括デプロイ（Stage 1のみ推奨）](#step-5-一括デプロイstage-1のみ推奨)
- [🔍 デプロイ確認](#-デプロイ確認)
  - [1. スタック状態確認](#1-スタック状態確認)
  - [2. 接続確認](#2-接続確認)
- [🛠️ トラブルシューティング](#️-トラブルシューティング)
  - [1. 一般的なエラー](#1-一般的なエラー)
  - [2. リソース固有のトラブル](#2-リソース固有のトラブル)
  - [3. ネットワーク問題](#3-ネットワーク問題)
  - [4. Jenkins Docker ビルドパイプライン問題](#4-jenkins-docker-ビルドパイプライン問題)
- [🧹 環境削除](#-環境削除)
  - [1. Stage 1 削除](#1-stage-1-削除)
  - [2. Stage 2 削除（今後追加時）](#2-stage-2-削除今後追加時)
  - [3. 一括削除](#3-一括削除)
  - [4. 削除確認](#4-削除確認)
- [📊 コスト見積もり](#-コスト見積もり)
  - [Stage 1 月間概算コスト（ap-northeast-1）](#stage-1-月間概算コストap-northeast-1)
  - [将来のStage 2追加時の概算コスト](#将来のstage-2追加時の概算コスト)
- [📝 運用メモ](#-運用メモ)
  - [Stage 1 現在の構成](#stage-1-現在の構成)
  - [定期メンテナンス](#定期メンテナンス)
  - [監視項目（Stage 1）](#監視項目stage-1)
  - [Stage 2 移行時の考慮事項](#stage-2-移行時の考慮事項)
  - [セキュリティ](#セキュリティ)
- [📚 関連ドキュメント](#-関連ドキュメント)

## �📋 概要

このドキュメントは、SceptreとCloudFormationを使用してAWS上にPOC環境を構築する手順を記載しています。

## 🏗️ 構築される環境

### Stage 1: 基本インフラ構成
- **VPC**: 3AZ構成（ap-northeast-1a/1c/1d）
- **ALB**: Application Load Balancer（TCP health check）
- **EC2**: Auto Scaling Group（固定3台、ホスト名: pochub-001/002/003）
- **Systems Manager**: Session Manager接続、パッチ管理
- **IAM**: 基本ロール・グループ

### Stage 2: アプリケーション層（今後追加予定）
- **ECS Fargate**: Jenkins CI/CD + Gitea Git Repository
- **Aurora MySQL**: Writer/Reader構成
- **S3**: ログ保存用バケット

## 🔧 前提条件

### 1. AWS環境
- AWSアカウントが利用可能
- AWS CLIがインストール・設定済み
- 適切なIAM権限を持つユーザー/ロール

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
        "ecs:*",
        "rds:*",
        "iam:*",
        "s3:*",
        "ssm:*",
        "secretsmanager:*",
        "elasticloadbalancing:*",
        "elasticfilesystem:*",
        "logs:*",
        "sns:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3. ローカル環境
- Python 3.8以上 (`uv run python` で実行)
- Sceptre 4.0以上
- AWS CLI 2.x
- uv (Python パッケージマネージャー)

## 🚀 デプロイ手順

### 📋 構築アプローチ

本POC環境は段階的構築アプローチを採用しています：

1. **Stage 1**: 最小限のEC2 + ALB構成
   - OS起動レベルのヘルスチェック（SSH TCP:22）
   - Jenkins等のアプリケーションデプロイ前の基盤確認

2. **Stage 2**: アプリケーション層追加（今後）
   - Jenkinsパイプラインによるアプリケーションデプロイ
   - HTTP ヘルスチェックへの進化

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
cd /home/t-tomonaga/AWS/AWS_POC/poc/sceptre

# Sceptre動作確認
uv run sceptre --version

# 設定ファイル構文チェック
uv run sceptre validate config/poc/
```

### Step 2: テンプレート検証

#### 2.1 CloudFormationテンプレート検証
```bash
# 全テンプレートの構文チェック
for template in templates/*.yaml; do
  echo "=== Validating $(basename $template) ==="
  aws cloudformation validate-template \
    --template-body file://$template \
    --region ap-northeast-1
done
```

#### 2.2 依存関係確認
```bash
# Sceptre依存関係可視化
uv run sceptre list dependencies config/poc/
```

### Step 3: Stage 1 - 基本インフラデプロイ

#### 3.1 基盤インフラ（必須順序）
```bash
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
```

#### 3.2 Application Load Balancer
```bash
# ALB（TCP health check on SSH port 22）
uv run sceptre create poc/alb.yaml -y
```

#### 3.3 EC2 Auto Scaling Group
```bash
# EC2 インスタンス（ELB health check使用）
uv run sceptre create poc/ec2.yaml -y
```

#### 3.4 Stage 1 確認
```bash
# 全Stage 1スタックの状態確認
uv run sceptre status poc

# EC2インスタンス確認（ホスト名設定確認）
aws ec2 describe-instances --filters "Name=tag:Environment,Values=poc" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],Tags[?Key==`Hostname`].Value|[0],PrivateIpAddress]' --output table --region ap-northeast-1

# ALB ターゲットグループ ヘルス確認
ALB_TG_ARN=$(aws cloudformation describe-stacks --stack-name poc-poc-alb --query 'Stacks[0].Outputs[?OutputKey==`TargetGroupArn`].OutputValue' --output text --region ap-northeast-1)

aws elbv2 describe-target-health --target-group-arn $ALB_TG_ARN --region ap-northeast-1

```

### Step 4: Stage 2 - アプリケーション層

#### 4.1 データベース
```bash
# Aurora MySQL（時間がかかります：約10-15分）
uv run sceptre create poc/aurora.yaml -y
```

#### 4.2 コンテナサービス（Git Repository）
```bash
# Gitea（ECS Fargate）- Jenkins Docker ビルド用リポジトリホスト
uv run sceptre create poc/ecs-gitea.yaml -y

# URL取得
aws cloudformation describe-stacks --stack-name poc-poc-ecs-gitea --query 'Stacks[0].Outputs[?OutputKey==`GiteaURL`].OutputValue' --
output text --region ap-northeast-1
```

#### 4.3 Jenkins Docker ビルドパイプライン
```bash
# ECRリポジトリ（Jenkins用Docker イメージ保存）
uv run sceptre create poc/ecr-jenkins.yaml -y

# CodeBuildプロジェクト（Jenkins Docker イメージビルド）
uv run sceptre create poc/codebuild-jenkins.yaml -y

# Jenkins ビルドトリガー（Gitea Webhook → Lambda → CodeBuild）
uv run sceptre create poc/jenkins-build-trigger.yaml -y

# ECR リポジトリ一覧
aws ecr describe-repositories --region ap-northeast-1
```

#### 4.4 コンテナサービス（Jenkins）
```bash
# Jenkins（ECS Fargate）- カスタムイメージを使用
uv run sceptre create poc/ecs-jenkins.yaml -y
```

#### 4.5 運用・ストレージ
```bash
# S3バケット（ログ保存用）
uv run sceptre create poc/s3.yaml -y

# Systems Manager パッチ管理
uv run sceptre create poc/ssm-patch-management.yaml -y
```

#### 4.6 EBSスナップショット自動バックアップ（In-Place方式強化）
```bash
# EBSスナップショット自動取得機能（パッチ適用前バックアップ）
uv run sceptre create poc/ebs-snapshot-backup.yaml -y
```

### Step 5: 一括デプロイ（Stage 1のみ推奨）

Stage 1の依存関係を自動解決してデプロイする場合：

```bash
# Stage 1スタック一括デプロイ
uv run sceptre create poc/fixed-natgw-eip.yaml poc/vpc.yaml poc/alb-securitygroup.yaml poc/securitygroup.yaml poc/iam-group.yaml poc/alb.yaml poc/ec2.yaml -y

# 進捗確認
uv run sceptre status poc
```

## 🔍 デプロイ確認

### 1. スタック状態確認
```bash
# 全スタックの状態確認
uv run sceptre status poc

# 個別スタック詳細確認
aws cloudformation describe-stacks \
  --stack-name poc-vpc \
  --region ap-northeast-1

# リソース一覧確認
aws cloudformation list-stack-resources \
  --stack-name poc-vpc \
  --region ap-northeast-1
```

### 2. 接続確認

#### 2.1 EC2インスタンス（ホスト名確認）
```bash
# EC2インスタンス一覧とホスト名確認
aws ec2 describe-instances --filters "Name=tag:Environment,Values=poc" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Hostname`].Value|[0],AvailabilityZone,PrivateIpAddress,State.Name]' --output table --region ap-northeast-1

# SSM Session Manager接続テスト
aws ssm start-session --target i-014cda05e3794eb17 --region ap-northeast-1

# ホスト名確認（Session Manager内で実行）
hostname
cat /var/log/hostname-setup.log
```

#### 2.2 ALB ヘルスチェック確認
```bash
# ALB 情報取得
aws cloudformation describe-stacks \
  --stack-name poc-alb \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' \
  --output table \
  --region ap-northeast-1

# Target Group ヘルス確認
ALB_TG_ARN=$(aws cloudformation describe-stacks \
  --stack-name poc-alb \
  --query 'Stacks[0].Outputs[?OutputKey==`TargetGroupArn`].OutputValue' \
  --output text \
  --region ap-northeast-1)

aws elbv2 describe-target-health \
  --target-group-arn $ALB_TG_ARN \
  --region ap-northeast-1
```

#### 2.3 Jenkins（Stage 2で追加予定）
```bash
# Jenkins ALB DNS名取得
aws cloudformation describe-stacks \
  --stack-name poc-ecs-jenkins \
  --query 'Stacks[0].Outputs[?OutputKey==`JenkinsURL`].OutputValue' \
  --output text \
  --region ap-northeast-1

# ブラウザでアクセス: http://[ALB-DNS-NAME]
```

#### 2.4 Gitea（Stage 2で追加予定）
```bash
# Gitea ALB DNS名取得
aws cloudformation describe-stacks \
  --stack-name poc-ecs-gitea \
  --query 'Stacks[0].Outputs[?OutputKey==`GiteaURL`].OutputValue' \
  --output text \
  --region ap-northeast-1

# ブラウザでアクセス: http://[ALB-DNS-NAME]
```

#### 2.5 Aurora MySQL（Stage 2で追加予定）
```bash
# データベース接続情報取得
aws secretsmanager get-secret-value \
  --secret-id poc-aurora/database/credentials \
  --region ap-northeast-1

# RDSエンドポイント確認
aws rds describe-db-clusters \
  --db-cluster-identifier poc-aurora-cluster \
  --region ap-northeast-1
```

#### 2.6 Jenkins Docker ビルドパイプライン
```bash
# ECRリポジトリ確認
aws ecr describe-repositories \
  --repository-names poc-jenkins \
  --region ap-northeast-1

# CodeBuildプロジェクト確認
aws codebuild list-projects \
  --region ap-northeast-1 | grep poc-jenkins

# CodeBuildプロジェクト詳細確認
aws codebuild batch-get-projects \
  --names poc-jenkins-docker-build \
  --region ap-northeast-1

# Lambda関数確認（ビルドトリガー）
aws lambda get-function \
  --function-name poc-jenkins-build-trigger \
  --region ap-northeast-1

# API Gateway確認（Webhook URL）
aws cloudformation describe-stacks \
  --stack-name poc-poc-jenkins-build-trigger \
  --query 'Stacks[0].Outputs[?OutputKey==`WebhookURL`].OutputValue' \
  --output text \
  --region ap-northeast-1

# ビルド履歴確認
aws codebuild list-builds-for-project \
  --project-name poc-jenkins-docker-build \
  --region ap-northeast-1
```

#### 2.7 EBSスナップショット自動バックアップ
```bash
# スナップショット機能の状態確認
aws cloudformation describe-stacks \
  --stack-name poc-ebs-snapshot-backup \
  --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' \
  --output table \
  --region ap-northeast-1

# Lambda関数確認（スナップショット作成）
aws lambda get-function \
  --function-name poc-ebs-snapshot-backup-snapshot-creator \
  --region ap-northeast-1

# EventBridge スケジュール確認
aws events describe-rule \
  --name poc-ebs-snapshot-backup-snapshot-schedule \
  --region ap-northeast-1

# 手動でスナップショット作成テスト
aws lambda invoke \
  --function-name poc-ebs-snapshot-backup-snapshot-creator \
  --region ap-northeast-1 \
  /tmp/snapshot-test-result.json

cat /tmp/snapshot-test-result.json

# 作成されたスナップショット確認
aws ec2 describe-snapshots \
  --owner-ids self \
  --filters "Name=tag:Environment,Values=poc" "Name=tag:BackupType,Values=PrePatch" \
  --query 'Snapshots[].[SnapshotId,Tags[?Key==`Name`].Value|[0],Tags[?Key==`Hostname`].Value|[0],StartTime,State]' \
  --output table \
  --region ap-northeast-1

# スナップショット復旧用ユーティリティ確認
aws lambda invoke \
  --function-name poc-ebs-snapshot-backup-snapshot-restore \
  --payload '{"action":"list_snapshots"}' \
  --region ap-northeast-1 \
  /tmp/snapshot-list-result.json

cat /tmp/snapshot-list-result.json
```

## 🛠️ トラブルシューティング

### 1. 一般的なエラー

#### スタック作成失敗
```bash
# エラー詳細確認
uv run sceptre describe poc/[スタック名].yaml

# CloudFormationイベント確認
aws cloudformation describe-stack-events \
  --stack-name [スタック名] \
  --region ap-northeast-1
```

#### 依存関係エラー
```bash
# 依存関係確認
uv run sceptre list dependencies poc

# 個別スタック作成順序確認
uv run sceptre list dependencies poc --format yaml
```

### 2. リソース固有のトラブル

#### Aurora起動失敗
- **原因1**: サブネットグループまたはセキュリティグループの問題
- **対策1**: VPCスタックの正常性確認

- **原因2**: CloudWatch LogGroupが既に存在（AlreadyExistsエラー）
- **対策2**: 既存LogGroupの削除
  ```bash
  # 既存LogGroup確認
  aws logs describe-log-groups \
    --log-group-name-prefix "/aws/rds/cluster/poc-poc-aurora-cluster" \
    --region ap-northeast-1
  
  # LogGroup削除（必要に応じて）
  aws logs delete-log-group \
    --log-group-name "/aws/rds/cluster/poc-poc-aurora-cluster/error" \
    --region ap-northeast-1
  aws logs delete-log-group \
    --log-group-name "/aws/rds/cluster/poc-poc-aurora-cluster/general" \
    --region ap-northeast-1
  aws logs delete-log-group \
    --log-group-name "/aws/rds/cluster/poc-poc-aurora-cluster/slowquery" \
    --region ap-northeast-1
  
  # 失敗したスタック削除（必要に応じて）
  aws cloudformation delete-stack \
    --stack-name poc-poc-aurora \
    --region ap-northeast-1
  ```

- **注意**: AuroraクラスターやRDS削除時、CloudWatch LogGroupは自動削除されません

### 6. CloudWatch LogGroup削除（手動クリーンアップ）

CloudFormationスタック削除後、以下のLogGroupが残留している場合があります：

```bash
# poc関連のCloudWatch LogGroup確認
aws logs describe-log-groups \
  --query 'logGroups[?contains(logGroupName, `poc`)].{LogGroupName:logGroupName,CreationTime:creationTime,StoredBytes:storedBytes}' \
  --output table \
  --region ap-northeast-1

# 残留LogGroupの一括削除
# ECS Container Insights
aws logs delete-log-group \
  --log-group-name "/aws/ecs/containerinsights/poc-poc-ecs-gitea-cluster/performance" \
  --region ap-northeast-1
aws logs delete-log-group \
  --log-group-name "/aws/ecs/containerinsights/poc-poc-ecs-jenkins-cluster/performance" \
  --region ap-northeast-1

# Lambda関数
aws logs delete-log-group \
  --log-group-name "/aws/lambda/poc-jenkins-build-trigger" \
  --region ap-northeast-1
aws logs delete-log-group \
  --log-group-name "/aws/lambda/poc-poc-ec2-auto-tagging" \
  --region ap-northeast-1

# Aurora Cluster
aws logs delete-log-group \
  --log-group-name "/aws/rds/cluster/poc-poc-aurora-cluster/error" \
  --region ap-northeast-1
aws logs delete-log-group \
  --log-group-name "/aws/rds/cluster/poc-poc-aurora-cluster/general" \
  --region ap-northeast-1
aws logs delete-log-group \
  --log-group-name "/aws/rds/cluster/poc-poc-aurora-cluster/slowquery" \
  --region ap-northeast-1

# EBSスナップショットバックアップ
aws logs delete-log-group \
  --log-group-name "/aws/lambda/poc-poc-ebs-snapshot-backup-snapshot-creator" \
  --region ap-northeast-1
aws logs delete-log-group \
  --log-group-name "/aws/lambda/poc-poc-ebs-snapshot-backup-snapshot-restore" \
  --region ap-northeast-1

# 削除確認
aws logs describe-log-groups \
  --query 'logGroups[?contains(logGroupName, `poc`)].LogGroupName' \
  --output text \
  --region ap-northeast-1
```

#### ECS タスク起動失敗（Stage 2）
- **原因**: IAMロール権限不足またはイメージ取得失敗
- **対策**: 
  ```bash
  # ECSタスク定義確認
  aws ecs describe-task-definition \
    --task-definition poc-ecs-jenkins-jenkins \
    --region ap-northeast-1
  
  # サービス状態確認
  aws ecs describe-services \
    --cluster poc-ecs-jenkins-cluster \
    --services poc-ecs-jenkins-jenkins \
    --region ap-northeast-1
  ```

#### EC2インスタンス起動失敗
- **原因**: Launch Templateまたはセキュリティグループの問題
- **対策**: Auto Scaling Group活動履歴確認
  ```bash
  # Auto Scaling Group活動履歴
  aws autoscaling describe-scaling-activities \
    --auto-scaling-group-name poc-ec2-asg \
    --region ap-northeast-1
  
  # インスタンス起動ログ確認
  aws logs describe-log-streams \
    --log-group-name /aws/ec2/poc-system/hostname \
    --region ap-northeast-1
  ```

#### ALB ヘルスチェック失敗
- **原因**: セキュリティグループでSSH（22番ポート）が許可されていない
- **対策**: 
  ```bash
  # Target Group詳細確認
  aws elbv2 describe-target-groups \
    --target-group-arns $ALB_TG_ARN \
    --region ap-northeast-1
  
  # セキュリティグループ確認
  aws ec2 describe-security-groups \
    --filters "Name=tag:Environment,Values=poc" \
    --region ap-northeast-1
  ```

### 3. ネットワーク問題

#### インターネット接続不可
```bash
# NAT Gateway状態確認
aws ec2 describe-nat-gateways \
  --filter "Name=tag:Environment,Values=poc" \
  --region ap-northeast-1

# ルートテーブル確認
aws ec2 describe-route-tables \
  --filters "Name=tag:Environment,Values=poc" \
  --region ap-northeast-1
```

### 4. Jenkins Docker ビルドパイプライン問題

#### CodeBuild実行失敗
- **原因1**: GitリポジトリのDockerfileが見つからない
- **対策1**: リポジトリルートにDockerfileが存在することを確認
  ```bash
  # ビルドログ確認
  aws logs describe-log-streams \
    --log-group-name /aws/codebuild/poc-jenkins-docker-build \
    --region ap-northeast-1
  
  # 最新ビルドログ確認
  aws logs get-log-events \
    --log-group-name /aws/codebuild/poc-jenkins-docker-build \
    --log-stream-name [LOG_STREAM_NAME] \
    --region ap-northeast-1
  ```

- **原因2**: ECRへのプッシュ権限不足
- **対策2**: CodeBuildサービスロールの権限確認
  ```bash
  # CodeBuildプロジェクトのロール確認
  aws codebuild batch-get-projects \
    --names poc-jenkins-docker-build \
    --query 'projects[0].serviceRole' \
    --region ap-northeast-1
  ```

#### Webhook実行失敗
- **原因**: Lambda関数エラーまたはAPI Gateway設定問題
- **対策**: 
  ```bash
  # Lambda関数ログ確認
  aws logs describe-log-streams \
    --log-group-name /aws/lambda/poc-jenkins-build-trigger \
    --region ap-northeast-1
  
  # Webhook URL確認
  aws cloudformation describe-stacks \
    --stack-name poc-poc-jenkins-build-trigger \
    --query 'Stacks[0].Outputs[?OutputKey==`WebhookURL`].OutputValue' \
    --output text \
    --region ap-northeast-1
  ```

#### ECRイメージプッシュ失敗
- **原因**: リージョン設定またはECR認証問題
- **対策**: 
  ```bash
  # ECRログイン確認
  aws ecr get-login-password --region ap-northeast-1 | \
    docker login --username AWS --password-stdin [ACCOUNT_ID].dkr.ecr.ap-northeast-1.amazonaws.com
  
  # ECRリポジトリポリシー確認
  aws ecr get-repository-policy \
    --repository-name poc-jenkins \
    --region ap-northeast-1
  ```

### 5. EBSスナップショット バックアップ問題

#### スナップショット作成失敗
- **原因1**: Lambda関数のIAM権限不足
- **対策1**: Lambda実行ロールの権限確認
  ```bash
  # Lambda関数の実行ログ確認
  aws logs get-log-events \
    --log-group-name /aws/lambda/poc-ebs-snapshot-backup-snapshot-creator \
    --log-stream-name [最新のログストリーム] \
    --region ap-northeast-1
  
  # IAMロール権限確認
  aws iam get-role-policy \
    --role-name poc-ebs-snapshot-backup-snapshot-lambda-role \
    --policy-name EBSSnapshotPolicy \
    --region ap-northeast-1
  ```

- **原因2**: 対象インスタンスのタグ設定問題
- **対策2**: EC2インスタンスのタグ確認
  ```bash
  # Environment タグの確認
  aws ec2 describe-instances \
    --filters "Name=tag:Environment,Values=poc" \
    --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Environment`].Value|[0]]' \
    --output table \
    --region ap-northeast-1
  ```

#### スナップショット削除失敗（保持期間経過後）
- **原因**: スナップショットが他のリソースで使用中
- **対策**: 手動での確認・削除
  ```bash
  # 保持期間切れスナップショット確認
  aws ec2 describe-snapshots \
    --owner-ids self \
    --filters "Name=tag:Environment,Values=poc" "Name=tag:BackupType,Values=PrePatch" \
    --query 'Snapshots[?Tags[?Key==`DeletionDate`]].{SnapshotId:SnapshotId,DeletionDate:Tags[?Key==`DeletionDate`].Value|[0],State:State}' \
    --output table \
    --region ap-northeast-1
  ```

#### パッチ適用失敗時のロールバック手順
- **手順1**: 失敗したインスタンスの特定
  ```bash
  # パッチ適用状況確認
  aws ssm describe-instance-patch-states \
    --instance-ids [INSTANCE_ID] \
    --region ap-northeast-1
  ```

- **手順2**: 対応するスナップショットの確認
  ```bash
  # インスタンス用のスナップショット取得
  aws lambda invoke \
    --function-name poc-ebs-snapshot-backup-snapshot-restore \
    --payload '{"action":"list_snapshots","instance_id":"[INSTANCE_ID]"}' \
    --region ap-northeast-1 \
    /tmp/instance-snapshots.json
  
  cat /tmp/instance-snapshots.json
  ```

- **手順3**: スナップショットからボリューム作成（手動復旧）
  ```bash
  # 復旧用ボリューム作成
  aws lambda invoke \
    --function-name poc-ebs-snapshot-backup-snapshot-restore \
    --payload '{"action":"create_volume","snapshot_id":"[SNAPSHOT_ID]","availability_zone":"[AZ]"}' \
    --region ap-northeast-1 \
    /tmp/restore-volume.json
  
  cat /tmp/restore-volume.json
  
  # ※ 実際のボリューム入れ替えは手動作業が必要
  # 1. インスタンス停止
  # 2. 既存ボリュームのデタッチ
  # 3. 復旧ボリュームのアタッチ
  # 4. インスタンス起動
  ```

## 🧹 環境削除

### 1. Stage 1 削除
```bash
# Stage 1 リソース削除（推奨順序）
uv run sceptre delete poc/ec2.yaml
uv run sceptre delete poc/alb.yaml
uv run sceptre delete poc/securitygroup.yaml
uv run sceptre delete poc/alb-securitygroup.yaml
uv run sceptre delete poc/iam-group.yaml
uv run sceptre delete poc/vpc.yaml
uv run sceptre delete poc/fixed-natgw-eip.yaml
```

### 2. Stage 2 削除（今後追加時）
```bash
# データ保護のため、Aurora以外を先に削除
uv run sceptre delete poc/ecs-jenkins.yaml
uv run sceptre delete poc/ecs-gitea.yaml

# EBSスナップショット自動バックアップ削除
# 注意：作成済みスナップショットは手動削除が必要
uv run sceptre delete poc/ebs-snapshot-backup.yaml

# 手動でスナップショット削除（必要に応じて）
aws ec2 describe-snapshots \
  --owner-ids self \
  --filters "Name=tag:Environment,Values=poc" "Name=tag:BackupType,Values=PrePatch" \
  --query 'Snapshots[].SnapshotId' \
  --output text \
  --region ap-northeast-1 | xargs -n1 aws ec2 delete-snapshot --snapshot-id

uv run sceptre delete poc/ssm-patch-management.yaml
uv run sceptre delete poc/s3.yaml

# Jenkins Docker ビルドパイプライン削除
uv run sceptre delete poc/jenkins-build-trigger.yaml
uv run sceptre delete poc/codebuild-jenkins.yaml

# ECRリポジトリ削除（注意：Dockerイメージが失われます）
# 事前にイメージを削除してからリポジトリを削除
aws ecr list-images \
  --repository-name poc-jenkins \
  --region ap-northeast-1 \
  --query 'imageIds[*]' \
  --output json > /tmp/poc-jenkins-images.json

aws ecr batch-delete-image \
  --repository-name poc-jenkins \
  --image-ids file:///tmp/poc-jenkins-images.json \
  --region ap-northeast-1

uv run sceptre delete poc/ecr-jenkins.yaml

# データベース削除（注意：データが失われます）
uv run sceptre delete poc/aurora.yaml
```

### 3. 一括削除
```bash
# 全スタック削除（注意：復旧不可）
uv run sceptre delete poc/ --yes
```

### 4. 削除確認
```bash
# スタック状態確認
uv run sceptre status poc/

# CloudFormation削除確認
aws cloudformation list-stacks \
  --stack-status-filter DELETE_COMPLETE \
  --region ap-northeast-1
```

## 📊 コスト見積もり

### Stage 1 月間概算コスト（ap-northeast-1）
- **EC2**: t3.medium × 3台 = $45/月
- **ALB**: 1台 = $15/月
- **NAT Gateway**: 3台 = $135/月
- **EBS**: gp3 20GB × 3台 = $6/月
- **その他**: CloudWatch, SSM等 = $5/月

**Stage 1 合計**: 約 $206/月（約28,000円/月）

### 将来のStage 2追加時の概算コスト
- **Aurora MySQL**: db.t3.medium × 2台 = $85/月
- **ECS Fargate**: 1vCPU, 2GB × 2サービス = $25/月
- **ALB追加**: 1台（Jenkins/Gitea用） = $15/月
- **EFS**: 基本料金 = $3/月
- **S3**: ログ保存等 = $5/月

**Stage 2追加時**: 約 $133/月

**全体合計（Stage 1 + 2）**: 約 $339/月（約46,000円/月）

## 📝 運用メモ

### Stage 1 現在の構成
- **ヘルスチェック**: ALB → EC2 SSH (TCP:22)
- **アクセス方法**: SSM Session Manager
- **ホスト名**: pochub-001（1a）、pochub-002（1c）、pochub-003（1d）
- **監視**: CloudWatch Agent（CPU、メモリ、ディスク）

### 定期メンテナンス
- **パッチ適用**: 毎週日曜日 2:00 AM UTC（自動）
- **ログローテーション**: CloudWatch Logs（14日保持）

### 監視項目（Stage 1）
- EC2インスタンス稼働状況
- ALB Target Group ヘルス状況
- Auto Scaling Group状況
- SSH接続可能性（TCP:22）

### Stage 2 移行時の考慮事項
- **ヘルスチェック進化**: TCP:22 → HTTP:80/8080
- **ALB Target Group**: アプリケーション用に再設定
- **Jenkins Pipeline**: アプリケーションデプロイ自動化

### セキュリティ
- セキュリティグループは最小権限
- SSH接続はSSM Session Managerのみ
- インスタンス配置はプライベートサブネットのみ

---

**作成日**: 2025年10月13日  
**最終更新**: Stage 1 基本インフラ構成対応  
**対象リージョン**: ap-northeast-1  
**Sceptre Version**: 4.x  
**CloudFormation**: AWS::CloudFormation  

## 📚 関連ドキュメント

- [テンプレート構成](./テンプレート構成.md)
- [ベストプラクティス](./ベストプラクティス.md)
- [EC2 Auto Scaling Group設計書](../EC2_AutoScalingGroup.md)
- [Jenkins Docker Build Pipeline](./Jenkins_Docker_Build_Pipeline.md)
