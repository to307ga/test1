# Immutable環境改善ガイド

## 📚 このドキュメントの目的

本ドキュメントは、現在のPOC環境の問題点を分析し、真のImmutable Infrastructureを実現するための知識と実装方法を提供します。

---

## 🔍 現在の構成の問題点分析

### 問題1: Mutableな運用になっている

**現状の構成：**
```
EC2起動（AMI） → Ansible実行（設定追加）
  ↓
- Laravel アプリケーションデプロイ
- ProxySQL インストール・設定
- CloudWatch Agent インストール
- アプリケーション設定
```

**問題点：**
- インスタンス起動後に状態が変化する（Mutable）
- 同じAMIから起動しても、Ansible実行タイミングで異なる状態になる可能性
- スケールアウト時に設定適用の遅延が発生
- インスタンスごとに微妙に異なる構成になるリスク

**Immutableの原則：**
> インスタンスは起動後に一切変更せず、変更が必要な場合は新しいインスタンスに置き換える

---

### 問題2: 監視設定の分散管理

**現状：**
- CloudFormation（Sceptre）: Alarms, SNS, Dashboard
- Ansible: CloudWatch Agent, Log設定, メトリクス収集

**問題点：**
- インフラの状態が2つのツールに分散
- どちらか一方を実行し忘れるリスク
- 構成の全体像が把握しづらい
- Infrastructure as Code の原則に反する

**理想：**
- すべてのインフラ定義はCloudFormation（Sceptre）に集約
- EC2のUserDataまたはAMIに監視エージェント設定を含める

---

### 問題3: プロジェクト境界の曖昧さ

**現状：**
```
/home/tomo/poc/                    # Sceptre（インフラ）プロジェクト
  └─ sceptre/
      └─ config/poc/monitoring-alerts.yaml  # 監視定義

/home/tomo/ansible-playbooks/     # Ansible（設定）プロジェクト
  └─ setup-comprehensive-monitoring.yml    # 監視エージェント設定
     ↑ group_vars/poc.yml を参照（pocプロジェクトと密結合）
```

**問題点：**
- 独立プロジェクトなのに依存関係が不明確
- どちらがSource of Truthか曖昧
- チーム開発時に混乱の原因になる

**理想：**
- `poc`プロジェクト: すべてのインフラ定義（CloudFormation）
- `ansible-playbooks`: 運用ツール、緊急対応、一時的な作業のみ

---

## 🎓 Immutable Infrastructureの基礎知識

### Immutable vs Mutable

| 観点 | Mutable (従来型) | Immutable (理想) |
|------|------------------|------------------|
| **変更方法** | サーバーに直接ログインして変更 | 新しいAMIを作成して置き換え |
| **設定適用** | Ansible/Chef/Puppet等で設定 | AMI/UserDataに事前設定 |
| **スケール** | 新サーバーに設定を適用（遅い） | AMIから即座に起動（速い） |
| **一貫性** | サーバーごとに微妙に異なる可能性 | すべて同じAMIなので完全に同一 |
| **ロールバック** | 設定を戻す（困難） | 旧AMIで起動（簡単） |
| **トラブル** | 原因調査が複雑 | AMIが問題なので明確 |

### Immutableの実現方法

```
1. ゴールデンイメージ（AMI）作成
   ├─ ベースOS（Amazon Linux 2023）
   ├─ アプリケーション（Laravel）
   ├─ ミドルウェア（Apache, PHP, ProxySQL）
   ├─ 監視エージェント（CloudWatch Agent）
   └─ すべての設定ファイル

2. Auto Scaling Group
   └─ Launch Template
       ├─ AMI: ゴールデンイメージ
       ├─ UserData: 起動時の動的設定のみ
       │   └─ 例: インスタンスID、AZ取得、タグ付け
       └─ Instance Profile: IAM Role

3. デプロイ
   ├─ 新AMI作成
   ├─ Launch Template更新
   └─ Auto Scaling Groupでローリング更新
```

---

## 🚀 AutoScaling Group (ASG) の仕組み

### ASGとは

Auto Scaling Groupは、EC2インスタンスの数を自動的に調整する仕組みです。

