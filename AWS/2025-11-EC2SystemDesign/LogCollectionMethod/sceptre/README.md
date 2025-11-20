# CloudWatch Logs Agent IAMリソース - Sceptreデプロイメント

## 概要

このディレクトリには、EC2インスタンス上でCloudWatch Logs Agentに必要なIAMリソースを作成するためのSceptre設定とCloudFormationテンプレートが含まれています。

## ディレクトリ構成

```
sceptre/
├── config/
│   └── poc/
│       ├── config.yaml                        # Sceptreプロジェクト設定
│       ├── cloudwatch-agent-iam-policy.yaml   # CloudWatch Agent IAMポリシー用スタック設定
│       └── cloudwatch-agent-iam-role.yaml     # CloudWatch Agent IAMロール用スタック設定
├── templates/
│   ├── cloudwatch-agent-iam-policy.yaml       # CloudWatch Agent IAMポリシー用CloudFormationテンプレート
│   └── cloudwatch-agent-iam-role.yaml         # CloudWatch Agent IAMロール用CloudFormationテンプレート
└── README.md                                   # このファイル
```

## 作成されるリソース

### 1. IAMポリシー (`poc-cloudwatch-agent-policy`)

含まれる権限:
- **CloudWatch Logs**:
  - `logs:CreateLogGroup`
  - `logs:CreateLogStream`
  - `logs:PutLogEvents`
  - `logs:DescribeLogStreams`
  - `logs:DescribeLogGroups`
  
- **SSM Parameter Store**:
  - `ssm:GetParameter`
  - `ssm:GetParameters`
  - `ssm:PutParameter`
  
- **EC2メタデータ**:
  - `ec2:DescribeTags`
  - `ec2:DescribeInstances`
  - `ec2:DescribeVolumes`

### 2. IAMロール (`poc-ec2-cloudwatch-agent-role`)

アタッチされるポリシー:
- カスタムポリシー: `poc-cloudwatch-agent-policy` (上記で作成)
- AWS管理ポリシー: `CloudWatchAgentServerPolicy`
- AWS管理ポリシー: `AmazonSSMManagedInstanceCore` (Session Manager用)

### 3. インスタンスプロファイル (`poc-ec2-cloudwatch-agent-profile`)

- EC2インスタンスへのアタッチ用にIAMロールをラップ

**インスタンスプロファイルとは:**

インスタンスプロファイルは、EC2インスタンスにIAMロールを関連付けるためのコンテナです。

```
IAMロール → インスタンスプロファイル → EC2インスタンス
```

**なぜ必要なのか:**
- EC2インスタンスは直接IAMロールをアタッチできません
- インスタンスプロファイルが「IAMロール」と「EC2インスタンス」の橋渡しをします
- EC2インスタンス内のアプリケーションは、インスタンスプロファイル経由でIAMロールの権限を使用できます

**動作の流れ:**
1. EC2インスタンスにインスタンスプロファイルをアタッチ
2. インスタンスプロファイルがIAMロールを参照
3. EC2上のアプリケーション（CloudWatch Agent等）がメタデータサービス経由で一時認証情報を取得
4. その認証情報でAWS API（CloudWatch Logs等）を呼び出し

**メタデータサービス経由の認証情報取得例:**
```bash
# EC2インスタンス内から実行
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/poc-ec2-cloudwatch-agent-role

# 出力例:
# {
#   "AccessKeyId": "ASIA...",
#   "SecretAccessKey": "...",
#   "Token": "...",
#   "Expiration": "2025-11-18T18:00:00Z"
# }
```

## デプロイ手順

### ステップ1: テンプレートの検証

```bash
# sceptreディレクトリへ移動
cd draft/2025-11-EC2SystemDesign/LogCollectionMethod/sceptre

# すべてのテンプレートを検証
uv run sceptre validate poc/cloudwatch-agent-iam-policy.yaml
uv run sceptre validate poc/cloudwatch-agent-iam-role.yaml
```

### ステップ2: CloudFormationテンプレートの生成（オプション）

```bash
# 最終的なCloudFormationテンプレートを生成して確認
uv run sceptre generate poc/cloudwatch-agent-iam-policy.yaml
uv run sceptre generate poc/cloudwatch-agent-iam-role.yaml
```

### ステップ3: IAMポリシーのデプロイ（最初に実行）

```bash
# IAMポリシースタックをデプロイ
uv run sceptre launch --yes poc/cloudwatch-agent-iam-policy.yaml

# スタック状態を確認
uv run sceptre status poc/cloudwatch-agent-iam-policy.yaml
```

### ステップ4: IAMロールのデプロイ（ポリシーの後に実行）

