# Jenkins Docker Build Pipeline - 構築・運用ガイド

## 📋 概要

このドキュメントは、Giteaリポジトリを使用してJenkinsカスタムDockerイメージをビルドし、ECRに配置するパイプラインの構築・運用方法を説明します。

## 🏷️ 世代管理とタグ戦略

### 自動生成されるイメージタグ
git pushにより、以下の4つのタグが自動的に作成されます：

| タグ形式 | 例 | 用途 |
|---------|-----|-----|
| `latest` | `latest` | 常に最新のイメージ（開発・テスト用） |
| `{commit-hash}` | `ea80486` | 特定コミットのイメージ（トレーサビリティ） |
| `{YYYYMMDD-HHMMSS}` | `20251014-105459` | ビルド日時（時系列管理） |
| `{YYYYMMDD-HHMMSS-commit}` | `20251014-105459-ea80486` | 完全トレーサビリティ |

### パラメータ化されたライフサイクルポリシー

#### 設定可能パラメータ
```yaml
# /home/tomo/poc/sceptre/config/poc/ecr-jenkins.yaml
parameters:
  # 環境プリセット (development/staging/production)
  LifecyclePolicyProfile: development
  
  # 保持するイメージ数
  ProductionImageCount: 10      # v*, release* タグ
  DevelopmentImageCount: 5      # dev*, feature*, latest タグ  
  DateBasedImageCount: 20       # 202* (YYYY形式) タグ
  
  # 保持期間（日数）
  UntaggedImageRetentionDays: 1     # 未タグイメージ
  TemporaryImageRetentionDays: 7    # temp*, branch*, pr*, test* タグ
```

#### 環境別プリセット設定

##### Development環境 (寛容な設定)
- **プロダクション**: `v*`, `release*` → 10個まで保持
- **開発**: `dev*`, `feature*`, `latest` → 5個まで保持
- **一時的**: `temp*`, `branch*`, `pr*`, `test*` → 7日間保持
- **日付ベース**: `202*` → 20個まで保持

##### Staging環境 (中間設定)
- **プロダクション**: `v*`, `release*`, `stable*` → 10個まで保持
- **開発**: `dev*`, `feature*`, `latest`, `staging*` → 5個まで保持
- **一時的**: `temp*`, `branch*`, `pr*`, `test*`, `hotfix*` → 7日間保持

##### Production環境 (厳格な設定)
- **プロダクション**: `v*`, `release*`, `stable*`, `prod*` → 10個まで保持
- **開発**: `latest` のみ → 5個まで保持
- **一時的**: `temp*`, `hotfix*` のみ → 7日間保持

### 設定変更例

#### ストレージ節約設定
```yaml
parameters:
  LifecyclePolicyProfile: production
  ProductionImageCount: 5              # 保持数削減
  DevelopmentImageCount: 2
  DateBasedImageCount: 10
  UntaggedImageRetentionDays: 1        # 即座に削除
  TemporaryImageRetentionDays: 1       # 1日で削除
```

#### 長期保持設定（監査要件など）
```yaml
parameters:
  LifecyclePolicyProfile: development
  ProductionImageCount: 50             # 長期保持
  DevelopmentImageCount: 20
  DateBasedImageCount: 100
  TemporaryImageRetentionDays: 30      # 30日間保持
```

### 設定変更手順

#### 1. パラメータ変更
```bash
# 設定ファイル編集
vi /home/tomo/poc/sceptre/config/poc/ecr-jenkins.yaml

# 例: production環境への変更
parameters:
  LifecyclePolicyProfile: production
  ProductionImageCount: 20
  DevelopmentImageCount: 3
  DateBasedImageCount: 15
  TemporaryImageRetentionDays: 3
```

#### 2. 設定適用
```bash
# 変更をプレビュー（安全確認）
cd /home/tomo/poc/sceptre
uv run sceptre diff poc/ecr-jenkins.yaml

# 設定適用
uv run sceptre update poc/ecr-jenkins.yaml -y

# 適用結果確認
uv run sceptre list outputs poc/ecr-jenkins.yaml | grep LifecyclePolicy
```