**主要コンポーネント：**

```
Auto Scaling Group
├─ Launch Template（起動テンプレート）
│   ├─ AMI ID
│   ├─ Instance Type
│   ├─ Security Group
│   ├─ IAM Instance Profile
│   └─ UserData Script
├─ Desired Capacity（希望台数）: 3台
├─ Min Size（最小）: 3台
├─ Max Size（最大）: 6台
└─ Health Check
    ├─ EC2 Status Check
    └─ ELB Health Check（ALB連携時）
```

### ASGのメリット

1. **自動復旧**
   - インスタンス障害時に自動で新しいインスタンスを起動
   - 常に指定台数を維持

2. **スケーリング**
   - CPU使用率などに応じて自動でスケールアウト/イン
   - コスト最適化

3. **Blue/Greenデプロイメント**
   - 新しいASGを作成 → トラフィック切り替え → 旧ASG削除
   - ダウンタイムゼロ

4. **ローリング更新**
   - Launch Templateを更新
   - 1台ずつ新しいインスタンスに置き換え

### 現在のPOC環境での使い方

**現状（ASGが存在するが活用していない）：**
```bash
# ASG確認
aws autoscaling describe-auto-scaling-groups \
  --query 'AutoScalingGroups[?contains(AutoScalingGroupName,`poc`)].{Name:AutoScalingGroupName,Desired:DesiredCapacity,Min:MinSize,Max:MaxSize}' \
  --region ap-northeast-1
```

**ASGを活用した運用例：**

```bash
# 1. Launch Template更新（新AMI）
aws ec2 create-launch-template-version \
  --launch-template-id lt-xxxxx \
  --source-version 1 \
  --launch-template-data '{"ImageId":"ami-new-golden-image"}'

# 2. ASGで新バージョンを使用
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name poc-asg \
  --launch-template '{"LaunchTemplateId":"lt-xxxxx","Version":"$Latest"}'

# 3. インスタンスリフレッシュ（ローリング更新）
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name poc-asg \
  --preferences '{"MinHealthyPercentage":66,"InstanceWarmup":300}'
```

---

## 🖼️ ゴールデンイメージ（AMI）作成プロセス

### AMIとは

Amazon Machine Image（AMI）は、EC2インスタンスのテンプレートです。
- OS
- アプリケーション
- 設定ファイル
- すべてがスナップショットとして保存される

### ゴールデンイメージ作成フロー

```
┌─────────────────────────────────────────────────────────┐
│ 1. ビルド用EC2インスタンス起動                              │
│    - ベースAMI: Amazon Linux 2023                        │
│    - UserData: 設定スクリプト実行                         │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 2. アプリケーションとミドルウェアのインストール              │
│    - Apache, PHP, ProxySQL                              │
│    - Laravel application                                │
│    - CloudWatch Agent                                   │
│    - 必要な設定ファイル                                    │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 3. 動作確認・テスト                                        │
│    - アプリケーション起動確認                              │
│    - 監視エージェント動作確認                              │
│    - セキュリティスキャン                                  │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 4. AMI作成                                               │
│    - インスタンスからイメージを作成                         │
│    - タグ付け: Version, BuildDate, Application           │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 5. ビルド用インスタンス削除                                │
│    - コスト削減                                           │
└─────────────────────────────────────────────────────────┘
```

### AMI作成の具体的手順

#### 方法1: 手動作成（学習・検証用）

```bash
# 1. 現在のEC2インスタンスからAMI作成
INSTANCE_ID="i-0cb639645f102ca9f"  # pochub-001
AMI_NAME="poc-web-golden-$(date +%Y%m%d-%H%M%S)"

aws ec2 create-image \
  --instance-id $INSTANCE_ID \
  --name $AMI_NAME \
  --description "POC Web Server Golden Image with Laravel + ProxySQL + Monitoring" \
  --tag-specifications "ResourceType=image,Tags=[{Key=Environment,Value=poc},{Key=Application,Value=poc-web},{Key=Version,Value=1.0.0}]" \
  --region ap-northeast-1

# 2. AMI作成状態確認
aws ec2 describe-images \
  --owners self \
  --filters "Name=name,Values=$AMI_NAME" \
  --query 'Images[0].{ID:ImageId,State:State,Name:Name}' \
  --region ap-northeast-1
```

