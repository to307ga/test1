# ECS (Fargate) 環境移行用パラメータシート

## 📋 目次
1. [概要](#概要)
2. [前提条件](#前提条件)
3. [ネットワーク構成パラメータ](#ネットワーク構成パラメータ)
4. [IAM/セキュリティパラメータ](#iamセキュリティパラメータ)
5. [Jenkins ECS パラメータ](#jenkins-ecs-パラメータ)
6. [Gitea ECS パラメータ](#gitea-ecs-パラメータ)
7. [ロードバランサー構成](#ロードバランサー構成)
8. [外部アクセス設定](#外部アクセス設定)
9. [デプロイ手順](#デプロイ手順)
10. [検証手順](#検証手順)

---

## 概要

このドキュメントは、POC環境で構築したJenkinsとGiteaのECS (Fargate)環境を、他の環境（dev/stg/prod等）へ移行する際に必要なパラメータをまとめたものです。

### アーキテクチャの特徴
- **ECS Fargate**: サーバーレスコンテナ実行環境
- **Internal ALB**: VPC内部からのみアクセス可能
- **EFS**: Jenkins/Giteaの永続データ保存
- **Secrets Manager**: 認証情報の安全な管理
- **SSM Session Manager**: ローカル環境からのポートフォワーディング
- **Ansible連携**: JenkinsからEC2への自動化操作

---

## 前提条件

### 必須リソース
以下のCloudFormationスタックが事前にデプロイされている必要があります：

| スタック名パターン | テンプレート | 説明 |
|---|---|---|
| `{env}-{env}-vpc` | `vpc.yaml` | VPC、サブネット、NAT Gateway |
| `{env}-{env}-securitygroup` | `securitygroup.yaml` | セキュリティグループ |
| `{env}-{env}-iam-group` | `iam-group.yaml` | IAMロール（ECSタスク実行/アプリケーション） |
| `{env}-{env}-ecr-jenkins` | `ecr-jenkins.yaml` | JenkinsカスタムイメージECRリポジトリ |

### 環境識別子
- **poc**: POC環境（検証用）
- **dev**: 開発環境
- **stg**: ステージング環境
- **prod**: 本番環境

---

## ネットワーク構成パラメータ

### 1. VPC設定 (`vpc.yaml`)

| パラメータ名 | 説明 | POC環境値 | 他環境での設定例 |
|---|---|---|---|
| `VpcCidr` | VPC CIDRブロック | `10.0.0.0/16` | `10.1.0.0/16` (dev)<br>`10.2.0.0/16` (stg)<br>`10.3.0.0/16` (prod) |
| `PublicSubnet1Cidr` | パブリックサブネット1 (AZ-1a) | `10.0.1.0/24` | `10.{X}.1.0/24` |
| `PublicSubnet2Cidr` | パブリックサブネット2 (AZ-1c) | `10.0.2.0/24` | `10.{X}.2.0/24` |
| `PublicSubnet3Cidr` | パブリックサブネット3 (AZ-1d) | `10.0.3.0/24` | `10.{X}.3.0/24` |
| `PrivateSubnet1Cidr` | プライベートサブネット1 (AZ-1a) | `10.0.11.0/24` | `10.{X}.11.0/24` |
| `PrivateSubnet2Cidr` | プライベートサブネット2 (AZ-1c) | `10.0.12.0/24` | `10.{X}.12.0/24` |
| `PrivateSubnet3Cidr` | プライベートサブネット3 (AZ-1d) | `10.0.13.0/24` | `10.{X}.13.0/24` |
| `EnableVpcEndpoints` | VPCエンドポイント有効化 | `true` | `true`（推奨） |
| `Environment` | 環境識別子 | `poc` | `dev` / `stg` / `prod` |

**VPC Outputs（他スタックへの入力として使用）**:
- `VpcId`: VPCのID
- `PrivateSubnets`: プライベートサブネットのカンマ区切りリスト
- `PublicSubnets`: パブリックサブネットのカンマ区切りリスト

**重要**: ECS Fargateタスクは**プライベートサブネット**に配置され、NAT Gateway経由でインターネットアクセスします。

---

### 2. セキュリティグループ設定 (`securitygroup.yaml`)

| パラメータ名 | 説明 | POC環境値 | 設定ポイント |
|---|---|---|---|
| `VPCId` | VPC ID | `!stack_output vpc.yaml::VpcId` | VPCスタックから自動取得 |
| `VPCCidr` | VPC CIDR（内部通信許可用） | `10.0.0.0/16` | VPCスタックから自動取得 |

**作成されるセキュリティグループ**:

#### Jenkins Security Group
- **名前**: `{env}-{env}-securitygroup-JenkinsSecurityGroup-*`
- **インバウンド**:
  - ポート8080/TCP: `0.0.0.0/0`（ALB経由アクセス用）
  - ALL: VPC CIDR（VPC内部通信）
- **アウトバウンド**:
  - ALL: `0.0.0.0/0`（インターネットアクセス、パッケージダウンロード等）

#### Gitea Security Group
- **名前**: `{env}-{env}-securitygroup-GiteaSecurityGroup-*`
- **インバウンド**:
  - ポート3000/TCP: `0.0.0.0/0`（ALB経由アクセス用）
  - ポート22/TCP: VPC CIDR（Git SSHアクセス）
  - ALL: VPC CIDR（VPC内部通信）
- **アウトバウンド**:
  - ALL: `0.0.0.0/0`

#### EC2 Security Group
- **用途**: JenkinsからAnsible経由でアクセスするEC2インスタンス用
- **インバウンド**:
  - ポート80/TCP: `0.0.0.0/0`（Webアクセス）
  - ポート443/TCP: `0.0.0.0/0`（HTTPS）
  - ALL: VPC CIDR（内部通信）
- **アウトバウンド**:
  - ALL: `0.0.0.0/0`

**Security Group Outputs**:
- `JenkinsSecurityGroupId`: JenkinsセキュリティグループID
- `GiteaSecurityGroupId`: GiteaセキュリティグループID
- `EC2SecurityGroupId`: EC2セキュリティグループID

---

## IAM/セキュリティパラメータ

### 3. IAMロール設定 (`iam-group.yaml`)

JenkinsからAnsible経由でAWS操作を行うため、適切な権限を持つIAMロールが必要です。

| リソース名 | 説明 | 必要な権限 |
|---|---|---|
| `ECSTaskExecutionRole` | ECSタスク実行ロール | - ECRイメージプル<br>- CloudWatch Logsへの書き込み<br>- Secrets Manager読み取り |
| `ECSTaskRole` | アプリケーションロール（Jenkins/Gitea） | - EC2操作（describe, start, stop等）<br>- SSM Session Manager<br>- Secrets Manager読み取り<br>- S3アクセス（ログ、アーティファクト）<br>- CloudWatch Logs書き込み |

#### ECSTaskRole の主要な権限（Jenkinsで必要）

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeTags",
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ssm:SendCommand",
        "ssm:GetCommandInvocation",
        "ssm:DescribeInstanceInformation",
        "ssm:StartSession"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:ap-northeast-1:*:secret:ansible/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::jenkins-artifacts-*",
        "arn:aws:s3:::jenkins-artifacts-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:ap-northeast-1:*:log-group:/ecs/*"
    }
  ]
}
```

**IAM Outputs**:
- `ECSTaskExecutionRoleArn`: タスク実行ロールARN
- `ECSTaskRoleArn`: アプリケーションロールARN

**重要**: 
- JenkinsからAnsibleでEC2を操作する場合、`ECSTaskRole`に必要な権限を付与する
- Ansible Vaultパスワードは**Secrets Manager**に保存（`ansible/vault-password`）
- 環境ごとにSecrets Managerのシークレットを作成する必要がある

---

## Jenkins ECS パラメータ

### 4. Jenkins ECRリポジトリ (`ecr-jenkins.yaml`)

| パラメータ名 | 説明 | POC環境値 | 他環境での設定 |
|---|---|---|---|
| `RepositoryName` | ECRリポジトリ名 | `poc-jenkins-custom` | `{env}-jenkins-custom` |
| `ImageTagMutability` | タグ変更可否 | `MUTABLE` | 同じ（推奨） |
| `ScanOnPush` | プッシュ時スキャン | `true` | 同じ（推奨） |

**ECR Outputs**:
- `RepositoryUri`: ECRリポジトリURI
- `RepositoryArn`: ECRリポジトリARN

**カスタムイメージのビルド**:
```bash
# CodeBuildプロジェクトを使用してビルド
aws codebuild start-build --project-name {env}-jenkins-docker-build

# またはローカルでビルド
cd jenkins-docker
docker build -t {account-id}.dkr.ecr.ap-northeast-1.amazonaws.com/{env}-jenkins-custom:latest .
docker push {account-id}.dkr.ecr.ap-northeast-1.amazonaws.com/{env}-jenkins-custom:latest
```

---

### 5. Jenkins ECS サービス (`ecs-jenkins.yaml`)

| パラメータ名 | 説明 | POC環境値 | 他環境での推奨値 |
|---|---|---|---|
| **ネットワーク** | | | |
| `VPCId` | VPC ID | `!stack_output vpc.yaml::VpcId` | 同じ（自動） |
| `PrivateSubnets` | プライベートサブネットリスト | `!stack_output vpc.yaml::PrivateSubnets` | 同じ（自動） |
| `SecurityGroupId` | Jenkinsセキュリティグループ | `!stack_output securitygroup.yaml::JenkinsSecurityGroupId` | 同じ（自動） |
| **コンピューティング** | | | |
| `TaskCpu` | CPUユニット | `2048` (2 vCPU) | `2048` (dev/stg)<br>`4096` (prod) |
| `TaskMemory` | メモリ (MB) | `4096` (4 GB) | `4096` (dev/stg)<br>`8192` (prod) |
| `DesiredCount` | タスク数 | `1` | `1` (マスターは1台のみ) |
| **アプリケーション** | | | |
| `JenkinsImageUri` | Jenkinsイメージ | `910230630316.dkr.ecr.ap-northeast-1.amazonaws.com/poc-jenkins-custom:latest` | `{account}.dkr.ecr.ap-northeast-1.amazonaws.com/{env}-jenkins-custom:latest` |
| `Environment` | 環境識別子 | `poc` | `dev` / `stg` / `prod` |

**Jenkins コンテナ環境変数**:
- `TZ`: `Asia/Tokyo`
- `JENKINS_OPTS`: `--httpPort=8080`
- `JAVA_OPTS`: 
  - `-Xmx2g`: Java最大ヒープサイズ（prod環境では`-Xmx4g`を推奨）
  - `-Djenkins.install.runSetupWizard=false`: セットアップウィザード無効化
  - `-Dhudson.model.DirectoryBrowserSupport.CSP="..."`: Content Security Policy（Playwright対応）
  - `-Dhudson.security.csrf.DefaultCrumbIssuer.EXCLUDE_SESSION_ID=true`: CSRF保護（ALB対応）

**EFS設定**:
- パフォーマンスモード: `generalPurpose`
- スループットモード: `provisioned` (10 MiB/s)
- 暗号化: 有効
- マウントポイント: `/var/jenkins_home`

**ヘルスチェック**:
- パス: `/login`
- 間隔: 30秒
- タイムアウト: 10秒
- 正常閾値: 2回
- 異常閾値: 5回
- 起動猶予期間: 600秒

**Jenkins Outputs**:
- `JenkinsURL`: Jenkins WebインターフェースURL（ALB DNS経由）
- `LoadBalancerDNS`: ALB DNSエンドポイント
- `ClusterName`: ECSクラスター名
- `ServiceName`: ECSサービス名
- `EFSFileSystemId`: EFSファイルシステムID

---

## Gitea ECS パラメータ

### 6. Gitea ECS サービス (`ecs-gitea.yaml`)

| パラメータ名 | 説明 | POC環境値 | 他環境での推奨値 |
|---|---|---|---|
| **ネットワーク** | | | |
| `VPCId` | VPC ID | `!stack_output vpc.yaml::VpcId` | 同じ（自動） |
| `PrivateSubnets` | プライベートサブネットリスト | `!stack_output vpc.yaml::PrivateSubnets` | 同じ（自動） |
| `SecurityGroupId` | Giteaセキュリティグループ | `!stack_output securitygroup.yaml::GiteaSecurityGroupId` | 同じ（自動） |
| **コンピューティング** | | | |
| `TaskCpu` | CPUユニット | `1024` (1 vCPU) | `1024` (dev/stg)<br>`2048` (prod) |
| `TaskMemory` | メモリ (MB) | `2048` (2 GB) | `2048` (dev/stg)<br>`4096` (prod) |
| `DesiredCount` | タスク数 | `1` | `1` |
| **アプリケーション** | | | |
| `GiteaImageUri` | Giteaイメージ | `gitea/gitea:latest` | `gitea/gitea:1.21.1`（固定バージョン推奨） |
| `Environment` | 環境識別子 | `poc` | `dev` / `stg` / `prod` |
| **データベース** | | | |
| `DatabaseEndpoint` | DB接続先 | `localhost` (SQLite使用) | Aurora使用時は実際のエンドポイント |
| `DatabaseSecretArn` | DB認証情報 | ダミー値 | Aurora使用時は実際のARN |
| `DatabaseName` | データベース名 | `gitea` | `gitea` |
| `DatabaseUser` | DBユーザー名 | `gitea` | `gitea` |

**Gitea コンテナ環境変数**:
- `TZ`: `Asia/Tokyo`
- `GITEA__database__DB_TYPE`: `sqlite3` (またはAurora使用時は`mysql`)
- `GITEA__server__DOMAIN`: ALB DNS名
- `GITEA__server__ROOT_URL`: `http://{alb-dns}:8080/`
- `GITEA__server__HTTP_PORT`: `3000`
- `GITEA__server__SSH_PORT`: `22`

**EFS設定**:
- パフォーマンスモード: `generalPurpose`
- スループットモード: `bursting`
- 暗号化: 有効
- マウントポイント: `/data`

**ヘルスチェック**:
- パス: `/`
- 間隔: 30秒
- タイムアウト: 10秒
- 正常閾値: 2回
- 異常閾値: 5回
- 起動猶予期間: 300秒

**Gitea Outputs**:
- `GiteaURL`: Gitea WebインターフェースURL（ALB DNS経由）
- `LoadBalancerDNS`: ALB DNSエンドポイント
- `ClusterName`: ECSクラスター名
- `ServiceName`: ECSサービス名
- `EFSFileSystemId`: EFSファイルシステムID

---

## ロードバランサー構成

### 7. Application Load Balancer (ALB)

**特徴**: Internal（VPC内部からのみアクセス可能）

#### Jenkins ALB
| 設定項目 | 値 | 説明 |
|---|---|---|
| スキーム | `internal` | VPC内部のみ |
| リスナーポート | `8081` | Jenkins Webインターフェース |
| ターゲットポート | `8080` | Jenkinsコンテナポート |
| プロトコル | `HTTP` | HTTPS化する場合はACM証明書が必要 |
| サブネット | プライベートサブネット × 3 AZ | 高可用性 |
| ヘルスチェックパス | `/login` | Jenkinsログインページ |
| ヘルスチェック成功コード | `200,403` | 認証なしでも正常とみなす |

**ALB DNS例**: 
```
internal-poc-poc-ecs-jenkins-alb-1435548930.ap-northeast-1.elb.amazonaws.com:8081
```

#### Gitea ALB
| 設定項目 | 値 | 説明 |
|---|---|---|
| スキーム | `internal` | VPC内部のみ |
| リスナーポート | `8080` | Gitea Webインターフェース |
| ターゲットポート | `3000` | Giteaコンテナポート |
| プロトコル | `HTTP` | HTTPS化する場合はACM証明書が必要 |
| サブネット | プライベートサブネット × 3 AZ | 高可用性 |
| ヘルスチェックパス | `/` | Giteaトップページ |
| ヘルスチェック成功コード | `200` | 正常応答 |

**ALB DNS例**: 
```
internal-poc-poc-ecs-gitea-alb-1435548930.ap-northeast-1.elb.amazonaws.com:8080
```

#### HTTPS化（オプション）

HTTPS化する場合の追加要件：
1. **ACM証明書**: Route53またはサードパーティで発行
2. **リスナー変更**: HTTPSリスナー（ポート443）追加
3. **セキュリティグループ**: 443ポート許可
4. **リダイレクト**: HTTP→HTTPSリダイレクトルール

```yaml
# ALBリスナー設定例（HTTPS化）
Listener:
  Type: AWS::ElasticLoadBalancingV2::Listener
  Properties:
    LoadBalancerArn: !Ref LoadBalancer
    Port: 443
    Protocol: HTTPS
    Certificates:
      - CertificateArn: !Ref ACMCertificateArn
    DefaultActions:
      - Type: forward
        TargetGroupArn: !Ref TargetGroup
```

---

## 外部アクセス設定

### 8. SSM Session Manager ポートフォワーディング

Internal ALBはVPC内部からのみアクセス可能なため、ローカル環境からアクセスするにはSSM Session Managerのポートフォワーディング機能を使用します。

#### 前提条件
1. **AWS CLI**: 最新版（Session Managerプラグイン含む）
2. **Session Managerプラグイン**: インストール済み
   ```bash
   # インストール確認
   session-manager-plugin --version
   ```
3. **IAMロール**: EC2インスタンスにSSM用IAMロール付与（既存EC2経由でアクセスする場合）
4. **MFA認証**: AWS CLI認証情報（MFA必須の場合）

#### アクセス方法

##### パターン1: 踏み台EC2インスタンス経由

VPC内に踏み台EC2インスタンスがある場合、そのインスタンス経由でポートフォワーディング：

```bash
# Jenkins アクセス
aws ssm start-session \
  --target i-xxxxxxxxxxxxxxxxx \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{
    "host":["internal-{env}-{env}-ecs-jenkins-alb-xxxxx.ap-northeast-1.elb.amazonaws.com"],
    "portNumber":["8081"],
    "localPortNumber":["8081"]
  }'

# ブラウザでアクセス
# http://localhost:8081
```

```bash
# Gitea アクセス
aws ssm start-session \
  --target i-xxxxxxxxxxxxxxxxx \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{
    "host":["internal-{env}-{env}-ecs-gitea-alb-xxxxx.ap-northeast-1.elb.amazonaws.com"],
    "portNumber":["8080"],
    "localPortNumber":["8080"]
  }'

# ブラウザでアクセス
# http://localhost:8080
```

##### パターン2: ECS Exec経由（Fargate直接接続）

ECS Execが有効な場合、Fargateタスクに直接接続：

```bash
# タスクID取得
TASK_ARN=$(aws ecs list-tasks \
  --cluster {env}-{env}-ecs-jenkins-cluster \
  --service-name {env}-{env}-ecs-jenkins-jenkins \
  --query 'taskArns[0]' \
  --output text)

# ECS Exec接続
aws ecs execute-command \
  --cluster {env}-{env}-ecs-jenkins-cluster \
  --task $TASK_ARN \
  --container jenkins \
  --interactive \
  --command "/bin/bash"
```

##### 接続スクリプト（簡易化）

`scripts/connect-jenkins.sh`:
```bash
#!/bin/bash
# Jenkins接続スクリプト

set -e

ENV=${1:-poc}
BASTION_INSTANCE_ID="i-xxxxxxxxxxxxxxxxx"  # 踏み台EC2インスタンスID
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${ENV}-ecs-jenkins \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
  --output text)

echo "Connecting to Jenkins..."
echo "ALB: ${ALB_DNS}:8081"
echo "Local: http://localhost:8081"
echo ""

aws ssm start-session \
  --target ${BASTION_INSTANCE_ID} \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{
    \"host\":[\"${ALB_DNS}\"],
    \"portNumber\":[\"8081\"],
    \"localPortNumber\":[\"8081\"]
  }"
```

`scripts/connect-gitea.sh`:
```bash
#!/bin/bash
# Gitea接続スクリプト

set -e

ENV=${1:-poc}
BASTION_INSTANCE_ID="i-xxxxxxxxxxxxxxxxx"  # 踏み台EC2インスタンスID
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${ENV}-ecs-gitea \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
  --output text)

echo "Connecting to Gitea..."
echo "ALB: ${ALB_DNS}:8080"
echo "Local: http://localhost:8080"
echo ""

aws ssm start-session \
  --target ${BASTION_INSTANCE_ID} \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{
    \"host\":[\"${ALB_DNS}\"],
    \"portNumber\":[\"8080\"],
    \"localPortNumber\":[\"8080\"]
  }"
```

#### 使用方法
```bash
# POC環境に接続
./scripts/connect-jenkins.sh poc
./scripts/connect-gitea.sh poc

# 他環境に接続
./scripts/connect-jenkins.sh dev
./scripts/connect-gitea.sh stg
```

---

## デプロイ手順

### 9. 環境構築手順

#### ステップ1: 事前準備

```bash
# 1. AWS認証設定（MFA必須の場合）
source aws_mfa_credentials

# 2. 環境変数設定
export ENV=dev  # または stg, prod
export AWS_REGION=ap-northeast-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 3. Sceptre設定確認
cd AWS_POC/poc/sceptre
```

#### ステップ2: 基盤リソースのデプロイ

```bash
# VPC作成
uv run sceptre create ${ENV}/vpc.yaml -y

# セキュリティグループ作成
uv run sceptre create ${ENV}/securitygroup.yaml -y

# IAMロール作成
uv run sceptre create ${ENV}/iam-group.yaml -y

# VPCエンドポイント作成（オプション）
uv run sceptre create ${ENV}/vpc-endpoints.yaml -y
```

#### ステップ3: ECRリポジトリ作成とイメージプッシュ

```bash
# ECRリポジトリ作成
uv run sceptre create ${ENV}/ecr-jenkins.yaml -y

# Jenkinsカスタムイメージビルド
cd ../jenkins-docker

# ECRログイン
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# イメージビルド＆プッシュ
docker build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ENV}-jenkins-custom:latest .
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ENV}-jenkins-custom:latest

cd ../sceptre
```

#### ステップ4: Secrets Manager設定

```bash
# Ansible Vaultパスワード作成
aws secretsmanager create-secret \
  --name ansible/vault-password \
  --description "Ansible Vault password for ${ENV} environment" \
  --secret-string "YOUR_VAULT_PASSWORD_HERE" \
  --region ${AWS_REGION}

# JCasC有効化する場合の追加設定（オプション）
# Jenkins管理者パスワードはECSスタック作成時に自動生成されるため不要
```

#### ステップ5: ECSサービスデプロイ

```bash
# Jenkins ECSサービス作成
uv run sceptre create ${ENV}/ecs-jenkins.yaml -y

# デプロイ完了待機（約5-10分）
aws cloudformation wait stack-create-complete \
  --stack-name ${ENV}-${ENV}-ecs-jenkins

# Jenkins URL取得
JENKINS_URL=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${ENV}-ecs-jenkins \
  --query 'Stacks[0].Outputs[?OutputKey==`JenkinsURL`].OutputValue' \
  --output text)
echo "Jenkins URL: ${JENKINS_URL}"

# Gitea ECSサービス作成
uv run sceptre create ${ENV}/ecs-gitea.yaml -y

# デプロイ完了待機
aws cloudformation wait stack-create-complete \
  --stack-name ${ENV}-${ENV}-ecs-gitea

# Gitea URL取得
GITEA_URL=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${ENV}-ecs-gitea \
  --query 'Stacks[0].Outputs[?OutputKey==`GiteaURL`].OutputValue' \
  --output text)
echo "Gitea URL: ${GITEA_URL}"
```

#### ステップ6: ポートフォワーディング設定

```bash
# 踏み台EC2インスタンスID取得（既存の場合）
BASTION_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*bastion*" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

# 接続スクリプトに設定
echo "BASTION_INSTANCE_ID=${BASTION_ID}" > .env

# Jenkins接続
./scripts/connect-jenkins.sh ${ENV}

# 別ターミナルでGitea接続
./scripts/connect-gitea.sh ${ENV}
```

---

## 検証手順

### 10. デプロイ後の確認

#### 10.1 ECSサービス状態確認

```bash
# Jenkinsサービス確認
aws ecs describe-services \
  --cluster ${ENV}-${ENV}-ecs-jenkins-cluster \
  --services ${ENV}-${ENV}-ecs-jenkins-jenkins \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Tasks:deployments[0].taskDefinition}' \
  --output table

# Giteaサービス確認
aws ecs describe-services \
  --cluster ${ENV}-${ENV}-ecs-gitea-cluster \
  --services ${ENV}-${ENV}-ecs-gitea-gitea \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Tasks:deployments[0].taskDefinition}' \
  --output table
```

**期待される結果**:
- Status: `ACTIVE`
- Running: `1`
- Desired: `1`

#### 10.2 タスクヘルスチェック

```bash
# Jenkinsタスク詳細
aws ecs describe-tasks \
  --cluster ${ENV}-${ENV}-ecs-jenkins-cluster \
  --tasks $(aws ecs list-tasks \
    --cluster ${ENV}-${ENV}-ecs-jenkins-cluster \
    --service-name ${ENV}-${ENV}-ecs-jenkins-jenkins \
    --query 'taskArns[0]' --output text) \
  --query 'tasks[0].{LastStatus:lastStatus,HealthStatus:healthStatus,Connectivity:connectivity}' \
  --output table
```

**期待される結果**:
- LastStatus: `RUNNING`
- HealthStatus: `HEALTHY`
- Connectivity: `CONNECTED`

#### 10.3 ALBヘルスチェック

```bash
# Jenkinsターゲットグループ確認
JENKINS_TG_ARN=$(aws cloudformation describe-stacks \
  --stack-name ${ENV}-${ENV}-ecs-jenkins \
  --query 'Stacks[0].Outputs[?OutputKey==`TargetGroupArn`].OutputValue' \
  --output text 2>/dev/null || \
  aws elbv2 describe-target-groups \
    --names ${ENV}-${ENV}-ecs-jenkins-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

aws elbv2 describe-target-health \
  --target-group-arn ${JENKINS_TG_ARN} \
  --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State}' \
  --output table
```

**期待される結果**:
- State: `healthy`

#### 10.4 Webアクセス確認

```bash
# ポートフォワーディング起動後
# Jenkins: http://localhost:8081
# Gitea: http://localhost:8080

# curlで確認
curl -I http://localhost:8081/login
# HTTP/1.1 200 OK

curl -I http://localhost:8080
# HTTP/1.1 200 OK
```

#### 10.5 Jenkins-Ansible連携確認

```bash
# 1. Jenkinsにログイン（管理者認証情報はSecrets Managerから取得）
# 2. test-ansibleジョブを実行
# 3. Ansible Vaultパスワード取得を確認
# 4. EC2インスタンスへのSSM接続を確認
# 5. Playbookタスク実行を確認

# コンソールで確認すべきログ：
# - AWS Secrets Manager からのvaultパスワード取得成功
# - Ansible dynamic inventory 実行成功
# - SSM Session Manager 接続確立
# - Playbookタスク実行完了
```

#### 10.6 ログ確認

```bash
# Jenkinsログ確認
aws logs tail /ecs/${ENV}-${ENV}-ecs-jenkins/jenkins --follow

# Giteaログ確認
aws logs tail /ecs/${ENV}-${ENV}-ecs-gitea/gitea --follow
```

---

## 補足情報

### 11. トラブルシューティング

#### タスク起動失敗

**症状**: タスクが`PENDING`から進まない、または`STOPPED`になる

**確認項目**:
1. ECSタスク実行ロールの権限（ECRプル、Secrets Manager読み取り）
2. ECRイメージの存在確認
3. サブネットのNAT Gateway設定
4. セキュリティグループのアウトバウンドルール
5. EFSマウント失敗（EFSセキュリティグループ）

```bash
# タスク停止理由確認
aws ecs describe-tasks \
  --cluster ${ENV}-${ENV}-ecs-jenkins-cluster \
  --tasks $(aws ecs list-tasks \
    --cluster ${ENV}-${ENV}-ecs-jenkins-cluster \
    --service-name ${ENV}-${ENV}-ecs-jenkins-jenkins \
    --desired-status STOPPED \
    --query 'taskArns[0]' --output text) \
  --query 'tasks[0].{StoppedReason:stoppedReason,Containers:containers[*].[name,reason]}' \
  --output json
```

#### ポートフォワーディング接続失敗

**症状**: `aws ssm start-session`でエラー

**確認項目**:
1. Session Managerプラグインのインストール
2. 踏み台EC2インスタンスのIAMロール（SSM管理ポリシー）
3. 踏み台EC2のSSMエージェント起動状態
4. ALB DNSの名前解決

```bash
# SSMエージェント状態確認
aws ssm describe-instance-information \
  --instance-information-filter-list key=InstanceIds,valueSet=${BASTION_ID} \
  --query 'InstanceInformationList[*].{InstanceId:InstanceId,PingStatus:PingStatus,LastPingDateTime:LastPingDateTime}' \
  --output table
```

#### Ansible Vault認証失敗

**症状**: Jenkinsから`ansible-playbook`実行時に`Decryption failed`エラー

**確認項目**:
1. Secrets Managerにシークレット存在確認
2. ECSタスクロールのSecrets Manager読み取り権限
3. `vault-password-aws.sh`スクリプトの環境変数設定（`AWS_VAULT_SECRET_NAME`）
4. Vaultパスワードの一致確認

```bash
# Secrets Manager確認
aws secretsmanager get-secret-value \
  --secret-id ansible/vault-password \
  --query SecretString \
  --output text
```

---

### 12. 環境削除手順

```bash
# 逆順で削除

# ECSサービス削除
uv run sceptre delete ${ENV}/ecs-jenkins.yaml -y
uv run sceptre delete ${ENV}/ecs-gitea.yaml -y

# ECRイメージ削除（必要に応じて）
aws ecr batch-delete-image \
  --repository-name ${ENV}-jenkins-custom \
  --image-ids imageTag=latest

# ECRリポジトリ削除
uv run sceptre delete ${ENV}/ecr-jenkins.yaml -y

# IAM削除
uv run sceptre delete ${ENV}/iam-group.yaml -y

# セキュリティグループ削除
uv run sceptre delete ${ENV}/securitygroup.yaml -y

# VPCエンドポイント削除
uv run sceptre delete ${ENV}/vpc-endpoints.yaml -y

# VPC削除（最後）
uv run sceptre delete ${ENV}/vpc.yaml -y

# Secrets Manager削除
aws secretsmanager delete-secret \
  --secret-id ansible/vault-password \
  --force-delete-without-recovery
```

---

## まとめ

このパラメータシートには、POC環境のJenkins/Gitea ECS環境を他環境へ移行するために必要な以下の情報が含まれています：

✅ **ネットワーク構成**: VPC、サブネット、セキュリティグループ  
✅ **IAMロール**: ECSタスク実行/アプリケーションロール、Ansible権限  
✅ **ECSサービス**: Jenkins/Giteaのコンピューティングリソース設定  
✅ **ロードバランサー**: Internal ALB構成、ヘルスチェック  
✅ **外部アクセス**: SSM Session Managerポートフォワーディング  
✅ **デプロイ手順**: 順序付きデプロイステップ  
✅ **検証手順**: デプロイ後の確認項目  
✅ **トラブルシューティング**: よくある問題と解決方法

このドキュメントを基に、dev/stg/prod環境への展開を実施できます。
