# Jenkins Docker Environment for AWS + Ansible

Jenkins CI/CDサーバーのDockerイメージとAWS ECS Fargate上での運用環境一式

## 概要

本プロジェクトは、AWS環境でのAnsible自動化を目的としたJenkinsサーバーの構築・運用を提供します。
plugins.txtを使ってJenkinsプラグインを事前インストールするため、Jenkins初回起動時の初期パスワード入力は不要です。

## ディレクトリ構成

```
jenkins-docker/
├── README.md                    # このファイル
├── AnsibleVaultOnJenkins.md    # Ansible Vault設定ガイド
├── buildspec.yml                # CodeBuild設定（GiteaとS3で管理）
└── jenkins/                    # Docker関連ファイル
    ├── Dockerfile              # Jenkinsイメージ定義
    ├── plugins.txt             # プラグイン一覧
    ├── ansible.cfg             # Ansible設定
    ├── vault-password-aws.sh   # Vaultパスワード取得
    └── .dockerignore           # ビルド除外設定
```

**Gitリポジトリ情報:**
- **リポジトリ**: `tomo/jenkins-docker`
- **Giteaホスト**: `internal-poc-poc-ecs-gitea-alb-1227977924.ap-northeast-1.elb.amazonaws.com`
- **デフォルトブランチ**: `main`
- **アクセス**: パブリックリポジトリ（認証不要）

## 含まれる機能

### ベースイメージ
- `jenkins/jenkins:lts-almalinux` - Jenkins公式almalinux版LTSイメージ

### 主要コンポーネント

#### Jenkinsイメージの特徴
- **Base**: `jenkins/jenkins:lts-almalinux`
- **Ansible**: Core + AWS Collections（EPEL版）
- **AWS CLI**: v2.x（最新版）
- **Session Manager**: EC2接続用プラグイン
- **プラグイン**: AWS + Ansible最適化済み

#### AWS統合機能
- **ECS Fargate**: サーバーレスコンテナ実行
- **EFS**: 永続化ストレージ（Jenkins Home）
- **ALB**: ロードバランサー（内部アクセス）
- **Secrets Manager**: Vault パスワード管理
- **SSM**: EC2セッション管理

## クイックスタート

### 1. Dockerイメージのビルド

```bash
# jenkins ディレクトリでビルド
cd jenkins/
docker build -t jenkins-aws-ansible:latest .
```

### 2. ローカル実行（テスト用）

```bash
# ローカルでのテスト実行
docker run -d \
  --name jenkins-test \
  -p 8080:8080 \
  -e AWS_ACCESS_KEY_ID=your-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret \
  jenkins-aws-ansible:latest
```

### 3. AWS ECS Fargateでのデプロイ

```bash
# CloudFormationでのデプロイ
cd ../AWS_POC/poc/sceptre/
sceptre launch poc/ecs-jenkins.yaml
```

## CI/CD パイプライン（CodeBuild）

### buildspec.ymlの管理方式

`buildspec.yml`は**GiteaとS3の両方に保存**されています。これには以下の理由があります：

#### 2つの保存場所とその理由

1. **Gitea（このリポジトリ）**: `jenkins-docker/buildspec.yml`
   - **目的**: バージョン管理と変更履歴の追跡
   - **役割**: マスターコピーとして機能
   - **利点**: 
     - 変更履歴が追跡可能
     - コードレビューが可能
     - ロールバックが容易
   
2. **S3**: `s3://poc-codebuild-buildspecs-910230630316/jenkins-docker/buildspec.yml`
   - **目的**: CodeBuildの実際のビルド実行
   - **役割**: CodeBuildのSource設定として使用
   - **利点**:
     - CloudFormation SourceタイプをS3に設定することで、buildspec.ymlを外部管理可能
     - CloudFormationテンプレート内に埋め込む必要がない（`$$`エスケープ不要）
     - buildspec.ymlの変更時にCloudFormationスタックの更新が不要

#### buildspec.ymlの更新手順

1. **このファイル（buildspec.yml）を編集**
   ```bash
   cd /home/t-tomonaga/AWS/AWS_POC/jenkins-docker
   vi buildspec.yml
   
   # 注意: 1行の最大文字数は78文字まで
   # これを超えるとCodeBuildでエラーになります
   ```

2. **変更をGiteaにコミット・プッシュ**
   ```bash
   git add buildspec.yml
   git commit -m "Update buildspec configuration"
   git push origin main
   ```

3. **S3にアップロード**
   ```bash
   aws s3 cp buildspec.yml \
     s3://poc-codebuild-buildspecs-910230630316/jenkins-docker/buildspec.yml \
     --region ap-northeast-1
   ```

4. **ビルドを開始**
   ```bash
   aws codebuild start-build \
     --project-name poc-jenkins-docker-build \
     --region ap-northeast-1
   ```