#### 3. 設定反映確認
```bash
# ECRライフサイクルポリシーの内容確認
aws ecr get-lifecycle-policy \
  --repository-name poc-jenkins-custom \
  --region ap-northeast-1 \
  --query 'lifecyclePolicyText' \
  --output text | jq .

# 現在の設定サマリー確認
aws cloudformation describe-stacks \
  --stack-name poc-poc-ecr-jenkins \
  --query 'Stacks[0].Outputs[?OutputKey==`LifecyclePolicySettings`].OutputValue' \
  --output text \
  --region ap-northeast-1
```

### 現在の設定確認
```bash
# 現在のライフサイクルポリシー設定確認
aws cloudformation describe-stacks \
  --stack-name poc-poc-ecr-jenkins \
  --query 'Stacks[0].Outputs[?OutputKey==`LifecyclePolicySettings`].OutputValue' \
  --output text \
  --region ap-northeast-1
```

### タグ戦略の利点

#### 1. **完全なトレーサビリティ**
```bash
# 特定の日時のイメージを使用
docker pull 627642418836.dkr.ecr.ap-northeast-1.amazonaws.com/poc-jenkins-custom:20251014-105459

# 特定のコミットのイメージを使用  
docker pull 627642418836.dkr.ecr.ap-northeast-1.amazonaws.com/poc-jenkins-custom:ea80486

# 完全な情報付きイメージ
docker pull 627642418836.dkr.ecr.ap-northeast-1.amazonaws.com/poc-jenkins-custom:20251014-105459-ea80486
```

#### 2. **安全なロールバック**
```bash
# 前のビルドに戻す場合
aws ecs update-service \
  --cluster poc-ecs-cluster \
  --service poc-jenkins-service \
  --task-definition poc-jenkins:previous-revision \
  --region ap-northeast-1
```

#### 3. **自動クリーンアップ**
- 古いイメージは自動削除でストレージコスト削減
- 環境別の適切な保持ポリシー
- 開発効率と運用コストのバランス

## 🏗️ アーキテクチャ

```
Gitea Repository (Dockerfile) 
    ↓ (webhook)
API Gateway → Lambda → CodeBuild → ECR Repository
    ↓
ECS Fargate (Jenkins)
```

## 📁 作成されるAWSリソース

### 1. ECR Repository (`ecr-jenkins.yaml`)
- **リポジトリ名**: `poc-jenkins-custom`
- **イメージスキャン**: プッシュ時に有効
- **ライフサイクルポリシー**: 古いイメージ自動削除
- **アクセス制御**: ECS・CodeBuildからのアクセス許可

### 2. CodeBuild Project (`codebuild-jenkins.yaml`)
- **プロジェクト名**: `poc-jenkins-docker-build`
- **ビルド環境**: AWS CodeBuild Standard 7.0 (Docker対応)
- **VPC**: プライベートサブネット内で実行
- **ビルドスペック**: Dockerfile → ECRプッシュの自動化

### 3. Build Trigger (`jenkins-build-trigger.yaml`)
- **Lambda関数**: Giteaウェブフック受信・CodeBuild起動
- **API Gateway**: ウェブフックエンドポイント提供
- **自動化**: Gitコミット → 自動ビルド

## 🚀 デプロイ手順

### Step 1: ECRリポジトリ作成
```bash
cd /home/tomo/poc/sceptre
uv run sceptre create poc/ecr-jenkins.yaml -y
```

### Step 2: CodeBuildプロジェクト作成
```bash
# VPCが先に作成されている必要があります
uv run sceptre create poc/codebuild-jenkins.yaml -y
```

### Step 3: ビルドトリガー作成
```bash
uv run sceptre create poc/jenkins-build-trigger.yaml -y
```

### Step 4: ウェブフックURL取得
```bash
# ウェブフックURLを取得
aws cloudformation describe-stacks \
  --stack-name poc-jenkins-build-trigger \
  --query 'Stacks[0].Outputs[?OutputKey==`WebhookUrl`].OutputValue' \
  --output text \
  --region ap-northeast-1
```