#### 方法2: Packer（自動化・本番用）

**Packerとは：**
HashiCorpが提供するAMI自動作成ツール

**Packerテンプレート例：**
```json
{
  "variables": {
    "aws_region": "ap-northeast-1",
    "app_version": "1.0.0"
  },
  "builders": [{
    "type": "amazon-ebs",
    "region": "{{user `aws_region`}}",
    "source_ami_filter": {
      "filters": {
        "name": "al2023-ami-*-x86_64",
        "root-device-type": "ebs",
        "virtualization-type": "hvm"
      },
      "owners": ["amazon"],
      "most_recent": true
    },
    "instance_type": "t3.medium",
    "ssh_username": "ec2-user",
    "ami_name": "poc-web-{{user `app_version`}}-{{timestamp}}",
    "tags": {
      "Environment": "poc",
      "Application": "poc-web",
      "Version": "{{user `app_version`}}",
      "BuildDate": "{{isotime}}"
    }
  }],
  "provisioners": [
    {
      "type": "ansible",
      "playbook_file": "./packer-ami-build.yml"
    },
    {
      "type": "shell",
      "inline": [
        "sudo systemctl enable apache",
        "sudo systemctl enable proxysql",
        "sudo systemctl enable amazon-cloudwatch-agent"
      ]
    }
  ]
}
```

#### 方法3: EC2 Image Builder（AWS推奨）

**EC2 Image Builderの利点：**
- AWSネイティブサービス
- パイプライン化（自動ビルド・テスト）
- セキュリティスキャン統合
- 脆弱性パッチ自動適用

**CloudFormationでの定義例：**
```yaml
ImageBuilderPipeline:
  Type: AWS::ImageBuilder::ImagePipeline
  Properties:
    Name: poc-web-golden-image-pipeline
    ImageRecipeArn: !Ref ImageRecipe
    InfrastructureConfigurationArn: !Ref InfrastructureConfiguration
    Schedule:
      ScheduleExpression: "cron(0 0 * * SUN)"  # 毎週日曜日
      PipelineExecutionStartCondition: EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE
```

### AMI管理のベストプラクティス

1. **バージョニング**
   ```
   poc-web-1.0.0-20251018-103000
   ├─ アプリケーション名: poc-web
   ├─ セマンティックバージョン: 1.0.0
   └─ ビルド日時: 20251018-103000
   ```

2. **タグ付け**
   ```yaml
   Environment: poc
   Application: poc-web
   Version: 1.0.0
   BuildDate: 2025-10-18T10:30:00Z
   CommitHash: abc123def456  # Git commit
   BuildBy: CI/CD Pipeline
   ```

3. **ライフサイクル管理**
   - 古いAMIの自動削除（90日後など）
   - 最新3世代のみ保持
   - Lambda + EventBridgeで自動化

---

## 🔄 Blue/Greenデプロイメントの実装

### Blue/Greenデプロイメントとは

**概念：**
```
┌─────────────┐          ┌─────────────┐
│   ALB       │          │   ALB       │
│   (100%流量) │          │   (100%流量) │
└──────┬──────┘          └──────┬──────┘
       │                        │
       ↓                        ↓
┌─────────────┐          ┌─────────────┐
│ Blue環境    │   →      │ Green環境   │
│ (現行)      │   切替    │ (新バージョン)│
│ ASG-Blue    │          │ ASG-Green   │
│ AMI v1.0.0  │          │ AMI v1.1.0  │
└─────────────┘          └─────────────┘
     ↓                         ↓
  削除                      本番運用
```

**メリット：**
- ダウンタイムゼロ
- 即座にロールバック可能
- 本番トラフィックでテスト可能

### 実装パターン

#### パターン1: ASG + ALB ターゲットグループ切替