```bash
# IAMロールスタックをデプロイ（IAMポリシーに依存）
uv run sceptre launch --yes poc/cloudwatch-agent-iam-role.yaml

# スタック状態を確認
uv run sceptre status poc/cloudwatch-agent-iam-role.yaml
```

### ステップ5: デプロイの確認

```bash
# poc環境のすべてのスタックを一覧表示
uv run sceptre list poc

# IAMロールスタックの出力を取得
uv run sceptre describe poc/cloudwatch-agent-iam-role.yaml

# AWSコンソールで確認
aws iam get-role --role-name poc-ec2-cloudwatch-agent-role
aws iam get-instance-profile --instance-profile-name poc-ec2-cloudwatch-agent-profile
```

## デプロイ出力

デプロイ成功後、以下の出力が得られます:

```yaml
Outputs:
  PolicyArn: arn:aws:iam::123456789012:policy/poc-cloudwatch-agent-policy
  RoleArn: arn:aws:iam::123456789012:role/poc-ec2-cloudwatch-agent-role
  RoleName: poc-ec2-cloudwatch-agent-role
  InstanceProfileArn: arn:aws:iam::123456789012:instance-profile/poc-ec2-cloudwatch-agent-profile
  InstanceProfileName: poc-ec2-cloudwatch-agent-profile
```

## EC2インスタンスへのアタッチ

### 重要: インスタンスプロファイルの制約

**EC2インスタンスには1つのインスタンスプロファイルのみアタッチ可能です。**

```
✅ 可能: 1つのIAMロールに複数のポリシーをアタッチ
❌ 不可: 1つのEC2インスタンスに複数のインスタンスプロファイルをアタッチ
```

### 既存インスタンスプロファイルが存在する場合の対応

既にEC2インスタンスにインスタンスプロファイルがアタッチされている場合、以下の2つの選択肢があります：

#### 選択肢1: 既存IAMロールにポリシーを追加（推奨）

既存のIAMロールを維持しながら、CloudWatch Logs Agent用のポリシーを追加します。

**手順:**

1. **既存インスタンスプロファイルとIAMロールの確認**

```bash
# インスタンスにアタッチされているインスタンスプロファイルを確認
aws ec2 describe-instances \
  --instance-ids i-0134c94a753025b8b i-0297dec34ad7ea77b i-0f464ba83118e3114 \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,IamInstanceProfile.Arn,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# 出力例:
# +---------------------+----------+-------------------------------------------------------------------------------+--------------+
# |  i-0297dec34ad7ea77b|  running |  arn:aws:iam::910230630316:instance-profile/poc-poc-ec2-ec2-instance-profile |  pochub-002  |
# |  i-0f464ba83118e3114|  running |  arn:aws:iam::910230630316:instance-profile/poc-poc-ec2-ec2-instance-profile |  pochub-003  |
# |  i-0134c94a753025b8b|  running |  arn:aws:iam::910230630316:instance-profile/poc-poc-ec2-ec2-instance-profile |  pochub-001  |
# +---------------------+----------+-------------------------------------------------------------------------------+--------------+

# インスタンスプロファイルに含まれるIAMロールを確認
aws iam get-instance-profile \
  --instance-profile-name poc-poc-ec2-ec2-instance-profile \
  --query 'InstanceProfile.Roles[*].[RoleName,Arn]' \
  --output table

# 出力例:
# +-----------------------+-------------------------------------------------------+
# |  poc-poc-ec2-ec2-role |  arn:aws:iam::910230630316:role/poc-poc-ec2-ec2-role |
# +-----------------------+-------------------------------------------------------+
```

2. **既存IAMロールの権限を確認**

```bash
# アタッチされているマネージドポリシーを確認
aws iam list-attached-role-policies --role-name poc-poc-ec2-ec2-role --output table

# 出力例:
# +-------------------------------------------------------+--------------------------------+
# |                       PolicyArn                       |          PolicyName            |
# +-------------------------------------------------------+--------------------------------+
# |  arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy  |  CloudWatchAgentServerPolicy   |
# |  arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore |  AmazonSSMManagedInstanceCore  |
# |  arn:aws:iam::aws:policy/AmazonSSMPatchAssociation    |  AmazonSSMPatchAssociation     |
# +-------------------------------------------------------+--------------------------------+

# インラインポリシーを確認
aws iam list-role-policies --role-name poc-poc-ec2-ec2-role --output table

# 出力例:
# +------------------------+
# |       PolicyNames      |
# +------------------------+
# |  EC2SelfTaggingPolicy  |
# +------------------------+

# インラインポリシーの内容確認
aws iam get-role-policy \
  --role-name poc-poc-ec2-ec2-role \
  --policy-name EC2SelfTaggingPolicy \
  --query 'PolicyDocument' \
  --output json
```

3. **CloudWatch Agent用カスタムポリシーを既存IAMロールにアタッチ**

