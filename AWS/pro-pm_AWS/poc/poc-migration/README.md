# POC環境 ECS移行パッケージ

このディレクトリには、POC環境で構築したJenkins/Gitea ECS (Fargate)環境を他の環境（dev/stg/prod）へ移行するために必要なファイルが含まれています。

## 📋 OLD_sceptreとの対応関係

このパッケージは、既存のOLD_sceptre構成との互換性を考慮して作成されています：

### ディレクトリ構造の対応

| OLD_sceptre | poc-migration | 説明 |
|-------------|---------------|------|
| `config/config.yaml` | `sceptre/config/config.yaml` | グローバル設定ファイル |
| `config/{env}/config.yaml` | `sceptre/config/{env}/config.yaml` | 環境別設定 |
| `config/{env}/*.yaml` | `sceptre/config/{env}/*.yaml` | スタック設定ファイル |
| `templates/*.yaml` | `sceptre/templates/*.yaml` | CloudFormationテンプレート |

### 設定ファイル形式の違い

**OLD_sceptre形式**:
```yaml
template:
  path: vpc.yaml
  type: file
parameters:
  VPCCIDR: 10.60.0.0/16
  # ...
```

**POC環境（現在）の形式**:
```yaml
template_path: vpc.yaml
dependencies:
  - poc/fixed-natgw-eip.yaml
parameters:
  VpcCidr: 10.0.0.0/16
  # ...
```

このパッケージは**POC環境の形式**を採用しています（実際に動作確認済みのため）。

### テンプレートファイル名の対応

| 機能 | OLD_sceptre | poc-migration | 備考 |
|------|-------------|---------------|------|
| VPC | `vpc.yaml` | `vpc.yaml` | ✅ 同名 |
| セキュリティグループ | `securitygroup.yaml` | `securitygroup.yaml` | ✅ 同名 |
| IAMロール | `iam-group.yaml` | `iam-group.yaml` | ✅ 同名 |
| NAT Gateway EIP | `fixed-natgw-eip.yaml` | `fixed-natgw-eip.yaml` | ✅ 同名 |
| VPCエンドポイント | `ssm-endpoint.yaml` | `vpc-endpoints.yaml` | ⚠️ 名称変更 |
| ECS | `ecs.yaml` | `ecs-jenkins.yaml` / `ecs-gitea.yaml` | ⚠️ 分割 |
| ALB | `elb.yaml` | `alb.yaml` | ⚠️ 名称変更 |
| ECR | なし | `ecr-jenkins.yaml` | ✨ 新規 |

### パラメータ名の主な違い

| パラメータ | OLD_sceptre | POC環境 |
|-----------|-------------|---------|
| VPC CIDR | `VPCCIDR` | `VpcCidr` |
| VPC ID参照 | `VPCID` | `VPCId` |
| サブネットCIDR | `PublicSubnetACIDR` | `PublicSubnet1Cidr` |
| 環境識別 | `EnvShort` + `SystemName` | `Environment` |

### 移行時の主な変更点

1. **Network Firewall**: OLD_sceptreにはあるが、POC環境では未実装
2. **VPC Flow Logs**: OLD_sceptreはS3バケット必須、POC環境はオプション
3. **ECS構成**: OLD_sceptreは単一ECSスタック、POC環境はJenkins/Gitea分離
4. **ALB**: POC環境はInternal ALBのみ（外部アクセスはSSM経由）

## 📁 ディレクトリ構成