```bash
# 1. Green環境用ASG作成
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name poc-asg-green \
  --launch-template "LaunchTemplateId=lt-xxxxx,Version=2" \
  --min-size 3 --max-size 3 --desired-capacity 3 \
  --target-group-arns arn:aws:elasticloadbalancing:ap-northeast-1:xxx:targetgroup/poc-green/xxx \
  --vpc-zone-identifier "subnet-xxx,subnet-yyy,subnet-zzz" \
  --health-check-type ELB \
  --health-check-grace-period 300

# 2. Green環境ヘルスチェック
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:ap-northeast-1:xxx:targetgroup/poc-green/xxx

# 3. ALBリスナールール変更（トラフィック切替）
aws elbv2 modify-listener \
  --listener-arn arn:aws:elasticloadbalancing:ap-northeast-1:xxx:listener/app/poc-alb/xxx \
  --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:ap-northeast-1:xxx:targetgroup/poc-green/xxx

# 4. Blue環境削除（または保持）
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name poc-asg-blue \
  --min-size 0 --max-size 0 --desired-capacity 0
```

#### パターン2: 重み付けトラフィック分散（カナリアデプロイ）

```bash
# 段階的にトラフィックを移行
# Blue: 90%, Green: 10%
aws elbv2 modify-rule \
  --rule-arn arn:aws:elasticloadbalancing:... \
  --actions Type=forward,ForwardConfig='{
    "TargetGroups":[
      {"TargetGroupArn":"arn:...blue","Weight":90},
      {"TargetGroupArn":"arn:...green","Weight":10}
    ]
  }'

# 問題なければ徐々に増やす
# Blue: 50%, Green: 50%
# Blue: 10%, Green: 90%
# Blue: 0%,  Green: 100%
```

### Blue/Green用CloudFormationテンプレート

```yaml
# sceptre/templates/blue-green-deployment.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: Blue/Green Deployment Infrastructure

Parameters:
  Environment:
    Type: String
    Default: poc
  BlueAMI:
    Type: AWS::EC2::Image::Id
    Description: Current production AMI
  GreenAMI:
    Type: AWS::EC2::Image::Id
    Description: New version AMI

Resources:
  BlueTargetGroup:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Properties:
      Name: !Sub ${Environment}-blue-tg
      VpcId: !ImportValue VPCId
      Port: 80
      Protocol: HTTP
      HealthCheckPath: /health
      Tags:
        - Key: Environment
          Value: blue

  GreenTargetGroup:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Properties:
      Name: !Sub ${Environment}-green-tg
      VpcId: !ImportValue VPCId
      Port: 80
      Protocol: HTTP
      HealthCheckPath: /health
      Tags:
        - Key: Environment
          Value: green

  BlueLaunchTemplate:
    Type: AWS::EC2::LaunchTemplate
    Properties:
      LaunchTemplateName: !Sub ${Environment}-blue-lt
      LaunchTemplateData:
        ImageId: !Ref BlueAMI
        InstanceType: t3.medium
        IamInstanceProfile:
          Arn: !ImportValue EC2InstanceProfileArn
        SecurityGroupIds:
          - !ImportValue EC2SecurityGroupId
        UserData:
          Fn::Base64: !Sub |
            #!/bin/bash
            # Minimal UserData - everything else is in AMI
            INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
            aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Deployment,Value=blue --region ${AWS::Region}

  GreenLaunchTemplate:
    Type: AWS::EC2::LaunchTemplate
    Properties:
      LaunchTemplateName: !Sub ${Environment}-green-lt
      LaunchTemplateData:
        ImageId: !Ref GreenAMI
        InstanceType: t3.medium
        IamInstanceProfile:
          Arn: !ImportValue EC2InstanceProfileArn
        SecurityGroupIds:
          - !ImportValue EC2SecurityGroupId
        UserData:
          Fn::Base64: !Sub |
            #!/bin/bash
            INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
            aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Deployment,Value=green --region ${AWS::Region}

  BlueASG:
    Type: AWS::AutoScaling::AutoScalingGroup
    Properties:
      AutoScalingGroupName: !Sub ${Environment}-blue-asg
      LaunchTemplate:
        LaunchTemplateId: !Ref BlueLaunchTemplate
        Version: !GetAtt BlueLaunchTemplate.LatestVersionNumber
      MinSize: 3
      MaxSize: 3
      DesiredCapacity: 3
      TargetGroupARNs:
        - !Ref BlueTargetGroup
      VPCZoneIdentifier: !Split [',', !ImportValue PrivateSubnetIds]
      HealthCheckType: ELB
      HealthCheckGracePeriod: 300
      Tags:
        - Key: Name
          Value: !Sub ${Environment}-blue
          PropagateAtLaunch: true
        - Key: Environment
          Value: blue
          PropagateAtLaunch: true

  GreenASG:
    Type: AWS::AutoScaling::AutoScalingGroup
    Properties:
      AutoScalingGroupName: !Sub ${Environment}-green-asg
      LaunchTemplate:
        LaunchTemplateId: !Ref GreenLaunchTemplate
        Version: !GetAtt GreenLaunchTemplate.LatestVersionNumber
      MinSize: 0
      MaxSize: 3
      DesiredCapacity: 0
      TargetGroupARNs:
        - !Ref GreenTargetGroup
      VPCZoneIdentifier: !Split [',', !ImportValue PrivateSubnetIds]
      HealthCheckType: ELB
      HealthCheckGracePeriod: 300
      Tags:
        - Key: Name
          Value: !Sub ${Environment}-green
          PropagateAtLaunch: true
        - Key: Environment
          Value: green
          PropagateAtLaunch: true

Outputs:
  BlueTargetGroupArn:
    Value: !Ref BlueTargetGroup
    Export:
      Name: BlueTargetGroupArn
  GreenTargetGroupArn:
    Value: !Ref GreenTargetGroup
    Export:
      Name: GreenTargetGroupArn
```