## 📂 Giteaリポジトリセットアップ

### 1. リポジトリ作成
1. Giteaにログイン: `http://[gitea-alb-dns]:3000`
2. 新規リポジトリ作成: `jenkins-docker`
3. 組織: `poc` または個人アカウント

### 2. Dockerfileアップロード
```bash
# ローカルからGiteaへプッシュ
cd /home/tomo/poc
git init
git add docker/jenkins/
git commit -m "Add Jenkins Dockerfile and plugins.txt"
git remote add origin http://[gitea-alb-dns]:3000/poc/jenkins-docker.git
git push -u origin main
```

### 3. Webhookの設定
1. リポジトリ設定 → Webhooks
2. Webhook追加:
   - **Payload URL**: `https://[api-gateway-id].execute-api.ap-northeast-1.amazonaws.com/prod/webhook`
   - **Content Type**: `application/json`
   - **Secret**: 空（必要に応じて後で設定）
   - **Events**: `Push events`のみ

## 🔧 手動ビルド実行

### CodeBuildから直接実行
```bash
# 手動ビルド実行
aws codebuild start-build \
  --project-name poc-jenkins-docker-build \
  --region ap-northeast-1

# ビルド状況確認
BUILD_ID=$(aws codebuild list-builds-for-project \
  --project-name poc-jenkins-docker-build \
  --query 'ids[0]' \
  --output text \
  --region ap-northeast-1)

aws codebuild batch-get-builds \
  --ids $BUILD_ID \
  --region ap-northeast-1
```

### API Gateway経由（ウェブフック形式）
```bash
# ウェブフックURL取得
WEBHOOK_URL=$(aws cloudformation describe-stacks \
  --stack-name poc-jenkins-build-trigger \
  --query 'Stacks[0].Outputs[?OutputKey==`WebhookUrl`].OutputValue' \
  --output text \
  --region ap-northeast-1)

# 手動でウェブフック送信
curl -X POST $WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d '{
    "repository": {
      "name": "jenkins-docker",
      "clone_url": "http://gitea-alb-dns:3000/poc/jenkins-docker.git"
    },
    "commits": [{
      "id": "manual-trigger",
      "message": "Manual build trigger",
      "author": {"name": "Admin"}
    }]
  }'
```

## 🔍 ビルド確認

### 1. git push後の自動ビルド確認
```bash
# git pushから2-3分後に確認
# 最新ビルドの実行状況確認
aws codebuild list-builds-for-project \
  --project-name poc-jenkins-docker-build \
  --region ap-northeast-1

# 最新ビルドの詳細確認
LATEST_BUILD=$(aws codebuild list-builds-for-project \
  --project-name poc-jenkins-docker-build \
  --query 'ids[0]' \
  --output text \
  --region ap-northeast-1)

aws codebuild batch-get-builds \
  --ids $LATEST_BUILD \
  --query 'builds[0].{status:buildStatus,phase:currentPhase,commit:sourceVersion,startTime:startTime}' \
  --output table \
  --region ap-northeast-1
```

### 2. リアルタイムビルドログ監視
```bash
# ビルド実行中のログをリアルタイム確認
aws logs tail /aws/codebuild/poc-jenkins-docker-build \
  --follow \
  --region ap-northeast-1

# 最新5分間のログのみ確認
aws logs tail /aws/codebuild/poc-jenkins-docker-build \
  --since 5m \
  --region ap-northeast-1
```

### 3. 世代管理されたイメージタグ確認
```bash
# ECRの全イメージとタグを確認
aws ecr describe-images \
  --repository-name poc-jenkins-custom \
  --query 'imageDetails[].[imageTags,imagePushedAt,imageSizeInBytes]' \
  --output table \
  --region ap-northeast-1

# 最新ビルドで作成されたタグ確認
aws ecr describe-images \
  --repository-name poc-jenkins-custom \
  --query 'imageDetails[0].imageTags' \
  --region ap-northeast-1
```

