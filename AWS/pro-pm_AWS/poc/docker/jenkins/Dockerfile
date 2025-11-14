# Jenkins公式イメージ（最新の安定版を使用）
FROM jenkins/jenkins:lts-almalinux
# 古いバージョン（プラグイン互換性の問題でコメントアウト）
# FROM jenkins/jenkins:2.452-almalinux

# rootユーザーに変更してパッケージインストール
USER root

# システムパッケージの更新（セキュリティ修正含む）
RUN dnf update -y \
    && dnf clean all

# 日本時間設定と基本ツールのインストール
RUN dnf install -y \
    epel-release \
    curl \
    git \
    vim \
    unzip \
    wget \
    python3 \
    python3-pip \
    nodejs \
    npm \
    jq \
    && dnf clean all

# Ansibleのインストール（epel-release経由）
RUN dnf install -y ansible-core \
    && dnf clean all

# Playwrightのインストール（npm経由）
RUN npm install -g playwright@1.40.0

# Docker CLIのインストール（リモートDockerデーモン接続用）
# 注意: FargateではDinD（Docker in Docker）は使用不可
# EC2インスタンス使用時またはリモートDockerデーモン接続時のみ有効
#RUN dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo \
    # && dnf install -y docker-ce-cli-26.1.3-1.el8 \
    # && dnf clean all

# AWS CLI v2 のインストール
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

# Jenkinsプラグインの事前インストール
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt

# jenkinsユーザーに戻す
USER jenkins

# Jenkinsホームとポート設定（デフォルト値）
WORKDIR /var/jenkins_home
EXPOSE 8080 50000