```bash
# カスタムポリシーをアタッチ
aws iam attach-role-policy \
  --role-name poc-poc-ec2-ec2-role \
  --policy-arn arn:aws:iam::910230630316:policy/poc-cloudwatch-agent-policy

# アタッチ確認
aws iam list-attached-role-policies --role-name poc-poc-ec2-ec2-role --output table

# 出力例（poc-cloudwatch-agent-policyが追加されている）:
# +--------------------------------------------------------------+--------------------------------+
# |                          PolicyArn                           |          PolicyName            |
# +--------------------------------------------------------------+--------------------------------+
# |  arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy         |  CloudWatchAgentServerPolicy   |
# |  arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore        |  AmazonSSMManagedInstanceCore  |
# |  arn:aws:iam::aws:policy/AmazonSSMPatchAssociation           |  AmazonSSMPatchAssociation     |
# |  arn:aws:iam::910230630316:policy/poc-cloudwatch-agent-policy|  poc-cloudwatch-agent-policy   |
# +--------------------------------------------------------------+--------------------------------+
```

4. **権限の有効化確認（EC2インスタンス内から）**

```bash
# EC2インスタンスにSSH/Session Managerで接続後、以下を実行
# メタデータサービスから一時認証情報を取得できることを確認
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/poc-poc-ec2-ec2-role

# CloudWatch Logs APIにアクセスできることを確認
aws logs describe-log-groups --log-group-name-prefix /aws/ec2/ --region ap-northeast-1
```

**実施結果（本番環境での実例）:**
```yaml
対象インスタンス:
  - i-0134c94a753025b8b (pochub-001)
  - i-0297dec34ad7ea77b (pochub-002)
  - i-0f464ba83118e3114 (pochub-003)

既存インスタンスプロファイル: poc-poc-ec2-ec2-instance-profile
既存IAMロール: poc-poc-ec2-ec2-role

既存の権限:
  - CloudWatchAgentServerPolicy (AWS管理)
  - AmazonSSMManagedInstanceCore (AWS管理)
  - AmazonSSMPatchAssociation (AWS管理)
  - EC2SelfTaggingPolicy (インライン)

追加した権限:
  - poc-cloudwatch-agent-policy (カスタム)
    - CloudWatch Logs詳細権限
    - SSM Parameter Store権限
    - EC2メタデータ権限

対応理由:
  EC2インスタンスには1つのインスタンスプロファイルのみアタッチ可能なため、
  新規インスタンスプロファイルへの置き換えではなく、
  既存IAMロールへのポリシー追加で対応しました。
```

#### 選択肢2: インスタンスプロファイルの置き換え（非推奨）

既存のインスタンスプロファイルを削除して、新しいものに置き換えます。

**注意:** この方法は既存の権限が失われる可能性があるため、選択肢1を推奨します。

```bash
# 1. 既存の関連付けIDを取得
aws ec2 describe-iam-instance-profile-associations \
  --filters "Name=instance-id,Values=i-xxxxxxxxx" \
  --query 'IamInstanceProfileAssociations[0].AssociationId' \
  --output text

# 2. 既存のインスタンスプロファイルを解除
aws ec2 disassociate-iam-instance-profile \
  --association-id iip-assoc-xxxxxxxxx

# 3. 新しいインスタンスプロファイルをアタッチ
aws ec2 associate-iam-instance-profile \
  --instance-id i-xxxxxxxxx \
  --iam-instance-profile Name=poc-ec2-cloudwatch-agent-profile
```

### 事前確認: EC2インスタンス一覧の取得

```bash
# すべてのEC2インスタンスを一覧表示
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# 実行中のインスタンスのみ表示
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# 出力例:
# ----------------------------------------------------------------------------
# |                          DescribeInstances                               |
# +---------------------+------------+--------------+-------------------------+
# |  i-1234567890abcdef0|  running   |  t3.2xlarge  |  10.0.1.10  | web-prod-1|
# |  i-0987654321fedcba0|  running   |  t3.2xlarge  |  10.0.2.20  | web-prod-2|
# +---------------------+------------+--------------+-------------------------+

# インスタンスプロファイルのアタッチ状態確認
aws ec2 describe-instances \
  --instance-ids i-1234567890abcdef0 \
  --query 'Reservations[0].Instances[0].IamInstanceProfile' \
  --output json

# 出力例（アタッチ済み）:
# {
#     "Arn": "arn:aws:iam::910230630316:instance-profile/poc-ec2-cloudwatch-agent-profile",
#     "Id": "AIPXXXXXXXXXXXXXXXXXX"
# }

# 出力例（未アタッチ）:
# null
```

### 方法1: EC2起動時にアタッチ