### 4. ビルド成功確認フロー
```bash
#!/bin/bash
# git push後の完全な確認スクリプト

echo "=== Git Push後のビルド確認 ==="
echo "1. 最新ビルド状況確認..."
LATEST_BUILD=$(aws codebuild list-builds-for-project \
  --project-name poc-jenkins-docker-build \
  --query 'ids[0]' \
  --output text \
  --region ap-northeast-1)

echo "最新ビルドID: $LATEST_BUILD"

# ビルド完了まで待機
echo "2. ビルド完了待機..."
while true; do
  STATUS=$(aws codebuild batch-get-builds \
    --ids $LATEST_BUILD \
    --query 'builds[0].buildStatus' \
    --output text \
    --region ap-northeast-1)
  
  if [ "$STATUS" = "SUCCEEDED" ]; then
    echo "✅ ビルド成功！"
    break
  elif [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "FAULT" ] || [ "$STATUS" = "STOPPED" ] || [ "$STATUS" = "TIMED_OUT" ]; then
    echo "❌ ビルド失敗: $STATUS"
    exit 1
  else
    echo "ビルド実行中... ($STATUS)"
    sleep 10
  fi
done

echo "3. 作成されたイメージタグ確認..."
aws ecr describe-images \
  --repository-name poc-jenkins-custom \
  --query 'imageDetails[0].imageTags' \
  --region ap-northeast-1

echo "=== 確認完了 ==="
```

### 5. CodeBuildログ確認
```bash
# CloudWatch Logsでビルド状況確認
aws logs describe-log-streams \
  --log-group-name "/aws/codebuild/poc-jenkins-docker-build" \
  --region ap-northeast-1

# 最新ログ確認
LATEST_STREAM=$(aws logs describe-log-streams \
  --log-group-name "/aws/codebuild/poc-jenkins-docker-build" \
  --order-by LastEventTime \
  --descending \
  --max-items 1 \
  --query 'logStreams[0].logStreamName' \
  --output text \
  --region ap-northeast-1)

aws logs get-log-events \
  --log-group-name "/aws/codebuild/poc-jenkins-docker-build" \
  --log-stream-name "$LATEST_STREAM" \
  --region ap-northeast-1
```

### 6. ECR内イメージ確認
```bash
# ECRリポジトリのイメージ一覧
aws ecr describe-images \
  --repository-name poc-jenkins-custom \
  --region ap-northeast-1

# 最新イメージタグ確認
aws ecr describe-images \
  --repository-name poc-jenkins-custom \
  --image-ids imageTag=latest \
  --region ap-northeast-1
```

## 🔄 ECS Fargateでのイメージ使用

### タスク定義での指定
```json
{
  "family": "poc-jenkins",
  "containerDefinitions": [
    {
      "name": "jenkins",
      "image": "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/poc-jenkins-custom:latest",
      "memory": 2048,
      "cpu": 1024,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ]
    }
  ]
}
```

### ECSサービス更新
```bash
# サービス更新（新しいイメージデプロイ）
aws ecs update-service \
  --cluster poc-ecs-cluster \
  --service poc-jenkins-service \
  --force-new-deployment \
  --region ap-northeast-1
```

## 🛠️ トラブルシューティング

### 1. CodeBuildエラー
```bash
# ビルドエラー詳細確認
aws codebuild batch-get-builds \
  --ids [BUILD_ID] \
  --query 'builds[0].logs' \
  --region ap-northeast-1
```

**よくあるエラー**:
- **Docker権限エラー**: `PrivilegedMode: true`が設定されているか確認
- **ECR認証エラー**: CodeBuildロールにECR権限があるか確認
- **VPC接続エラー**: セキュリティグループで必要なポートが開いているか確認

### 2. Lambda/API Gatewayエラー
```bash
# Lambda実行ログ確認
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/poc-jenkins-build-trigger" \
  --region ap-northeast-1
```

### 3. Gitea Webhook設定確認
- Gitea管理画面で配信履歴を確認
- HTTPステータスコードが200以外の場合は設定見直し
- API GatewayのCORS설�이 必요な場合があります

