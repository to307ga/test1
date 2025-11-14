# Blue-Green Immutable Deployment Guide

## 概要

このガイドでは、Blue-Greenデプロイメント方式を使用したImmutableインフラストラクチャーの構築と運用方法について説明します。

## アーキテクチャ概要

### Blue-Green デプロイメント構成

```
Internet Gateway
       |
   CloudFront (Optional)
       |
Application Load Balancer
   /              \
Blue Env          Green Env
(Current)         (New)
   |                |
Target Group      Target Group
   |                |
Auto Scaling      Auto Scaling
Group             Group
```

## 主要コンポーネント

### 1. インフラストラクチャー
- **VPC**: プライベートサブネットによる隔離されたネットワーク
- **ALB**: Blue/Green環境間のトラフィック制御
- **Target Groups**: 各環境専用のターゲットグループ
- **Auto Scaling Groups**: 各色環境の独立したスケーリング

### 2. デプロイメントパイプライン
- **Packer**: Golden AMI作成（OS + ミドルウェア）
- **Ansible**: ミドルウェア設定とアプリケーションデプロイ
- **Jenkins**: CI/CDオーケストレーション
- **CloudFormation/Sceptre**: インフラストラクチャー管理

### 3. セキュリティ
- **SSM Session Manager**: SSH不要のセキュアアクセス
- **IAM Roles**: 最小権限によるアクセス制御
- **Security Groups**: ネットワークレベルセキュリティ

## デプロイメント手順

### Phase 1: 初期環境構築

#### 1. VPCとネットワーク構築
```bash
cd /home/tomo/poc/sceptre

# VPC構築
uv run sceptre create poc/vpc.yaml --yes

# セキュリティグループ作成
uv run sceptre create poc/securitygroup.yaml --yes
uv run sceptre create poc/alb-securitygroup.yaml --yes
```

#### 2. Blue-Green ALB構築
```bash
# Blue-Green対応ALB作成
uv run sceptre create poc/alb-blue-green.yaml --yes
```

#### 3. Golden AMI作成
```bash
cd /home/tomo/poc

# Ansible playbooks更新（シンボリックリンク経由）
git -C ansible-playbooks pull origin main

# Golden AMI作成
cd packer
packer build \
    -var 'environment=poc' \
    -var 'project_code=poc' \
    -var 'ami_version=20241201-001' \
    golden-ami.pkr.hcl
```

#### 4. Blue環境構築
```bash
cd /home/tomo/poc/sceptre

# Blue環境構築
uv run sceptre create poc/ec2-blue.yaml --yes
```

### Phase 2: Blue-Green デプロイメント実行

#### 1. Jenkins パイプライン実行

**パラメータ設定例:**
- Environment: `poc`
- Deployment Type: `full`
- Traffic Strategy: `gradual`
- Skip Tests: `false`
- Dry Run: `false`

#### 2. デプロイメント段階

1. **AMI Build**: 新しいGolden AMI作成
2. **Infrastructure Deployment**: Green環境構築
3. **Application Deployment**: アプリケーションデプロイ
4. **Health Check & Validation**: ヘルスチェックと検証
5. **Traffic Switch**: 段階的トラフィック移行
6. **Post-Switch Validation**: 移行後検証
7. **Cleanup**: 旧環境クリーンアップ

### Phase 3: トラフィック切り替え戦略

#### Gradual (段階的切り替え)
- 10% → 25% → 50% → 75% → 100%
- 各段階で3分間の検証時間
- 自動ロールバック機能

#### Immediate (即座切り替え)
- 0% → 100% の即座切り替え
- 高速デプロイメント用途

#### Canary (カナリア切り替え)
- 小割合でのテスト実行
- 手動承認後にフル切り替え
- 本番環境推奨

## 運用管理

### 手動トラフィック制御

#### Pythonスクリプト使用
```bash
cd /home/tomo/poc

# Greenに段階的移行
python3 scripts/blue_green_traffic_manager.py \
    --environment poc \
    --application poc-web \
    --action shift \
    --target green \
    --percentage 10 \
    --validation-minutes 5

# 緊急ロールバック
python3 scripts/blue_green_traffic_manager.py \
    --environment poc \
    --application poc-web \
    --action rollback
```