```bash
aws ec2 run-instances \
  --image-id ami-xxxxxxxxx \
  --instance-type t3.micro \
  --iam-instance-profile Name=poc-ec2-cloudwatch-agent-profile \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cloudwatch-agent-test}]'
```

### 方法2: 既存インスタンスにアタッチ

```bash
# 関連付けを作成
aws ec2 associate-iam-instance-profile \
  --instance-id i-1234567890abcdef0 \
  --iam-instance-profile Name=poc-ec2-cloudwatch-agent-profile

# アタッチを確認
aws ec2 describe-iam-instance-profile-associations
```

### 方法3: CloudFormation EC2インスタンス定義

```yaml
Resources:
  MyEC2Instance:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: ami-xxxxxxxxx
      InstanceType: t3.micro
      IamInstanceProfile: !ImportValue poc-ec2-cloudwatch-agent-profile-name
      Tags:
        - Key: Name
          Value: cloudwatch-agent-test
```

## 既存スタックの更新

```bash
# IAMポリシーを更新
uv run sceptre launch --yes poc/cloudwatch-agent-iam-policy.yaml

# IAMロールを更新（ポリシーが変更された場合）
uv run sceptre launch --yes poc/cloudwatch-agent-iam-role.yaml
```

## スタックの削除

```bash
# 逆順で削除（ロールを先に、次にポリシー）
uv run sceptre delete --yes poc/cloudwatch-agent-iam-role.yaml
uv run sceptre delete --yes poc/cloudwatch-agent-iam-policy.yaml

# またはpoc環境のすべてのスタックを削除
uv run sceptre delete --yes poc
```

## トラブルシューティング

### エラー: "ManagedPolicyArn not found"

```bash
# IAMポリシースタックが先にデプロイされていることを確認
uv run sceptre status poc/cloudwatch-agent-iam-policy.yaml

# CloudFormationのエクスポートを確認
aws cloudformation list-exports --query "Exports[?Name=='poc-cloudwatch-agent-policy-arn']"
```

### エラー: "Role already exists"

```bash
# 既存のロールを手動削除
aws iam delete-role --role-name poc-ec2-cloudwatch-agent-role

# またはSceptreで管理
uv run sceptre delete --yes poc/cloudwatch-agent-iam-role.yaml
uv run sceptre launch --yes poc/cloudwatch-agent-iam-role.yaml
```

### エラー: "Cannot delete policy - still attached"

```bash
# すべてのロールからデタッチ
aws iam list-entities-for-policy --policy-arn arn:aws:iam::123456789012:policy/poc-cloudwatch-agent-policy

# 次にロールスタックを削除
uv run sceptre delete --yes poc/cloudwatch-agent-iam-role.yaml

# 最後にポリシースタックを削除
uv run sceptre delete --yes poc/cloudwatch-agent-iam-policy.yaml
```

## コスト見積もり

IAMリソース（ロール、ポリシー、インスタンスプロファイル）はAWSで**無料**です。

CloudWatch Logsのデータ取り込みとストレージのみがコストとして発生します:
- ログ取り込み: $0.50/GB
- ログストレージ: $0.03/GB/月

## セキュリティに関する考慮事項

### 最小権限の原則

IAMポリシーは最小権限の原則に従っています:
- CloudWatch Logs: `/aws/ec2/*` ログループのみに制限
- SSMパラメータ: エージェント設定パラメータのみに制限
- EC2メタデータ: 読み取り専用アクセス

### リソースベースの制限

```yaml
Resource:
  - !Sub arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/ec2/*
  - !Sub arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/AmazonCloudWatch-*
```

### 推奨される追加制限（オプション）

タグベースでさらに制限する場合:

```yaml
Condition:
  StringEquals:
    aws:PrincipalTag/Project: poc
```

## 次のステップ

IAMリソースのデプロイ後:

1. **EC2インスタンスにCloudWatch Agentをインストール**
   ```bash
   sudo yum install -y amazon-cloudwatch-agent
   ```

2. **`config.json`でAgentを設定**
   - 詳細な設定方法は `LogCollectionMethod.md` を参照

3. **Agentを起動**
   ```bash
   sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
     -a fetch-config \
     -m ec2 \
     -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json \
     -s
   ```

4. **CloudWatchコンソールでログを確認**
   - CloudWatch Logsに移動
   - `/aws/ec2/` 配下のログループを確認

## 参考資料

- [CloudWatch Logs Agent公式ドキュメント](https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html)
- [EC2のIAMロール](https://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)
- [Sceptreドキュメント](https://docs.sceptre-project.org/)
- [CloudFormation IAMリファレンス](https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/aws-resource-iam-role.html)

## 改版履歴

| 版数 | 日付 | 改版内容 | 作成者 |
|------|------|----------|--------|
| 1.0 | 2025-11-18 | 初版作成 | - |