---

## 📋 具体的な改善ロードマップ

### Phase 1: AMI作成（初回）

**目標：** 現在の構成をAMIとして固める

**手順：**

1. **現在のインスタンスを基にAMI作成**
   ```bash
   cd /home/tomo/poc
   
   # AMI作成スクリプト
   ./scripts/create-golden-ami.sh pochub-001
   ```

2. **AMI検証用インスタンス起動**
   ```bash
   # 新しいAMIから起動してテスト
   aws ec2 run-instances \
     --image-id ami-xxxxx \
     --instance-type t3.medium \
     --subnet-id subnet-xxxxx \
     --security-group-ids sg-xxxxx
   
   # 動作確認
   # - Webアプリケーション
   # - ProxySQL
   # - 監視エージェント
   ```

3. **Launch Template更新**
   ```bash
   # 新AMIでLaunch Template作成
   aws ec2 create-launch-template-version \
     --launch-template-id lt-xxxxx \
     --source-version 1 \
     --launch-template-data '{"ImageId":"ami-new-golden-image"}'
   ```

### Phase 2: UserDataへの移行

**目標：** 動的設定のみUserDataで実行

**変更内容：**

**現在（Ansible）：**
```yaml
- name: Configure instance-specific settings
  tasks:
    - Set hostname
    - Configure network
    - Install applications
    - Configure monitoring
    - Deploy application
```

**改善後（AMI + UserData）：**
```yaml
# AMIに含めるもの（静的設定）
- OS packages
- Applications (Laravel, ProxySQL)
- CloudWatch Agent
- Apache/PHP configuration
- Application code (または S3から取得)

# UserDataで実行するもの（動的設定）
#!/bin/bash
# 1. インスタンス情報取得
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
AZ=$(ec2-metadata --availability-zone | cut -d " " -f 2)
REGION=$(echo $AZ | sed 's/[a-z]$//')

# 2. タグ付け
aws ec2 create-tags --resources $INSTANCE_ID \
  --tags Key=AvailabilityZone,Value=$AZ --region $REGION

# 3. 環境変数設定（必要最小限）
echo "INSTANCE_ID=$INSTANCE_ID" >> /opt/app/laravel/.env
echo "AWS_REGION=$REGION" >> /opt/app/laravel/.env

# 4. サービス起動（AMIでenabledにしておく）
systemctl start apache
systemctl start proxysql
systemctl start amazon-cloudwatch-agent
```

### Phase 3: Blue/Green環境構築

