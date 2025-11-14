# Jenkins カスタムコンテナイメージ 要件定義

## 📋 基本要件

### ベースイメージ
- **指定イメージ**: `jenkins/jenkins:2.452-almalinux`
- **理由**: AlmaLinux ベースで安定性と互換性を重視
- **更新方針**: セキュリティアップデート対応時のみバージョンアップ

## 🛠️ 必須ツール・ライブラリ

### 1. パッケージ管理・基本ツール
- curl, wget, git, vim, unzip
- python3, python3-pip
- nodejs, npm

### 2. 自動化・デプロイメントツール
- **Ansible**: インフラ自動化、設定管理用
  - `ansible-core` 最新安定版
  - よく使われるコレクション (community.general, ansible.posix)
  - Ansibleはepel経由でインストールする pipではインストールしない
- **Playwright**: E2Eテスト、ブラウザ自動化用
  - Python版 Playwright
  - Chrome, Firefox, Safari ブラウザサポート

### 3. コンテナ・クラウドツール  
- **Docker CLI**: Docker in Docker でコンテナビルド
- **AWS CLI v2**: AWS リソース操作用

### 4. 開発・ビルドツール
- **Java**: Jenkins プラグイン開発用（OpenJDK 17）
- **Maven/Gradle**: Javaプロジェクトビルド用
- **jq**: JSON処理用

## 🔌 Jenkins プラグイン要件

### 基本プラグイン
- Pipeline関連 (workflow-aggregator, pipeline-stage-view)
- Git連携 (git, github)
- Gitea連携 (Gitea)
- 認証・権限 (matrix-auth, credentials-binding)
- Docker連携 (docker-workflow, docker-commons)

### AWS連携プラグイン
- aws-credentials: AWS認証情報管理
- pipeline-aws: AWSサービス連携

### 自動化・テスト関連
- build-timeout: ビルドタイムアウト制御
- email-ext: メール通知
- timestamper: タイムスタンプログ
- junit: テスト結果表示

### UI・管理プラグイン
- blueocean: モダンUI
- configuration-as-code: 設定コード化
- job-dsl: ジョブ定義のコード化

## 🐍 Python パッケージ要件

### Ansible エコシステム
```
ansible-core>=2.15.0
ansible-runner
ansible-vault
```

### Playwright テスト
```
playwright>=1.40.0
pytest-playwright
playwright-stealth
```

### AWS/クラウド連携
```
boto3
botocore
awscli
```

### 開発・ユーティリティ
```
requests
pyyaml
jinja2
pytest
black
flake8
```

## 📦 Node.js パッケージ要件

### Playwright JavaScript/TypeScript
```
@playwright/test
playwright
```

### 開発ツール
```
typescript
@types/node
eslint
prettier
```

## 🎯 パフォーマンス要件

### リソース設定
- **メモリ**: 最小 2GB、推奨 4GB
- **CPU**: 最小 1vCPU、推奨 2vCPU  
- **ディスク**: Jenkins HOME 用に 20GB以上

### ビルド時間目標
- **イメージビルド**: 15分以内
- **プラグインインストール**: 5分以内
- **起動時間**: 60秒以内

## 🔒 セキュリティ要件

### 権限管理
- 非root実行 (jenkins ユーザー)
- Docker socket アクセスは最小権限
- 機密情報は環境変数またはSecrets Manager

### ネットワーク
- 必要最小限のポート公開 (8080, 50000)
- HTTPS通信の推奨
- プロキシ環境対応

## 🚀 デプロイ要件

### コンテナレジストリ
- **プライマリ**: Amazon ECR
- **タグ戦略**: semantic versioning (1.0.0, 1.0.1...)
- **latest タグ**: 安定版のみ

### 環境別イメージ
- **dev**: 開発・テスト用（フル機能）
- **prod**: 本番用（フル機能）