```
poc-migration/
├── README.md                          # このファイル
├── ECS移行用パラメータファイル.md      # 詳細なパラメータシートと手順書
├── sceptre/                           # CloudFormation テンプレート（Sceptre形式）
│   ├── config/                        # Sceptre設定ファイル
│   │   └── poc/                       # POC環境の設定例
│   │       ├── vpc.yaml               # VPC設定
│   │       ├── securitygroup.yaml     # セキュリティグループ設定
│   │       ├── iam-group.yaml         # IAMロール設定
│   │       ├── fixed-natgw-eip.yaml   # NAT Gateway EIP設定
│   │       ├── vpc-endpoints.yaml     # VPCエンドポイント設定
│   │       ├── ecr-jenkins.yaml       # JenkinsECRリポジトリ設定
│   │       ├── ecs-jenkins.yaml       # Jenkins ECSサービス設定
│   │       └── ecs-gitea.yaml         # Gitea ECSサービス設定
│   └── templates/                     # CloudFormationテンプレート
│       ├── vpc.yaml                   # VPCテンプレート
│       ├── securitygroup.yaml         # セキュリティグループテンプレート
│       ├── iam-group.yaml             # IAMロールテンプレート
│       ├── fixed-natgw-eip.yaml       # NAT Gateway EIPテンプレート
│       ├── vpc-endpoints.yaml         # VPCエンドポイントテンプレート
│       ├── ecr-jenkins.yaml           # JenkinsECRリポジトリテンプレート
│       ├── ecs-jenkins.yaml           # Jenkins ECSサービステンプレート
│       └── ecs-gitea.yaml             # Gitea ECSサービステンプレート
├── jenkins-docker/                    # Jenkinsカスタムイメージビルド用
│   ├── buildspec.yml                  # CodeBuildビルド定義
│   ├── jenkins.yaml                   # Jenkins Configuration as Code（現在は無効化）
│   └── jenkins/                       # Dockerイメージビルドコンテキスト
│       ├── Dockerfile                 # Jenkinsカスタムイメージ
│       ├── plugins.txt                # Jenkinsプラグインリスト
│       ├── vault-password-aws.sh      # Ansible Vault AWS連携スクリプト
│       └── ansible.cfg                # Ansible設定（イメージ内埋め込み用）
└── scripts/                           # 運用スクリプト
    ├── connect-jenkins.sh             # Jenkins SSMポートフォワーディング
    ├── connect-gitea.sh               # Gitea SSMポートフォワーディング
    ├── connect-ec2.sh                 # EC2 SSM接続
    └── connect-all.sh                 # 一括接続スクリプト
```

## 🚀 クイックスタート

### 前提条件

1. **AWS CLI**: 最新版（Session Managerプラグイン含む）
2. **Sceptre**: Python Sceptreツール
   ```bash
   pip install sceptre
   ```
3. **uv**: Python環境管理ツール（推奨）
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```
4. **Docker**: Jenkinsカスタムイメージビルド用
5. **AWS認証情報**: 適切な権限を持つIAMユーザー

### 基本的なデプロイフロー

```bash
# 1. 環境変数設定
export ENV=dev  # または stg, prod
export AWS_REGION=ap-northeast-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 2. 基盤リソースのデプロイ
cd sceptre
uv run sceptre create ${ENV}/vpc.yaml -y
uv run sceptre create ${ENV}/securitygroup.yaml -y
uv run sceptre create ${ENV}/iam-group.yaml -y

# 3. ECRリポジトリ作成とイメージプッシュ
uv run sceptre create ${ENV}/ecr-jenkins.yaml -y

cd ../jenkins-docker
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

docker build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ENV}-jenkins-custom:latest jenkins/
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ENV}-jenkins-custom:latest

# 4. Secrets Manager設定
aws secretsmanager create-secret \
  --name ansible/vault-password \
  --description "Ansible Vault password for ${ENV} environment" \
  --secret-string "YOUR_VAULT_PASSWORD_HERE" \
  --region ${AWS_REGION}

# 5. ECSサービスデプロイ
cd ../sceptre
uv run sceptre create ${ENV}/ecs-jenkins.yaml -y
uv run sceptre create ${ENV}/ecs-gitea.yaml -y

# 6. アクセス確認
cd ../scripts
./connect-jenkins.sh ${ENV}  # http://localhost:8081
./connect-gitea.sh ${ENV}    # http://localhost:8080
```

## 📖 詳細ドキュメント

このパッケージには以下のドキュメントが含まれています：

1. **ECS移行用パラメータファイル.md**: 詳細なパラメータシートと手順書
   - ネットワーク構成パラメータ
   - IAM/セキュリティパラメータ
   - Jenkins/Gitea ECS パラメータ
   - ロードバランサー構成
   - 外部アクセス設定（SSM Session Manager）
   - デプロイ手順（ステップバイステップ）
   - 検証手順
   - トラブルシューティング

2. **OLD_sceptre統合ガイド.md**: 既存OLD_sceptre環境への統合方法
   - パラメータ名の変換方法
   - テンプレート形式の違いと対応
   - 既存環境への追加デプロイ手順
   - トラブルシューティング

## 🔧 環境別設定のカスタマイズ

### 新しい環境用の設定ファイル作成

```bash
# dev環境用の設定を作成
cd sceptre/config
cp -r poc dev