**目標：** ダウンタイムゼロデプロイメント

**手順：**

1. **Blue/Green用テンプレート作成**
   ```bash
   # Sceptreで管理
   cd /home/tomo/poc/sceptre
   
   # 新規テンプレート作成
   templates/blue-green-deployment.yaml
   config/poc/blue-green-deployment.yaml
   ```

2. **Green環境デプロイ**
   ```bash
   cd /home/tomo/poc/sceptre
   
   # Green環境構築（新AMI使用）
   uv run sceptre create poc/blue-green-deployment.yaml --yes
   ```

3. **トラフィック切替スクリプト**
   ```bash
   #!/bin/bash
   # scripts/switch-to-green.sh
   
   BLUE_TG="arn:aws:elasticloadbalancing:...:targetgroup/poc-blue/xxx"
   GREEN_TG="arn:aws:elasticloadbalancing:...:targetgroup/poc-green/xxx"
   LISTENER_ARN="arn:aws:elasticloadbalancing:...:listener/app/poc-alb/xxx"
   
   echo "Switching traffic to Green environment..."
   
   # 10% → Green
   modify_traffic 90 10
   sleep 300  # 5分待機
   
   # 50% → Green
   modify_traffic 50 50
   sleep 300
   
   # 100% → Green
   modify_traffic 0 100
   
   echo "Traffic switch completed!"
   ```

### Phase 4: CI/CDパイプライン構築

**目標：** 完全自動化

```
GitHub Push
    ↓
CodeBuild (Build & Test)
    ↓
Packer / EC2 Image Builder
    ↓
AMI作成
    ↓
Lambda (自動デプロイ)
    ├─ Green環境起動
    ├─ ヘルスチェック
    ├─ トラフィック切替
    └─ Blue環境削除
```

---

## 🔍 検証手順への追加項目

### 検証1: AMIからの起動テスト

**目的：** ゴールデンイメージが正しく機能するか確認

**手順：**
```bash
# 1. AMIから新規インスタンス起動
aws ec2 run-instances --image-id ami-golden-image ...

# 2. UserData実行完了待機
aws ec2 wait instance-status-ok --instance-ids i-xxxxx

# 3. 動作確認
# - Webアプリケーションアクセス
# - ProxySQL接続確認
# - CloudWatch メトリクス送信確認
# - ログ出力確認

# 4. インスタンス削除（テスト完了）
aws ec2 terminate-instances --instance-ids i-xxxxx
```

**期待結果：**
- 起動から5分以内にすべてのサービスが稼働
- Ansible実行不要
- 完全に同一の構成

### 検証2: Auto Scaling動作テスト

**目的：** ASGによる自動復旧を確認

**手順：**
```bash
# 1. 現在のインスタンス数確認
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names poc-asg

# 2. 1台を強制終了
INSTANCE_ID=$(aws ec2 describe-instances ... | jq -r '.Reservations[0].Instances[0].InstanceId')
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# 3. 自動復旧監視（5分以内）
watch -n 10 'aws autoscaling describe-auto-scaling-groups ...'

# 4. 新インスタンスの動作確認
```

**期待結果：**
- 5分以内に新しいインスタンスが起動
- ALBのヘルスチェックパス
- 台数が元の3台に戻る

### 検証3: Blue/Green切替テスト

**目的：** ダウンタイムゼロでデプロイできるか確認

**手順：**
```bash
# 1. Blue環境で継続的アクセス（別ターミナル）
while true; do
  curl -s http://poc-alb-xxxxx.ap-northeast-1.elb.amazonaws.com/health
  sleep 1
done

# 2. Green環境起動
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name poc-asg-green \
  --desired-capacity 3

# 3. Green環境ヘルスチェック待機
# 4. トラフィック切替
# 5. Blue環境削除

# 6. アクセスログ確認
# → エラーなく継続できているか
```

**期待結果：**
- リクエスト失敗ゼロ
- レスポンスタイムの大きな変動なし
- ユーザー体験に影響なし

### 検証4: ロールバックテスト

**目的：** 問題発生時に即座に戻せるか確認