#### ビルド機能

**フェーズ構成:**
- **INSTALL**: Hadolint + Trivy のインストール
- **PRE_BUILD**: Giteaからリポジトリをクローン → Hadolintでlinting → ECRログイン
- **BUILD**: Dockerイメージビルド → Trivyセキュリティスキャン
- **POST_BUILD**: マルチタグでECRにプッシュ

**主要機能:**
- **Giteaからのクローン**: 
  - URL: `http://internal-poc-poc-ecs-gitea-alb-*.elb.amazonaws.com`
  - ポート: 80 (HTTP)
  - 認証: なし（パブリックリポジトリ）
  - リポジトリ: `tomo/jenkins-docker`
  
- **Dockerfile Linting (Hadolint)**:
  - バージョン: v2.12.0
  - 厳密モード: WARNING レベルでも失敗
  - 無視ルール: DL3041（パッケージバージョン指定）, DL3059（連続RUN統合）
  - CloudFormationパラメータで動的設定可能
  
- **セキュリティスキャン (Trivy)**:
  - Severity Threshold: CRITICAL（CloudFormationパラメータで動的設定可能）
  - 実行モード: 警告のみ（`--exit-code 0`）
  - 検出された脆弱性があってもビルドは継続
  
- **マルチタグプッシュ**:
  - `latest`: 最新ビルド
  - `no-git`: IMAGE_TAG（git情報なし環境用）
  - `<commit-hash>`: 7文字のコミットハッシュ
  - `YYYYMMDD-HHMMSS`: ビルド日時
  - `YYYYMMDD-HHMMSS-<commit-hash>`: 日時+コミット

#### 主要な修正履歴

**2025年11月7日の修正:**
1. ✅ Giteaクローン設定（ポート3000→80, GITEA_USERNAME修正: jenkins-ci→tomo）
2. ✅ Jenkins plugins.txt修正（5つの廃止/存在しないプラグインを削除・修正）
3. ✅ Trivy設定変更（severity: HIGH→CRITICAL, exit-code: 1→0）
4. ✅ Dockerfile DL3040修正（`dnf clean all` 追加）
5. ✅ Hadolint無視ルール更新（DL3008→DL3041, DL3059）
6. ✅ Hadolint厳密モード有効化（`--failure-threshold error` 削除）

**最新のビルド結果:**
- Build #44: 全フェーズ成功（厳密モードでの初回成功）
- 検出された警告: なし（無視ルール以外）
- 脆弱性: CRITICAL 2件検出（警告のみ、ビルド継続）



## 設定ガイド

### Ansible Vault設定
詳細は [AnsibleVaultOnJenkins.md](./AnsibleVaultOnJenkins.md) を参照してください。

### 環境変数
| 変数名 | 説明 | デフォルト値 |
|--------|------|-------------|
| `AWS_VAULT_SECRET_NAME` | Secrets ManagerのSecret名 | - |
| `AWS_REGION` | AWSリージョン | `ap-northeast-1` |
| `AWS_VAULT_KEY` | SecretのJSONキー名 | `password` |

### プラグイン管理

`jenkins/plugins.txt` でプラグインを管理。

#### プラグイン仕様の書き方

```txt
# バージョン指定あり（推奨）
workflow-aggregator:596.v8c21c963d92d
git:5.2.2

# バージョン指定なし（LTS互換の最新版を自動取得）
aws-java-sdk-minimal
extended-choice-parameter
```

#### 重要な注意事項

1. **jenkins-plugin-cliが自動的に依存関係を解決**
   - 指定したプラグインの依存プラグインは自動インストールされます
   - バージョン指定がない場合、Jenkins LTS互換の最新版が選択されます

2. **廃止されたプラグインに注意**
   - `aws-systems-manager`: プラグインが存在しません（削除済み）
   - `ansible-plugin`: プラグインが存在しません（削除済み）
   - `aws-java-sdk-s3`: 廃止されました（削除済み）
   - `aws-java-sdk2-*`: 存在しないプラグインシリーズ（削除済み）

3. **プラグイン追加時のベストプラクティス**
   - まずバージョンなしで試す（LTS互換性が高い）
   - エラーが出たら特定バージョンを指定
   - https://updates.jenkins.io/download/plugins/ で存在確認

#### 最近の修正内容（2025年11月7日）

以下の問題プラグインを削除・修正：
- ❌ `aws-systems-manager:7.0.0` → 削除（プラグインが存在しない）
- ❌ `ansible-plugin:410.v31b_0a_b_0f6814` → 削除（プラグインが存在しない）
- ❌ `aws-java-sdk-s3` → 削除（廃止されたプラグイン）
- ❌ `aws-java-sdk2-*` → 削除（存在しないシリーズ）
- ✅ `extended-choice-parameter` → バージョン指定削除（LTS互換モード）
- ✅ `junit-attachments` → バージョン指定削除（LTS互換モード）

