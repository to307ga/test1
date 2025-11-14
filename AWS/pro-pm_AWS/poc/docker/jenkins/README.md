# Jenkins カスタムコンテナイメージ

## 概要

このディレクトリには、POC環境で使用するJenkinsのカスタムDockerイメージを作成するためのファイルが含まれています。

## 構成

- **Dockerfile**: Jenkinsカスタムイメージの定義
- **plugins.txt**: 事前インストールするJenkinsプラグイン一覧
- **README.md**: このファイル

## 含まれる機能

### ベースイメージ
- `jenkins/jenkins:lts` - Jenkins公式LTSイメージ

### 追加インストール
- **開発ツール**: git, vim, curl, wget, unzip
- **ランタイム**: Python3, Node.js, npm
- **Docker CLI**: Docker in Docker でコンテナビルドが可能
- **AWS CLI v2**: AWS リソース操作用
- **Jenkinsプラグイン**: 約40個の推奨プラグインを事前インストール

## イメージビルド

### 1. 基本ビルド
```bash
cd /home/tomo/poc/docker/jenkins
docker build -t poc-jenkins:latest .
```

### 2. タグ付きビルド
```bash
# バージョンタグ付き
docker build -t poc-jenkins:1.0.0 -t poc-jenkins:latest .

# ECRレジストリ用タグ
docker build -t 627642418836.dkr.ecr.ap-northeast-1.amazonaws.com/poc-jenkins:latest .
```

## イメージ起動テスト

### ローカルでのテスト実行
```bash
# ポート8080でJenkinsを起動
docker run -d --name jenkins-test -p 8080:8080 -p 50000:50000 poc-jenkins:latest

# 初期管理者パスワード確認
docker exec jenkins-test cat /var/jenkins_home/secrets/initialAdminPassword

# ログ確認
docker logs jenkins-test

# コンテナ停止・削除
docker stop jenkins-test && docker rm jenkins-test
```

### Docker in Docker テスト
```bash
# Dockerソケットをマウントしてテスト
docker run -d --name jenkins-dind \
  -p 8080:8080 -p 50000:50000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v jenkins_home:/var/jenkins_home \
  poc-jenkins:latest

# Docker動作確認
docker exec jenkins-dind docker --version
```

## ECRプッシュ

### 1. ECR認証
```bash
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin 627642418836.dkr.ecr.ap-northeast-1.amazonaws.com
```

### 2. ECRリポジトリ作成（初回のみ）
```bash
aws ecr create-repository --repository-name poc-jenkins --region ap-northeast-1
```

### 3. イメージプッシュ
```bash
docker push 627642418836.dkr.ecr.ap-northeast-1.amazonaws.com/poc-jenkins:latest
```

## カスタマイズ

### プラグイン追加
`plugins.txt` にプラグイン名とバージョンを追加してリビルド

### 追加パッケージインストール
`Dockerfile` のRUN文にパッケージを追加

### 設定ファイル配置
Configuration as Code (JCasC) 設定ファイルを追加可能：
```dockerfile
COPY jenkins.yaml /var/jenkins_home/casc_configs/jenkins.yaml
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs
```

## トラブルシューティング

### ビルドエラー
- プラグインバージョンが古い場合は最新版に更新
- 依存関係エラーが出る場合はプラグインの順序を調整

### 権限エラー  
- Docker in Docker使用時はjenkinユーザーをdockerグループに追加
- ファイル権限の問題は`chown jenkins:jenkins`で解決

### ネットワークエラー
- プロキシ環境の場合は`Dockerfile`にHTTP_PROXY設定を追加

## セキュリティ考慮事項

- 本番環境では最小限の権限で実行
- Docker in DockerよりDocker Outsideを推奨  
- 機密情報はDocker SecretsまたはAWS Secrets Managerを使用
- 定期的なベースイメージアップデート

---

**作成日**: 2025年10月14日  
**対象環境**: POC環境  
**ベースイメージ**: jenkins/jenkins:lts
