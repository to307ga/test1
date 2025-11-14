# EC2 Auto Scaling Group 完全ガイド

このドキュメントでは、EC2 Auto Scaling Group（ASG）について中学生でもわかるレベルで詳しく説明します。

## 📚 目次

1. [Auto Scaling Groupとは？](#auto-scaling-groupとは)
2. [ヘルスチェックの詳細](#ヘルスチェックの詳細)
3. [複数のAuto Scaling Group作成](#複数のauto-scaling-group作成)
4. [実際の運用例](#実際の運用例)
5. [トラブルシューティング](#トラブルシューティング)

## 🤖 Auto Scaling Groupとは？

### 基本的な考え方

Auto Scaling Group（ASG）は、**コンピュータの自動管理システム**です。

人間の例で説明すると：
- **店長**：Auto Scaling Group
- **アルバイト**：EC2インスタンス
- **お客さん**：システムの利用者

店長は以下のことを自動で行います：
1. **必要な人数を維持**：3人必要なら常に3人確保
2. **体調不良者の交代**：調子悪い人がいたら新しい人を雇う
3. **忙しさに応じた調整**：忙しくなったら人数増加（今回は固定台数）

## 🏥 ヘルスチェックの詳細

### 🔍 ヘルスチェックの種類

#### 1. EC2ヘルスチェック（現在の設定）

**特徴**：最も基本的なチェック

**チェック内容**：
```
✅ 電源が入っているか？
✅ OSが起動しているか？
✅ AWSとの通信ができているか？
❌ アプリケーションは動いているか？（チェックしない）
❌ Webサーバは正常か？（チェックしない）
```

**健康判定の基準**：
- `running` = 健康 ✅
- `pending` = 起動中（猶予期間内なら健康扱い）⏳
- `stopping` = 不健康 ❌
- `stopped` = 不健康 ❌
- `terminated` = 完全に削除 💀

#### 2. ELBヘルスチェック（上級設定）

**特徴**：より詳細なアプリケーション レベルのチェック

**チェック内容**：
```
✅ 電源が入っているか？
✅ OSが起動しているか？
✅ Webサーバが応答するか？
✅ 指定したURLが正常に返答するか？
✅ アプリケーションが正常に動作するか？
```

### ⏰ ヘルスチェックのタイミング

#### グレースピリオド（猶予期間）

現在の設定：`HealthCheckGracePeriod: 300`（5分間）

**タイムライン例**：
```
時刻 0:00 - インスタンス起動開始
時刻 0:30 - OS起動中...
時刻 1:00 - ホスト名設定中... (pochub-001)
時刻 2:00 - httpd インストール中...
時刻 3:00 - Webサーバ起動中...
時刻 4:00 - 全設定完了
時刻 5:00 - ← この時点からヘルスチェック開始！
```

**猶予期間の意味**：
- **0～5分**：「準備中だから調子悪くても許可」
- **5分後**：「もう準備できたはず。本格チェック開始」

#### チェック頻度

**約30秒ごと**にチェックが実行されます：

```
5:00 - 1回目 ✅ (健康)
5:30 - 2回目 ✅ (健康)
6:00 - 3回目 ❌ (応答なし)
6:30 - 4回目 ❌ (応答なし)
7:00 - 判定：不健康 → 交換決定
```

### 🔄 自動復旧の流れ

#### ステップ1：異常検知
```
pochub-002 が応答しなくなった！
```

#### ステップ2：交換判定
```
ASG: 「pochub-002は不健康。新しいインスタンスを起動する」
```

#### ステップ3：新インスタンス起動
```
新しいインスタンス起動 → AZ 1c に配置 → 自動的に pochub-002 になる
```

#### ステップ4：古いインスタンス削除
```
新しい pochub-002 が健康になったら、古い方を削除
```

## 🏗️ 複数のAuto Scaling Group作成
# 🚨 ASG環境でAnsibleを使う際の注意点

Auto Scaling Group（ASG）で自動起動されるEC2インスタンスは、再起動やスケールイン/アウト時にIPアドレスやホスト名が変わるため、Ansibleのインベントリに「固定のIPやホスト名」を使う運用は推奨されません。

### 推奨運用
- **動的インベントリ（Dynamic Inventory）**を利用し、AWSのタグ情報でインスタンスを抽出する
- EC2インスタンスには、CloudFormationテンプレートでNameやRole、PatchGroupなどのタグを付与しておく
- AnsibleのAWS EC2プラグインやaws cliでタグ指定してインスタンス一覧を取得する

### CloudFormationで動的タグ付与の注意点
- LaunchTemplate/ASGのTagSpecificationsでは、直接AZ（アベイラビリティゾーン）名をタグに設定することはできません
- AZ名など動的な値は、EC2インスタンスのUserDataで起動時に取得し、AWS CLIでタグ付与する方法が一般的です

#### UserDataによるAZタグ付与例
```bash
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 create-tags --resources $INSTANCE_ID --tags Key=AvailabilityZone,Value=$AZ --region ap-northeast-1
```
このスクリプトをUserDataに追加することで、インスタンス起動時に自身のAZ名をタグとして付与できます。

### まとめ
- ASG環境では、IP/ホスト名は動的に変化するためタグベース運用が必須
- 動的なタグ（AZ名など）はUserDataで付与する
- Ansibleのインベントリはタグベースで動的生成すること

### ✅ 答え：はい、複数作成可能です！

Auto Scaling Groupは**用途別**に複数作成することが一般的なベストプラクティスです。

### 📋 実際の構成例

#### パターン1：機能別分離
```yaml
# WEB用 Auto Scaling Group
ASG-WEB:
  - MinSize: 2
  - MaxSize: 10
  - DesiredCapacity: 3
  - InstanceType: t3.medium
  - 用途: Webサーバ（Apache/Nginx）

# バッチ用 Auto Scaling Group  
ASG-BATCH:
  - MinSize: 1
  - MaxSize: 5
  - DesiredCapacity: 1
  - InstanceType: c5.large
  - 用途: データ処理・バッチジョブ
```

#### パターン2：環境別分離
```yaml
# 本番環境
ASG-PROD-WEB:
  - 台数: 6台（高可用性）
  - インスタンス: c5.xlarge（高性能）

# 開発環境
ASG-DEV-WEB:
  - 台数: 1台（コスト節約）
  - インスタンス: t3.small（最小構成）
```

#### パターン3：処理負荷別分離
```yaml
# フロントエンド用
ASG-FRONTEND:
  - 負荷：ユーザーアクセス処理
  - スケール：アクセス数に応じて増減

# バックエンド用
ASG-BACKEND:
  - 負荷：API処理・DB接続
  - スケール：処理量に応じて増減

# バッチ処理用
ASG-BATCH:
  - 負荷：大量データ処理
  - スケール：処理待ちキューに応じて増減
```

### 🎯 複数ASG作成のメリット

#### 1. **専門性**
- Webサーバには軽量インスタンス
- データ処理には高性能CPU

#### 2. **独立性**
- Web側に障害が起きてもバッチ処理は継続
- 片方だけメンテナンス可能

#### 3. **コスト最適化**
- 用途に応じた最適なインスタンスタイプ選択
- 必要な時だけスケールアウト

#### 4. **運用の柔軟性**
- それぞれ異なるデプロイタイミング
- 異なるヘルスチェック設定

## 💼 実際の運用例

### 現在のPOC設定
```yaml
AutoScalingGroup:
  Name: poc-web-asg
  MinSize: 3
  MaxSize: 3
  DesiredCapacity: 3
  HealthCheckType: EC2
  HealthCheckGracePeriod: 300秒
```

### 本格運用時の推奨設定例

#### WEB用ASG
```yaml
AutoScalingGroup-WEB:
  MinSize: 2
  MaxSize: 10
  DesiredCapacity: 3
  HealthCheckType: ELB  # より詳細なチェック
  HealthCheckGracePeriod: 600秒  # Webアプリ起動に時間がかかる場合
  TargetGroupARNs: 
    - ALB-TargetGroup-ARN
```

#### バッチ用ASG
```yaml
AutoScalingGroup-BATCH:
  MinSize: 0  # 処理がない時は0台
  MaxSize: 20  # 大量処理時は大幅スケール
  DesiredCapacity: 1
  HealthCheckType: EC2  # シンプルなチェックで十分
  HealthCheckGracePeriod: 300秒
```

## 🚨 トラブルシューティング

### よくある問題と対策

#### 1. インスタンスが頻繁に交換される
**原因**：
- グレースピリオドが短すぎる
- アプリケーション起動に時間がかかる

**対策**：
```yaml
HealthCheckGracePeriod: 600  # 5分→10分に延長
```

#### 2. 障害時に復旧しない
**原因**：
- ヘルスチェックが甘すぎる（EC2のみ）
- アプリケーション障害を検知できない

**対策**：
```yaml
HealthCheckType: ELB  # ALBのヘルスチェックを利用
```

#### 3. スケールアウトしない
**原因**：
- 固定台数設定（Min=Max=Desired）
- CloudWatchアラームが設定されていない

**対策**：
```yaml
MinSize: 2
MaxSize: 10  # 拡張可能に設定
```

### デバッグ方法

#### CloudWatch Logsで確認
```bash
# インスタンス起動ログ
/var/log/cloud-init-output.log

# ホスト名設定ログ  
/var/log/hostname-setup.log

# Apache ログ
/var/log/httpd/access_log
/var/log/httpd/error_log
```

#### SSM Session Managerで調査
```bash
# ホスト名確認
hostname

# サービス状態確認
systemctl status httpd

# ヘルスチェックエンドポイント確認
curl http://localhost/health
```

## � 段階的なヘルスチェック設定

### ✅ 答え：はい、段階的な設定変更が可能です！

ELBヘルスチェックでも、初期構築時は基本的なチェックのみから開始し、後からアプリケーション レベルのチェックに段階的に移行することができます。

### 📋 段階的移行のパターン

#### 🏗️ 段階1：初期構築時（EC2同等レベル）

**ALB ターゲットグループ設定**：
```yaml
HealthCheckPath: /         # シンプルなルートパス
HealthCheckProtocol: HTTP
HealthCheckPort: 80
HealthCheckIntervalSeconds: 30
HealthyThresholdCount: 2     # 2回成功で健康
UnhealthyThresholdCount: 5   # 5回失敗で不健康
HealthCheckTimeoutSeconds: 5
Matcher: 
  HttpCode: "200,404"        # 404も許可（初期段階）
```

**この時点での動作**：
- HTTPサーバが起動しているかのみチェック
- ページの内容は問わない（404でもOK）
- EC2ヘルスチェックと同等の基本チェック

#### 🚀 段階2：Webアプリデプロイ後

**設定変更**：
```yaml
HealthCheckPath: /health    # 専用ヘルスチェックエンドポイント
HealthCheckProtocol: HTTP
HealthCheckPort: 80
HealthCheckIntervalSeconds: 15  # より頻繁なチェック
HealthyThresholdCount: 2
UnhealthyThresholdCount: 3      # より厳しい判定
HealthCheckTimeoutSeconds: 5
Matcher: 
  HttpCode: "200"              # 200のみ許可（厳格化）
```

**この時点での動作**：
- 専用ヘルスチェックエンドポイントで詳細チェック
- アプリケーションの健全性も含めて判定
- より精密な監視を実現

### 🔧 実装の具体例

#### 段階1：基本的なHTTPレスポンス

**ターゲットグループ作成時**：
```yaml
TargetGroup:
  Type: AWS::ElasticLoadBalancingV2::TargetGroup
  Properties:
    HealthCheckPath: /              # ルートパスをチェック
    HealthCheckIntervalSeconds: 30
    HealthCheckTimeoutSeconds: 5
    HealthyThresholdCount: 2
    UnhealthyThresholdCount: 5
    Matcher:
      HttpCode: "200,404"           # 初期段階は緩い設定
```

**Webサーバの初期状態**：
```html
<!-- /var/www/html/index.html -->
<!DOCTYPE html>
<html>
<head><title>Server Starting...</title></head>
<body>
    <h1>Server is running</h1>
    <p>Basic web server is operational</p>
</body>
</html>
```

#### 段階2：アプリケーション ヘルスチェック

**ターゲットグループ設定変更**：
```bash
# AWS CLIで設定変更
aws elbv2 modify-target-group \
    --target-group-arn <TARGET_GROUP_ARN> \
    --health-check-path "/health" \
    --matcher HttpCode="200"
```

**専用ヘルスチェックエンドポイント**：
```bash
# /var/www/html/health
#!/bin/bash
echo "Content-Type: application/json"
echo ""

# データベース接続チェック
if ! mysql -u app -p$DB_PASS -e "SELECT 1" > /dev/null 2>&1; then
    echo '{"status": "unhealthy", "error": "database_connection_failed"}'
    exit 0
fi

# アプリケーション固有のチェック
if ! systemctl is-active --quiet myapp; then
    echo '{"status": "unhealthy", "error": "application_service_down"}'
    exit 0
fi

echo '{"status": "healthy", "timestamp": "'$(date -Iseconds)'"}'
```

### ⚙️ 段階的移行の手順

#### ステップ1：ALB + 基本ヘルスチェック導入

1. **ALBとターゲットグループ作成**
2. **基本的なヘルスチェック設定**（`/` パス、緩い条件）
3. **ASGのヘルスチェックタイプ変更**：
   ```yaml
   HealthCheckType: ELB
   HealthCheckGracePeriod: 600  # 少し長めに設定
   ```

#### ステップ2：アプリケーションデプロイ

1. **アプリケーションのデプロイ**
2. **専用ヘルスチェックエンドポイント作成**
3. **動作確認**（手動でエンドポイントテスト）

#### ステップ3：ヘルスチェック設定の厳格化

1. **ターゲットグループのヘルスチェックパス変更**
2. **判定条件の厳格化**（UnhealthyThresholdCount削減など）
3. **監視とログで動作確認**

### 🎯 メリット

#### 1. **リスク分散**
- 初期段階での設定トラブルを最小化
- 段階的な検証で問題を早期発見

#### 2. **運用の安定性**
- 基本機能から段階的に機能追加
- 各段階での動作確認が可能

#### 3. **チーム対応**
- インフラチーム：基本的なALB設定
- アプリチーム：後からヘルスチェック詳細化

#### 4. **障害時の切り戻し**
- 問題発生時は前の段階に戻すことが可能
- 設定変更の影響範囲を限定

### 🔄 設定変更の注意点

#### 1. **グレースピリオドの調整**
```yaml
# 初期段階
HealthCheckGracePeriod: 300  # 5分

# アプリ導入後
HealthCheckGracePeriod: 600  # 10分（アプリ起動時間考慮）
```

#### 2. **段階的な条件厳格化**
```yaml
# 段階1：緩い条件
HealthCheckIntervalSeconds: 30
UnhealthyThresholdCount: 5

# 段階2：厳しい条件
HealthCheckIntervalSeconds: 15
UnhealthyThresholdCount: 3
```

#### 3. **ログとモニタリング**
- 各段階での変更前後のログ確認
- CloudWatch Metricsでヘルスチェック状況を監視
- アラート設定で異常を早期検知

### 💡 実際の運用推奨フロー

```
1. EC2ヘルスチェック（現在）
   ↓ ALB導入
2. ELBヘルスチェック（基本HTTP応答）
   ↓ アプリデプロイ
3. ELBヘルスチェック（アプリケーション詳細）
   ↓ 本格運用
4. ELBヘルスチェック（本格的な監視）
```

この段階的なアプローチにより、安全で確実なシステム移行が可能になります。

## 🏗️ 段階的構築：最小EC2 + ALB アプローチ

### ✅ 答え：はい、その構成は実現可能で推奨されます！

この方法は実際の本格運用で広く使われているベストプラクティスです。

### � 段階別実装方針

#### 🔧 段階1：最小限のEC2 + ALB構成

**EC2テンプレート修正内容**：
```bash
# UserDataから削除する項目
# dnf install -y httpd          # ← 削除
# systemctl enable httpd        # ← 削除  
# systemctl start httpd         # ← 削除
# Webページ作成部分             # ← 削除
# ヘルスチェックエンドポイント   # ← 削除
```

**残す項目**：
```bash
# 基本的なシステム設定のみ
dnf update -y
dnf install -y wget curl unzip   # 基本ツールのみ

# ホスト名設定（これは残す）
hostnamectl set-hostname $HOSTNAME

# CloudWatch Agent（監視用）
# AWS CLI（管理用）
# SSM関連設定
```

#### 🌐 ALBテンプレート新規作成

**ALB + ターゲットグループ構成**：
```yaml
# ALBテンプレート（新規作成）
ApplicationLoadBalancer:
  Type: AWS::ElasticLoadBalancingV2::LoadBalancer
  Properties:
    Name: !Sub '${Environment}-poc-alb'
    Type: application
    Scheme: internal
    SecurityGroups:
      - !Ref ALBSecurityGroup
    Subnets: !Ref PrivateSubnets

TargetGroup:
  Type: AWS::ElasticLoadBalancingV2::TargetGroup
  Properties:
    Name: !Sub '${Environment}-poc-tg'
    Port: 22                    # SSH接続確認
    Protocol: HTTP
    VpcId: !Ref VPCId
    HealthCheckEnabled: true
    HealthCheckPath: /          # 初期は適当なパス
    HealthCheckProtocol: TCP    # TCPレベルの確認のみ
    HealthCheckPort: 22         # SSH ポートで生存確認
    HealthCheckIntervalSeconds: 30
    HealthyThresholdCount: 2
    UnhealthyThresholdCount: 5
    HealthCheckTimeoutSeconds: 5
```

#### 🔄 EC2テンプレートのASG設定変更

```yaml
AutoScalingGroup:
  Properties:
    HealthCheckType: ELB              # ELBヘルスチェック使用
    HealthCheckGracePeriod: 300       # 5分間の猶予
    TargetGroupARNs:                  # ターゲットグループに登録
      - !Ref TargetGroup
```

### 🚀 段階2：Jenkins経由のアプリケーション構築

#### 📦 Jenkinsパイプライン例

```groovy
pipeline {
    agent any
    
    stages {
        stage('Application Setup') {
            steps {
                script {
                    // 各EC2インスタンスに対してアプリケーション構築
                    def instances = getTargetInstances()
                    
                    instances.each { instance ->
                        // SSM経由でコマンド実行
                        sh """
                            aws ssm send-command \
                                --instance-ids ${instance} \
                                --document-name "AWS-RunShellScript" \
                                --parameters 'commands=[
                                    "dnf install -y httpd",
                                    "systemctl enable httpd",
                                    "systemctl start httpd",
                                    "# アプリケーション固有の設定"
                                ]'
                        """
                    }
                }
            }
        }
        
        stage('Health Check Endpoint Setup') {
            steps {
                script {
                    // ヘルスチェックエンドポイント作成
                    instances.each { instance ->
                        sh """
                            aws ssm send-command \
                                --instance-ids ${instance} \
                                --parameters 'commands=[
                                    "cat > /var/www/html/health << EOF
#!/bin/bash
echo \"Content-Type: application/json\"
echo \"\"
echo {\\\"status\\\": \\\"healthy\\\", \\\"hostname\\\": \\\"$(hostname)\\\", \\\"timestamp\\\": \\\"$(date -Iseconds)\\\"}
EOF",
                                    "chmod +x /var/www/html/health"
                                ]'
                        """
                    }
                }
            }
        }
        
        stage('Update Health Check Configuration') {
            steps {
                script {
                    // ALBターゲットグループのヘルスチェック設定変更
                    sh """
                        aws elbv2 modify-target-group \
                            --target-group-arn ${TARGET_GROUP_ARN} \
                            --health-check-protocol HTTP \
                            --health-check-port 80 \
                            --health-check-path "/health" \
                            --matcher HttpCode="200"
                    """
                }
            }
        }
    }
}
```

### 🔄 ヘルスチェック設定の段階的変更

#### 初期状態（EC2起動直後）
```yaml
HealthCheckProtocol: TCP
HealthCheckPort: 22
# SSH接続可能 = OS起動完了 = 健康
```

#### アプリケーション構築後（Jenkins実行後）
```yaml
HealthCheckProtocol: HTTP
HealthCheckPort: 80
HealthCheckPath: /health
Matcher: HttpCode="200"
# Webアプリケーション応答 = アプリ健康
```

### 🎯 この構成のメリット

#### 1. **リスクの最小化**
- 初期構築時のトラブル要因を削減
- アプリケーション構築は安定した基盤上で実行

#### 2. **柔軟な運用**
- Jenkinsで様々なアプリケーション構成に対応
- 環境ごとに異なる構築手順が可能

#### 3. **段階的な監視強化**
- 基本的な生存確認から開始
- アプリケーション完成後に詳細監視に移行

#### 4. **CI/CDとの親和性**
- コードベースでのアプリケーション管理
- バージョン管理されたデプロイメント

### 🔧 実装時の注意点

#### 1. **ターゲットグループの初期登録**
```yaml
# ASGで自動的にインスタンスをターゲットグループに登録
TargetGroupARNs:
  - !Ref TargetGroup
```

#### 2. **ヘルスチェック設定変更タイミング**
```bash
# アプリケーション構築完了後に実行
aws elbv2 modify-target-group \
    --target-group-arn $TG_ARN \
    --health-check-path "/health"
```

#### 3. **グレースピリオドの調整**
```yaml
# アプリケーション構築時間を考慮
HealthCheckGracePeriod: 600  # 10分に延長
```

### 💼 必要なテンプレート構成

#### 新規作成が必要
1. **ALBテンプレート**（`alb.yaml`）
2. **ALB用セキュリティグループテンプレート**

#### 修正が必要  
1. **EC2テンプレート**（HTTPD削除）
2. **既存セキュリティグループテンプレート**（ALB通信許可）

### 🚀 実装フロー

```
1. ALBテンプレート作成
   ↓
2. EC2テンプレート修正（HTTPD削除）
   ↓  
3. スタックデプロイ（最小構成）
   ↓
4. Jenkinsパイプライン実行
   ↓
5. ヘルスチェック設定変更
   ↓
6. 本格運用開始
```

この方法により、**安全で柔軟なシステム構築**が実現できます。

## �📊 まとめ

- **Auto Scaling Group**は「コンピュータの自動管理システム」
- **EC2ヘルスチェック**は基本的な生存確認（電源・OS）
- **複数ASG作成**は可能で、用途別分離が推奨
- **グレースピリオド**で起動時間を考慮した設定が重要
- **本格運用時**はELBヘルスチェックでより詳細な監視を実現

現在のPOC設定は、基本的な自動復旧機能として十分機能します。本格運用時には、要件に応じてより詳細な設定を検討してください。