## 🔐 セキュリティ考慮事項

### 1. IAMロール権限
- CodeBuildロール: 最小限のECR權限のみ
- Lambdaロール: CodeBuild実行権限のみ

### 2. ネットワークセキュリティ
- CodeBuildはプライベートサブネット内で実行
- セキュリティグループで必要最小限の通信のみ許可

### 3. API Gateway認証
現在はパブリックエンドポイントですが、以下の強化が可能:
- API Keyによる認証
- ソースIP制限
- WAF導入

## 📊 コスト見積もり

### 月間概算コスト（ap-northeast-1）
- **ECR**: ストレージ使用量による（~$1/month）
- **CodeBuild**: ビルド実行時間による（~$5/month）
- **Lambda**: 実行回数による（~$1/month）
- **API Gateway**: リクエスト数による（~$1/month）

**合計**: 約$8/month（約1,100円/月）

## 📝 運用メモ

### 定期メンテナンス
- **ECRイメージライフサイクル**: パラメータ化された自動削除
- **CloudWatchログ**: 14日保持
- **ライフサイクルポリシー確認**: 月1回設定見直し

### 監視項目
- **CodeBuildビルド成功率**: 95%以上を維持
- **ECRプッシュ成功確認**: タグ生成の完全性
- **Lambda実行エラー監視**: Webhook受信失敗の早期検知
- **ストレージ使用量**: ECRリポジトリサイズの推移

### Git Push → 本番デプロイのワークフロー

#### 1. 開発フェーズ
```bash
# 機能開発
git checkout -b feature/new-plugin
# Dockerfile修正、plugins.txt更新
git add .
git commit -m "feat: Add new Jenkins plugin"
git push origin feature/new-plugin
# → 自動的に feature-{hash} タグでECRにプッシュ
```

#### 2. テスト用デプロイ
```bash
# テスト環境でイメージ確認
aws ecs update-service \
  --cluster poc-ecs-test-cluster \
  --service poc-jenkins-test \
  --task-definition poc-jenkins-test \
  --region ap-northeast-1
```

#### 3. プロダクション準備
```bash
# mainブランチにマージ
git checkout main
git merge feature/new-plugin
git tag v1.2.0
git push origin main --tags
# → latest, v1.2.0, {date-hash} 複数タグで自動ビルド
```

#### 4. プロダクションデプロイ
```bash
# 本番環境へのデプロイ
aws ecs update-service \
  --cluster poc-ecs-prod-cluster \
  --service poc-jenkins-prod \
  --task-definition poc-jenkins-prod \
  --region ap-northeast-1
```

### トラブル時の対応

#### ビルド失敗時の調査手順
```bash
# 1. 最新ビルドの失敗理由確認
FAILED_BUILD=$(aws codebuild list-builds-for-project \
  --project-name poc-jenkins-docker-build \
  --query 'ids[0]' \
  --output text \
  --region ap-northeast-1)

aws codebuild batch-get-builds \
  --ids $FAILED_BUILD \
  --query 'builds[0].phases[?phaseStatus==`FAILED`]' \
  --region ap-northeast-1

# 2. 詳細ログ確認
aws logs get-log-events \
  --log-group-name "/aws/codebuild/poc-jenkins-docker-build" \
  --log-stream-name "$FAILED_BUILD" \
  --region ap-northeast-1

# 3. 前回成功したイメージへのロールバック
aws ecs update-service \
  --cluster poc-ecs-cluster \
  --service poc-jenkins-service \
  --task-definition poc-jenkins:previous-working \
  --region ap-northeast-1
```

#### 容量不足時の対応
```bash
# ECRストレージ使用量確認
aws ecr describe-repository-statistics \
  --repository-names poc-jenkins-custom \
  --region ap-northeast-1

# 不要なイメージの手動削除
aws ecr list-images \
  --repository-name poc-jenkins-custom \
  --filter tagStatus=UNTAGGED \
  --query 'imageIds[*]' \
  --output json \
  --region ap-northeast-1 > untagged-images.json

aws ecr batch-delete-image \
  --repository-name poc-jenkins-custom \
  --image-ids file://untagged-images.json \
  --region ap-northeast-1
```