# dev環境用のパラメータを編集
# - vpc.yaml: VPC CIDR (10.1.0.0/16)
# - ecs-jenkins.yaml: JenkinsImageUri, Environment
# - ecs-gitea.yaml: Environment
```

### 主要なカスタマイズポイント

1. **VPC CIDR**: 環境ごとに異なるCIDRブロックを使用
   - poc: `10.0.0.0/16`
   - dev: `10.1.0.0/16`
   - stg: `10.2.0.0/16`
   - prod: `10.3.0.0/16`

2. **ECSリソース**: 環境に応じたCPU/メモリ設定
   - dev/stg: 2 vCPU / 4 GB
   - prod: 4 vCPU / 8 GB

3. **ECRイメージ**: 環境別のイメージタグ
   - `{account}.dkr.ecr.{region}.amazonaws.com/{env}-jenkins-custom:latest`

## 🔐 セキュリティ設定

### 必須のSecrets Manager設定

```bash
# Ansible Vaultパスワード
aws secretsmanager create-secret \
  --name ansible/vault-password \
  --description "Ansible Vault password" \
  --secret-string "YOUR_VAULT_PASSWORD" \
  --region ap-northeast-1
```

### IAMロールの権限

- **ECSTaskExecutionRole**: ECRイメージプル、CloudWatch Logs、Secrets Manager読み取り
- **ECSTaskRole**: EC2操作、SSM、S3、CloudWatch Logs（Jenkinsが使用）

## 📊 デプロイ後の確認

```bash
# ECSサービス状態確認
aws ecs describe-services \
  --cluster ${ENV}-${ENV}-ecs-jenkins-cluster \
  --services ${ENV}-${ENV}-ecs-jenkins-jenkins \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' \
  --output table

# タスクヘルスチェック
aws ecs list-tasks \
  --cluster ${ENV}-${ENV}-ecs-jenkins-cluster \
  --service-name ${ENV}-${ENV}-ecs-jenkins-jenkins

# ALB DNS取得
aws cloudformation describe-stacks \
  --stack-name ${ENV}-${ENV}-ecs-jenkins \
  --query 'Stacks[0].Outputs[?OutputKey==`JenkinsURL`].OutputValue' \
  --output text
```

## 🔄 更新とメンテナンス

### Jenkinsイメージの更新

```bash
# イメージ再ビルド
cd jenkins-docker
docker build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ENV}-jenkins-custom:latest jenkins/
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ENV}-jenkins-custom:latest

# ECSサービス再デプロイ
aws ecs update-service \
  --cluster ${ENV}-${ENV}-ecs-jenkins-cluster \
  --service ${ENV}-${ENV}-ecs-jenkins-jenkins \
  --force-new-deployment
```

### スタックの更新

```bash
# 設定変更後
cd sceptre
uv run sceptre update ${ENV}/ecs-jenkins.yaml -y
```

## 🗑️ 環境削除

```bash
# 逆順で削除
cd sceptre
uv run sceptre delete ${ENV}/ecs-jenkins.yaml -y
uv run sceptre delete ${ENV}/ecs-gitea.yaml -y
uv run sceptre delete ${ENV}/ecr-jenkins.yaml -y
uv run sceptre delete ${ENV}/iam-group.yaml -y
uv run sceptre delete ${ENV}/securitygroup.yaml -y
uv run sceptre delete ${ENV}/vpc-endpoints.yaml -y
uv run sceptre delete ${ENV}/vpc.yaml -y

# Secrets Manager削除
aws secretsmanager delete-secret \
  --secret-id ansible/vault-password \
  --force-delete-without-recovery
```

## 📞 サポート

問題が発生した場合は、`ECS移行用パラメータファイル.md`のトラブルシューティングセクションを参照してください。

## 📝 ライセンス

このパッケージはPOC環境の構成を再現するためのものです。本番環境で使用する前に、セキュリティレビューを実施してください。