### ヘルスチェック
- HTTP GET /login (Jenkins ready確認)
- タイムアウト: 30秒
- リトライ: 3回

## 🧪 テスト要件

### 単体テスト
- Dockerfile linting (hadolint)
- セキュリティスキャン (trivy)
- イメージサイズチェック (< 2GB)

### 統合テスト
- コンテナ起動テスト
- プラグイン動作確認
- Ansible/Playwright実行確認

### E2Eテスト
- Jenkins UI動作確認
- Pipeline実行テスト
- AWS連携テスト

## 📝 設定管理

### Configuration as Code (JCasC)
- jenkins.yaml でデフォルト設定
- プラグイン設定の自動化
- 初期ジョブ/Pipeline定義

### 環境変数
```bash
# Jenkins設定
JENKINS_OPTS=""
JAVA_OPTS="-Xmx2048m"

# Ansible設定  
ANSIBLE_HOST_KEY_CHECKING=False
ANSIBLE_STDOUT_CALLBACK=yaml

# Playwright設定
PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
```

## 🔄 更新・メンテナンス要件

### 定期更新
- **セキュリティパッチ**: 月1回
- **プラグイン更新**: 四半期ごと  
- **ベースイメージ**: 半年ごと

### バックアップ戦略
- Jenkins設定: Git管理
- ジョブ履歴: S3保存
- プラグイン設定: JCasC化

## 📋 受け入れ基準

### 機能要件
- [ ] jenkins/jenkins:2.452-almalinux ベース
- [ ] Ansible コマンド実行可能
- [ ] Playwright テスト実行可能
- [ ] Docker コマンド実行可能
- [ ] AWS CLI 操作可能
- [ ] 全指定プラグインがインストール済み

### 非機能要件  
- [ ] イメージサイズ 2GB以下
- [ ] 起動時間 60秒以内
- [ ] セキュリティスキャン PASS
- [ ] ヘルスチェック正常応答

---

**作成日**: 2025年10月14日  
**更新日**: 2025年10月14日  
**バージョン**: 1.0.0  
**承認者**: -

## 🌐 AWS環境での構成管理要件

### SSM接続によるEC2管理
- **接続方式**: AWS Systems Manager (SSM) Session Manager を利用
  - SSHポート開放・鍵管理不要
  - IAM権限のみで安全に接続可能
- **必要条件**:
  - EC2インスタンスにSSM Agentがインストール済み（Amazon Linux 2は標準搭載）
  - EC2インスタンスにIAMロール `AmazonSSMManagedInstanceCore` を付与

### Ansible設定例
- **インベントリ設定**:
  ```ini
  [ec2]
  i-0abc123def456ghij

  group_vars/ec2.yml:
  ansible_connection: aws_ssm
  ansible_aws_ssm_profile: default
  ```
- **Playbook例**:
  ```yaml
  ---
  - name: EC2構成管理（SSM接続）
    hosts: ec2
    gather_facts: yes
    tasks:
      - name: パッケージインストール
        yum:
          name: httpd
          state: present
      - name: サービス起動
        service:
          name: httpd
          state: started
          enabled: yes
  ```

### IAMロール設計
- **Jenkins（Fargate）用IAMロール**:
  - 必要なポリシー:
    - `AmazonSSMFullAccess`（または必要最小限のSSM権限）
    - `AmazonEC2ReadOnlyAccess`（EC2インスタンス情報取得用）
  - **ポリシーJSON例（最小構成）**:
    ```json
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "ssm:SendCommand",
            "ssm:StartSession",
            "ssm:DescribeInstanceInformation",
            "ssm:GetCommandInvocation",
            "ssm:ListCommands",
            "ssm:ListCommandInvocations",
            "ec2:DescribeInstances",
            "ec2:DescribeTags"
          ],
          "Resource": "*"
        }
      ]
    }
    ```
- **EC2インスタンス用IAMロール**:
  - `AmazonSSMManagedInstanceCore` を割り当て