### パフォーマンス最適化

#### 1. ビルド時間短縮
- **マルチステージビルド**: Dockerfileの最適化
- **レイヤーキャッシュ**: 変更頻度の低い処理を前段に配置
- **CodeBuild設定**: COMPUTE_TYPE を適切にサイズ調整

#### 2. ネットワーク最適化
- **VPCエンドポイント**: ECR, CloudWatch Logs用のVPCエンドポイント設置でデータ転送費削減

#### 3. コスト最適化
```bash
# 現在の設定でのコスト試算
echo "=== ECRストレージコスト試算 ==="
REPO_SIZE=$(aws ecr describe-repository-statistics \
  --repository-names poc-jenkins-custom \
  --query 'repositoryStatistics.repositorySizeInBytes' \
  --output text \
  --region ap-northeast-1)

echo "Repository Size: $(($REPO_SIZE / 1024 / 1024)) MB"
echo "月間コスト概算: \$$(echo "scale=2; $REPO_SIZE / 1024 / 1024 / 1024 * 0.10" | bc)"
```

### セキュリティ運用

#### 1. 脆弱性スキャン結果確認
```bash
# ECRイメージスキャン結果確認
aws ecr describe-image-scan-findings \
  --repository-name poc-jenkins-custom \
  --image-id imageTag=latest \
  --region ap-northeast-1
```

#### 2. アクセスログ監視
```bash
# API Gateway アクセスログ確認
aws logs filter-log-events \
  --log-group-name "API-Gateway-Execution-Logs_[api-id]/prod" \
  --filter-pattern "[timestamp, request_id, ip, user, timestamp, method, resource, status_code >= 400]" \
  --region ap-northeast-1
```

### 定期的な設定見直し

#### 月次確認項目
1. **ライフサイクルポリシー効果測定**
2. **ビルド頻度とストレージ使用量の相関確認**  
3. **失敗率の傾向分析**
4. **コスト推移の確認**

#### 四半期確認項目
1. **セキュリティスキャン結果レビュー**
2. **パフォーマンスベンチマーク**
3. **災害復旧テスト**

---

**作成日**: 2025年10月14日  
**対象リージョン**: ap-northeast-1  
**依存サービス**: VPC, Gitea, ECS Fargate

## 🔮 今後の改善課題

### 1. Configuration as Code (JCasC) 実装

#### 現状の課題
- Jenkinsの初期設定が手動のため、環境間での設定差異が発生しやすい
- プラグイン設定、ジョブ定義、セキュリティ設定をコード化できていない
- スケーラブルな設定管理が困難

#### 実装予定内容

##### JCasC設定ファイル構造

#### 🚨 現在発生している問題点

##### 1. ディレクトリ存在チェック不備
**問題**: `CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs`を設定したが、ディレクトリが存在しないためJenkinsコンテナが起動失敗

**根本原因**:
- Dockerfileで設定ファイルディレクトリを作成していない
- EFS mount後の権限設定が不適切
- 設定ファイル配置とアクセス権の不整合

**エラーメッセージ例**:
```
SEVERE: Configuration-as-Code plugin failed to load configuration files from /var/jenkins_home/casc_configs
```

##### 2. SecretsManagerとJCasC設定の競合
**問題**: AWS SecretsManagerで管理されている認証情報と、JCasC設定ファイル内のユーザー定義が重複

**影響**:
- JenkinsコンソールからユーザーA追加 → SecretsManagerには反映されない
- SecretsManagerのadmin情報 → JCasC設定と不整合
- 結果的に認証情報の管理が分散し整合性が保てない

##### 3. 環境変数展開の問題
**問題**: JCasC YAML内の`${JENKINS_ADMIN_ID}`等の環境変数が正しく展開されない場合がある

**対策要点**:
- ECSタスク定義での環境変数設定確認
- Jenkins起動時の変数読み込み確認
- デフォルト値の設定

#### 🔧 推奨実装パターン

