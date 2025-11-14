

# ECS Services ドキュメント

## 📑 目次

- [ECS Services ドキュメント](#ecs-services-ドキュメント)
  - [📑 目次](#-目次)
  - [🔧 Gitea](#-gitea)
    - [リポジトリ一覧](#リポジトリ一覧)
      - [jenkins-docker](#jenkins-docker)
      - [test-ansible](#test-ansible)
      - [test-playwright](#test-playwright)
  - [🚀 Jenkins](#-jenkins)
    - [ジョブ一覧](#ジョブ一覧)
      - [test-playwright](#test-playwright-1)
      - [test-ansible](#test-ansible-1)

## 🔧 Gitea

**アクセスURL**: http://localhost:8080/

Giteaには以下の3つのリポジトリがあります。

### リポジトリ一覧

#### jenkins-docker

Jenkins用のDockerfileを管理するリポジトリ

**特徴**:
- **ベースイメージ**: Jenkins公式のAlmaLinux版
- **CI/CDパイプライン**: 
  - pushをトリガーにCodeBuildがイメージを作成
  - ECRへ自動push
  - LintとセキュリティスキャンはCodeBuildのパイプラインで実施（現在設定は甘め）
- **プラグイン**: 
  - Jenkinsに必要なプラグインはインストール済み
  - 初期ログインパスワードは要求されない
  - 既存のJenkinsバックアップからインポートする際はプラグインを除外してください
- **Python環境**: 
  - Fabricは不要のためイメージには含まれていない
  - Python 3系のみをインストール
- **Secrets Manager連携**: 
  - Secrets Managerから`ansible-vault-password`を取得するシェルを配置済み

#### test-ansible

AnsibleをAWS環境へ適応させたリポジトリ

**特徴**:
- **ansible-vault-password**: 
  - AWSのSecrets Managerへ格納済み
  - 既存の暗号化されたファイルはそのまま使用可能
- **実行環境**: 
  - Jenkinsでも実行可能
  - ローカル環境でも実行可能
  - Playbookのサンプル含む
- **セットアップ**: 
  - uvでansibleをインストール
  - このリポジトリをcloneしたら`uv sync`を実行
  - Ansibleがインストールされていない環境が望ましい
  - 詳細は`ansible環境構築手順.md`を参照

#### test-playwright

Playwright実行環境のテストリポジトリ

**特徴**:
- JenkinsコンテナにPlaywrightをインストール
- 動作確認・検証用のサンプルコード

## 🚀 Jenkins

**アクセスURL**: http://localhost:8081/

Jenkinsには以下の3つのジョブがあります。

### ジョブ一覧

#### test-playwright

JenkinsからPlaywrightを実行するジョブ

**特徴**:
- **環境**: 
  - 必要なものは全てイメージ作成時にインストール済み
  - 不足がある場合はDockerfileへ追加してください
  - Jenkinsのジョブ内での追加も可能だが、極力Dockerfileへの追加を推奨
  - DinD（Docker in Docker）も可能だが非推奨なので避けてください
- **レポート機能**: 
  - Playwright HTML Reportプラグインをインストール済み
  - 従来のJUnitとPlaywright両方のレポート形式をサポート
  - Jenkinsfileで両方のレポートを作成
- **レポートの種類**:
  - **JUnit**: 
    - 「最新のテスト結果」タブリンク
    - テスト統計・トレンドグラフ
    - xUnit等ほとんどのテストツールがサポート
    - 汎用性が高い
  - **Playwright HTML**: 
    - 「Playwright HTML Report」リンク
    - スクリーンショット付き
    - 詳細デバッグ情報
    - Playwright特化型

#### test-ansible

JenkinsからAnsibleを実行するジョブ

**特徴**:
- Giteaリポジトリからplaybookを取得して実行
- AWS環境への設定変更を自動化