### カスタマイズ

#### プラグイン追加
`jenkins/plugins.txt` にプラグイン名とバージョンを追加してリビルド

#### 追加パッケージインストール
`jenkins/Dockerfile` のRUN文にパッケージを追加

## トラブルシューティング

### CodeBuildエラー

#### git cloneタイムアウト
**症状**: `fatal: unable to access 'http://...': Failed to connect to ... port 3000: Connection timed out`

**原因**: 
- Giteaへの接続にポート3000を使用しようとしている
- Security Groupでポート3000が許可されていない、または不要

**解決策**:
```bash
# buildspec.yml でポート80（HTTP）を使用
REPO_URL=http://$GITEA_LOAD_BALANCER_DNS  # ポート番号なし
```

#### git認証エラー
**症状**: `could not read Username for 'http://...': No such device or address`

**原因**: 
- 非対話環境でgitが認証情報を要求
- パブリックリポジトリなのに認証が試行される

**解決策**:
```bash
# buildspec.yml で認証プロンプトを無効化
export GIT_TERMINAL_PROMPT=0
git clone $REPO_URL/$REPO_PATH /tmp/repo
```

#### Jenkinsプラグインインストールエラー
**症状**: `Failed to download plugin: http code 404`

**原因**:
- プラグインが存在しない、または廃止されている
- プラグインバージョンが誤っている

**解決策**:
1. プラグインの存在確認:
   ```bash
   curl -I https://updates.jenkins.io/download/plugins/<plugin-name>/
   ```

2. `jenkins/plugins.txt`から削除または修正:
   ```txt
   # 存在しないプラグインは削除
   # aws-systems-manager:7.0.0  ← コメントアウトまたは削除
   
   # バージョン指定を削除してLTS互換版を使用
   extended-choice-parameter
   ```

3. 変更をコミット・プッシュしてリビルド

#### Hadolint警告エラー
**症状**: `Dockerfile linting failed` または `DL3040`, `DL3041` などの警告

**原因**:
- Hadolintが厳密モードで警告を検出
- パッケージマネージャのクリーンアップ不足など

**解決策**:

1. **警告を修正する（推奨）**:
   ```dockerfile
   # DL3040: dnf clean allが不足
   RUN dnf install -y package \
       && dnf clean all  # ← 追加
   ```

2. **警告を無視する**:
   ```yaml
   # CloudFormation: poc/sceptre/config/poc/codebuild-jenkins.yaml
   HadolintIgnoredRules:
     - DL3041  # パッケージバージョン指定なし
     - DL3059  # 複数の連続したRUN
   ```

#### Trivyセキュリティスキャンエラー
**症状**: `CRITICAL vulnerability found`, ビルドが失敗

**原因**:
- イメージに重大な脆弱性が検出された
- Trivyがexit-code 1で終了してビルドが失敗

**解決策**:

1. **警告のみモードに変更（現在の設定）**:
   ```yaml
   # buildspec.yml
   OPT="--exit-code 0 --no-progress"
   trivy image $OPT --severity $TRIVY_SEVERITY_THRESHOLD $IMG
   ```

2. **Severity閾値を調整**:
   ```yaml
   # CloudFormation: poc/sceptre/config/poc/codebuild-jenkins.yaml
   TrivySeverityThreshold: CRITICAL  # HIGH, MEDIUM, LOWから選択
   ```

3. **脆弱性を修正する（根本対策）**:
   - ベースイメージを更新
   - パッケージを最新版にアップデート

### ビルド全般のエラー

#### buildspec.yml行の長さエラー
**症状**: CodeBuildでエラー（特定のエラーメッセージなし、単に失敗）

**原因**: buildspec.ymlの1行が78文字を超えている

**解決策**:
```yaml
# 長い行を分割
- URL=https://github.com/hadolint/hadolint/releases
- HADOLINT_URL=$URL/download/v2.12.0/hadolint-Linux-x86_64
```

### ネットワークエラー
- プロキシ環境の場合は`Dockerfile`にHTTP_PROXY設定を追加

### 権限エラー  
- Docker in Docker使用時はjenkinユーザーをdockerグループに追加
- ファイル権限の問題は`chown jenkins:jenkins`で解決

## セキュリティ考慮事項

- 本番環境では最小限の権限で実行
- Docker in DockerよりDocker Outsideを推奨  
- 機密情報はDocker SecretsまたはAWS Secrets Managerを使用
- 定期的なベースイメージアップデート

---

**作成日**: 2025年10月14日  
**対象環境**: POC環境  
**ベースイメージ**: jenkins/jenkins:lts-almalinux

# テスト：改善された世代管理
# テスト：YAML修正