##### パターン A: フルJCasC + Secrets Manager統合型
```yaml
# /var/jenkins_home/casc_configs/jenkins.yaml
jenkins:
  systemMessage: "Jenkins POC Environment - Managed by JCasC"
  securityRealm:
    local:
      users:
        - id: "${JENKINS_ADMIN_ID:-admin}"
          password: "${JENKINS_ADMIN_PASSWORD}"
          # SecretsManagerから環境変数で注入
  authorizationStrategy:
    globalMatrix:
      permissions:
        - "Overall/Administer:${JENKINS_ADMIN_ID:-admin}"
        - "Overall/Read:authenticated"
        - "Job/Build:authenticated"
        - "Job/Configure:authenticated"
        - "Job/Create:authenticated"
        - "Job/Read:authenticated"

unclassified:
  location:
    url: "${JENKINS_URL}"
  timestamper:
    allPipelines: true
  
tool:
  git:
    installations:
      - name: "Default Git"
        home: "/usr/bin/git"

# マルチファイル分割での管理
# security.yaml, tools.yaml, jobs.yaml等に分離可能
```

**ECSタスク定義（推奨）**:
```yaml
Environment:
  - Name: CASC_JENKINS_CONFIG
    Value: /var/jenkins_home/casc_configs
  - Name: JENKINS_URL
    Value: !Sub 'http://${LoadBalancer.DNSName}'
Secrets:
  - Name: JENKINS_ADMIN_ID
    ValueFrom: !Ref JenkinsAdminSecret
  - Name: JENKINS_ADMIN_PASSWORD
    ValueFrom: !Sub "${JenkinsAdminSecret}:password::"
```

##### パターン B: 軽量JCasC + 手動ユーザー管理型
```yaml
# 最小限の設定のみJCasC化
jenkins:
  systemMessage: "Jenkins POC Environment"
  # ユーザー管理はJenkinsコンソールで実施
  disableRememberMe: false

unclassified:
  location:
    url: "${JENKINS_URL}"
  timestamper:
    allPipelines: true
  
security:
  # セキュリティ設定のみコード化
  globalJobDslSecurityConfiguration:
    useScriptSecurity: true
```

**利点**: 
- JCasC導入リスクを最小化
- ユーザー管理の柔軟性維持
- 段階的な拡張が可能

##### パターン C: ハイブリッド型（POC推奨）
```yaml
# POC環境での現実的なバランス設定
jenkins:
  systemMessage: "Jenkins POC Environment - Hybrid Management"
  # 基本ユーザーのみJCasC化、追加ユーザーは手動
  securityRealm:
    local:
      users:
        - id: "${JENKINS_ADMIN_ID:-admin}"
          password: "${JENKINS_ADMIN_PASSWORD}"
          # 追加ユーザーはJenkinsコンソールから追加
  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false

unclassified:
  location:
    url: "${JENKINS_URL}"
  timestamper:
    allPipelines: true

# ジョブ定義例（今後の拡張用）
jobs:
  - script: >
      pipelineJob('example-pipeline') {
        definition {
          cps {
            script('''
              pipeline {
                agent any
                stages {
                  stage('Hello') {
                    steps {
                      echo 'Hello from JCasC!'
                    }
                  }
                }
              }
            ''')
          }
        }
      }
```

#### 🛠️ 段階的実装戦略

##### Phase 1: 基盤準備（最優先）
1. **ディレクトリ作成の確実化**
```dockerfile
# Dockerfile修正案
USER root
RUN mkdir -p /var/jenkins_home/casc_configs && \
    chown -R jenkins:jenkins /var/jenkins_home/casc_configs
USER jenkins

# 設定ファイル配置
COPY casc_configs/ /var/jenkins_home/casc_configs/
```

2. **EFS権限設定**
```bash
# ECS起動時の権限修正
InitScript:
  - |
    mkdir -p /var/jenkins_home/casc_configs
    chown -R 1000:1000 /var/jenkins_home/casc_configs
```

##### Phase 2: 最小限JCasC導入
- セキュリティ設定のみコード化
- ユーザー管理は引き続き手動
- システムメッセージ、基本設定をJCasC化