**手順：**
```bash
# 1. Green環境で問題発見（想定）
# 2. トラフィックをBlueに戻す
aws elbv2 modify-listener \
  --listener-arn arn:... \
  --default-actions Type=forward,TargetGroupArn=arn:...blue

# 3. 復旧時間計測
# 4. Green環境削除
```

**期待結果：**
- 1分以内にロールバック完了
- データ損失なし
- ユーザー影響最小化

---

## 📊 改善前後の比較

### デプロイ時間

| 項目 | 現在（Mutable） | 改善後（Immutable） |
|------|----------------|-------------------|
| 新規インスタンス起動 | 5分 | 5分 |
| Ansible設定適用 | 15-20分 | 不要 |
| アプリケーションデプロイ | 10分 | 不要（AMIに含む） |
| **合計** | **30-35分** | **5分** |
| ロールバック | 30-35分 | 1分 |

### 運用コスト

| 項目 | 現在 | 改善後 |
|------|------|--------|
| デプロイ作業 | 手動30分 | 自動5分 |
| トラブル調査 | 2-4時間 | 30分 |
| スケールアウト | 35分/台 | 5分/台 |
| 構成のドリフト | 発生する | 発生しない |

### 信頼性

| 項目 | 現在 | 改善後 |
|------|------|--------|
| 設定ミス | 起こりうる | ほぼゼロ |
| インスタンス間の差異 | 発生する | ゼロ |
| テスト環境との差異 | 発生する | ゼロ |
| ロールバック成功率 | 70% | 99.9% |

---

## 🎯 学習リソース

### 推奨書籍

1. **Infrastructure as Code（IaC）**
   - 『Infrastructure as Code』Kief Morris著
   - 『Terraform: Up & Running』Yevgeniy Brikman著

2. **Immutable Infrastructure**
   - 『Site Reliability Engineering』Google著
   - 『The DevOps Handbook』Gene Kim他著

3. **AWS**
   - AWS Well-Architected Framework
   - AWS Immutable Infrastructure Best Practices

### AWS公式ドキュメント

- [EC2 Image Builder](https://docs.aws.amazon.com/imagebuilder/)
- [Auto Scaling Groups](https://docs.aws.amazon.com/autoscaling/)
- [Blue/Green Deployments on AWS](https://docs.aws.amazon.com/whitepapers/latest/blue-green-deployments/)

### ハンズオン

1. AWS Workshops
   - [Immutable Infrastructure Workshop](https://immutableinfra.awsworkshop.io/)
   - [Blue/Green Deployment Workshop](https://catalog.workshops.aws/)

2. 自習用演習
   - Packerで簡単なAMI作成
   - ASGのスケーリングポリシー設定
   - Lambda + EventBridgeで自動化

---

## 📝 まとめ

### 現在の状態（POC完了時）

✅ **達成したこと：**
- 基本的なインフラ構築（VPC, EC2, Aurora, ALB）
- アプリケーションデプロイ（Laravel + ProxySQL）
- 監視・アラート設定（CloudWatch）
- 動作検証完了

⚠️ **改善が必要な点：**
- Mutableな運用（Ansible後設定）
- ASG未活用
- ゴールデンイメージ未作成
- Blue/Green未実装

### 次のステップ（本番環境構築時）

1. **Phase 1**: AMI作成（1-2日）
2. **Phase 2**: UserData移行（1日）
3. **Phase 3**: Blue/Green構築（2-3日）
4. **Phase 4**: CI/CD構築（3-5日）

**合計：** 7-11営業日で理想的なImmutable環境が完成

### 学んだこと

1. **Immutable Infrastructureの価値**
   - デプロイ時間短縮
   - 運用コスト削減
   - 信頼性向上

2. **ASGの重要性**
   - 自動復旧
   - スケーリング
   - Blue/Greenの基盤

3. **ゴールデンイメージ**
   - 一貫性の保証
   - 高速起動
   - 簡単なロールバック

---

**このドキュメントは、現在のPOC環境を理想的なImmutable環境に進化させるためのロードマップです。**

次回のプロジェクトや本番環境構築時に、このガイドを参照して段階的に実装していくことをお勧めします。