#### AWS CLI直接操作
```bash
# 現在のトラフィック分散状況確認
aws elbv2 describe-listeners \
    --load-balancer-arn $(aws elbv2 describe-load-balancers \
        --names poc-poc-web-alb \
        --query 'LoadBalancers[0].LoadBalancerArn' --output text) \
    --query 'Listeners[0].DefaultActions[0].ForwardConfig.TargetGroups'

# 即座にBlueに100%切り替え（緊急時）
LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn $(aws elbv2 describe-load-balancers \
        --names poc-poc-web-alb \
        --query 'LoadBalancers[0].LoadBalancerArn' --output text) \
    --query 'Listeners[0].ListenerArn' --output text)

BLUE_TG_ARN=$(aws elbv2 describe-target-groups \
    --names poc-poc-web-blue-tg \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

GREEN_TG_ARN=$(aws elbv2 describe-target-groups \
    --names poc-poc-web-green-tg \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

aws elbv2 modify-listener \
    --listener-arn $LISTENER_ARN \
    --default-actions Type=forward,ForwardConfig="{
        TargetGroups=[
            {TargetGroupArn=$BLUE_TG_ARN,Weight=100},
            {TargetGroupArn=$GREEN_TG_ARN,Weight=0}
        ]
    }"
```

### モニタリング

#### CloudWatchメトリクス
- **TargetResponseTime**: レスポンス時間監視
- **HTTPCode_Target_5XX_Count**: エラー率監視
- **HealthyHostCount**: ヘルシーインスタンス数
- **UnHealthyHostCount**: 異常インスタンス数

#### アラーム設定例
```bash
# レスポンス時間アラーム
aws cloudwatch put-metric-alarm \
    --alarm-name "poc-alb-response-time" \
    --alarm-description "ALB response time alarm" \
    --metric-name TargetResponseTime \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 300 \
    --evaluation-periods 2 \
    --threshold 5.0 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=LoadBalancer,Value=app/poc-poc-web-alb/1234567890
```

## トラブルシューティング

### 一般的な問題と解決方法

#### 1. デプロイメント失敗
```bash
# ログ確認
aws logs describe-log-groups --log-group-name-prefix /aws/alb/poc-poc-web

# SSM経由でインスタンス接続
aws ssm start-session --target i-1234567890123456
```

#### 2. ヘルスチェック失敗
```bash
# ターゲットグループヘルス確認
aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:targetgroup/poc-poc-web-green-tg/1234567890123456

# アプリケーションログ確認（SSM経由）
aws ssm send-command \
    --instance-ids i-1234567890123456 \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["tail -f /var/log/httpd/error_log"]'
```

#### 3. トラフィック切り替え問題
```bash
# 現在のリスナー設定確認
aws elbv2 describe-listeners \
    --load-balancer-arn arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:loadbalancer/app/poc-poc-web-alb/1234567890123456

# 緊急ロールバック実行
python3 scripts/blue_green_traffic_manager.py \
    --environment poc \
    --application poc-web \
    --action rollback
```

## ベストプラクティス

### 1. デプロイメント前
- [ ] Ansible playbooksの更新とテスト
- [ ] アプリケーションコードのテスト完了
- [ ] バックアップ確認（データベース等）
- [ ] モニタリング設定確認

### 2. デプロイメント中
- [ ] 段階的トラフィック移行の監視
- [ ] エラーレートとレスポンス時間の確認
- [ ] ユーザー影響の最小化
- [ ] ロールバック手順の準備

### 3. デプロイメント後
- [ ] 24時間のモニタリング継続
- [ ] パフォーマンステストの実行
- [ ] ユーザーフィードバックの収集
- [ ] 次回デプロイメントの改善点洗い出し

## セキュリティ考慮事項

### 1. アクセス制御
- SSM Session Manager経由のアクセスのみ
- IAMロールベースの権限管理
- MFA必須設定

### 2. ネットワークセキュリティ
- プライベートサブネット配置
- セキュリティグループによる通信制限
- WAF設定（CloudFront経由の場合）

### 3. データ保護
- EBS暗号化の有効化
- 通信のTLS/SSL暗号化
- ログの適切な管理と保護

## パフォーマンス最適化

### 1. リソース最適化
- インスタンスタイプの適切な選択
- Auto Scaling設定の調整
- EBS最適化インスタンスの使用

### 2. アプリケーション最適化
- キャッシュ戦略の実装
- データベース接続プールの最適化
- 静的コンテンツのCDN配信

### 3. 監視と改善
- CloudWatchによる継続的監視
- X-Ray分散トレーシング
- パフォーマンステストの自動化

---

## 関連ドキュメント

- [POC環境構築手順](doc/POC環境構築手順.md)
- [テンプレート構成](doc/テンプレート構成.md)
- [ベストプラクティス](doc/ベストプラクティス.md)
- [Jenkins + Ansible + EC2 構成](Jenkins_ansible_EC2.md)