##### Phase 3: 認証統合検討
- SecretsManager統合パターンの評価
- 既存ユーザー移行戦略の策定
- バックアップ・リストア手順の確立

#### ⚠️ 実装時の注意点

##### 1. SecretsManager統合時の考慮事項
```yaml
# 現在のSecretsManager構造
{
  "username": "admin",
  "password": ".n}z:`JryTt7,PmE"
}

# JCasC統合時の対応
- 環境変数での値注入を確実に
- パスワードローテーション時の影響確認
- バックアップユーザーの確保
```

##### 2. 既存Jenkins設定の保持
```bash
# 現在の設定バックアップ
# EFS内の設定ファイル退避
aws efs create-backup \
  --resource-arn arn:aws:elasticfilesystem:ap-northeast-1:627642418836:file-system/fs-xxx \
  --region ap-northeast-1

# 手動で作成したユーザー情報の確認
# users.xml, config.xml等の保存
```

##### 3. ロールバック戦略
```yaml
# 緊急時の設定無効化
Environment:
  # - Name: CASC_JENKINS_CONFIG
  #   Value: /var/jenkins_home/casc_configs
  - Name: JAVA_OPTS
    Value: "-Xmx2g -Djenkins.install.runSetupWizard=false -Dio.jenkins.plugins.casc.ConfigurationAsCode.initialDelay=60000"
```

#### 📋 実装前チェックリスト

##### 必須確認項目
- [ ] EFS内のディレクトリ作成権限確認
- [ ] 現在のユーザー設定のバックアップ
- [ ] SecretsManager統合方針の決定
- [ ] ロールバック手順の準備
- [ ] テスト環境での事前検証

##### オプション拡張項目
- [ ] プラグイン設定のコード化
- [ ] ジョブ定義テンプレート準備
- [ ] 環境別設定ファイル分離
- [ ] 設定変更の自動テスト実装

##### Dockerfile修正案
```dockerfile
# CASC設定ファイルをコンテナに埋め込み
COPY casc_configs/ /var/jenkins_home/casc_configs/

# 権限設定
RUN chown -R jenkins:jenkins /var/jenkins_home/casc_configs
```

##### 環境変数の再有効化
```yaml
# ECSタスク定義で追加
Environment:
  - Name: CASC_JENKINS_CONFIG
    Value: /var/jenkins_home/casc_configs
  - Name: JENKINS_URL
    Value: !Sub 'http://${LoadBalancer.DNSName}'
```

#### 実装効果
- **設定の標準化**: 全環境で統一されたJenkins設定
- **バージョン管理**: 設定変更履歴の追跡可能
- **自動化促進**: 手動セットアップ作業の削減
- **災害復旧**: 設定ファイルからの高速復旧

#### 実装スケジュール
1. **Phase 1**: 基本設定のJCasC化（セキュリティ、ユーザー管理）
2. **Phase 2**: プラグイン設定のコード化
3. **Phase 3**: ジョブ定義テンプレートの自動生成
4. **Phase 4**: 環境別設定パラメータ化

### 2. セキュリティ強化

#### API Gateway認証機能
- **実装予定**: API Key認証、IP制限、WAF導入
- **効果**: 不正なWebhook呼び出しの防止

#### シークレット管理の改善
- **実装予定**: AWS Secrets Manager統合拡張
- **効果**: 認証情報のローテーション自動化

### 3. 監視・アラート機能

#### CloudWatch Dashboardの構築
- **実装予定**: ビルド成功率、実行時間、コスト推移の可視化
- **効果**: プロアクティブな運用管理

#### 異常検知アラート
- **実装予定**: ビルド失敗、長時間実行の自動通知
- **効果**: 迅速な問題対応

### 4. マルチ環境対応

#### 環境別パイプライン分離
- **実装予定**: dev/staging/production環境の独立したパイプライン
- **効果**: 本番環境の安定性向上

---

**最終更新**: 2025年10月14日  
**次回レビュー予定**: 2025年11月14日
