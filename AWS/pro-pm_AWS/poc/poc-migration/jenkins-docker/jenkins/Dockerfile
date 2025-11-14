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
    jq \
    && dnf clean all

# Node.js 18.x のインストール（Playwright 1.40.0 はNode.js 16以上が必要）
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://rpm.nodesource.com/setup_18.x | bash - \
    && dnf install -y nodejs \
    && node --version \
    && npm --version \
    && dnf clean all

# Python 3.13.1のインストール（ソースからビルド）
RUN dnf install -y \
    gcc \
    make \
    openssl-devel \
    bzip2-devel \
    libffi-devel \
    zlib-devel \
    xz-devel \
    && dnf clean all

WORKDIR /tmp
RUN curl -O https://www.python.org/ftp/python/3.13.1/Python-3.13.1.tgz \
    && tar -xzf Python-3.13.1.tgz

WORKDIR /tmp/Python-3.13.1
RUN ./configure --enable-optimizations --prefix=/usr/local \
    && make "-j$(nproc)" \
    && make altinstall

WORKDIR /
RUN rm -rf /tmp/Python-3.13.1 /tmp/Python-3.13.1.tgz

# boto3とbotocoreを最新版にアップグレード（Ansible Collections要件を満たすため）
# Python 3.13にインストール
RUN /usr/local/bin/python3.13 -m pip install --no-cache-dir --upgrade pip && \
    /usr/local/bin/python3.13 -m pip install --no-cache-dir --upgrade boto3 botocore

# Ansible-coreをPython 3.13にインストール
RUN /usr/local/bin/python3.13 -m pip install --no-cache-dir ansible-core

# Ansible用追加パッケージのインストール
# - python3-requests: HTTP リクエスト処理
# - sshpass: SSH パスワード認証用（通常はキーベース認証推奨）
RUN dnf install -y \
    python3-requests \
    sshpass \
    && dnf clean all

# Ansibleがディスカバリープラグインでもpython3.13を使用するように環境変数を設定
ENV ANSIBLE_PYTHON_INTERPRETER=/usr/local/bin/python3.13

# Ansible Collection の確認
# EPEL版ansible-coreには以下のコレクションが既に含まれている：
# - amazon.aws (7.2.0): EC2、VPC、IAM等のAWSリソース管理
# - community.aws (7.1.0): 追加のAWSモジュール群  
# - ansible.posix (1.5.4): POSIX系OS操作（systemd、cron等）
# - community.general (8.3.0): 汎用的なモジュール群
# 
# 実際にはEPEL版にはコレクションが含まれていないため、手動インストールが必要
# jenkinsユーザーでインストールするため、後続のUSER jenkins後に実行

# Ansible設定ファイルの配置
# - SSM接続用の設定
# - 動的インベントリ用の設定
# - Vault Password取得スクリプト（AWS Secrets Manager用）
RUN mkdir -p /etc/ansible
COPY ansible.cfg /etc/ansible/ansible.cfg
COPY vault-password-aws.sh /usr/local/bin/vault-password-aws.sh
RUN chmod +x /usr/local/bin/vault-password-aws.sh

# 日本語フォントのインストール（文字化け対策）
RUN dnf install -y \
    google-noto-sans-cjk-ttc-fonts \
    google-noto-serif-cjk-ttc-fonts \
    && dnf clean all

# Playwrightのインストール（npm経由）
RUN npm install -g playwright@1.40.0

# Playwrightブラウザのインストール（chromium, firefoxのみ）
# 注意: webkitはAlmaLinux 8で依存関係が複雑なため除外
# 注意: --with-depsはAlmaLinuxで動作しないため、依存関係は手動インストール済み
# 重要: /var/jenkins_homeはEFSマウントされるため、ブラウザは/opt配下にインストール
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
RUN mkdir -p $PLAYWRIGHT_BROWSERS_PATH \
    && playwright install chromium firefox \
    && ls -la $PLAYWRIGHT_BROWSERS_PATH

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

# AWS Session Manager プラグインのインストール
# - EC2インスタンスへのSSM Session Manager経由でのアクセス用
# - 'aws ssm start-session' コマンドでセッション開始可能
RUN curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm" \
    && dnf install -y session-manager-plugin.rpm \
    && dnf clean all \
    && rm -f session-manager-plugin.rpm

    # Playwrightシステム依存関係のインストール（全ブラウザ対応）
RUN dnf install -y \
    nss \
    nspr \
    atk \
    at-spi2-atk \
    cups-libs \
    libdrm \
    libxcb \
    at-spi2-core \
    libX11 \
    libXcomposite \
    libXcursor \
    libXdamage \
    libXext \
    libXfixes \
    libXi \
    libXrandr \
    libXScrnSaver \
    libXtst \
    mesa-libgbm \
    pango \
    cairo \
    alsa-lib \
    gtk3 \
    xorg-x11-fonts-75dpi \
    xorg-x11-fonts-misc \
    xorg-x11-fonts-Type1 \
    xorg-x11-utils \
    dbus-glib \
    libgbm \
    libnotify \
    && dnf clean all

# Jenkinsプラグインの事前インストール
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt

# Configuration as Code (JCasC) 設定ファイルの配置
# 既存Jenkinsのバックアップからリストアするので不要
# CloudFormationテンプレートで CASC_JENKINS_CONFIG を無効化しているので以下を有効にしても動かない
# - Jenkins初期設定の自動化
# - セキュリティ設定、ユーザー管理、システム設定等を含む
# 注意: 既存のcasc_configs/jenkins.yamlを上書きします
# COPY jenkins.yaml /var/jenkins_home/casc_configs/jenkins.yaml
# ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs
# JCasC設定ディレクトリの権限設定
# RUN chown -R jenkins:jenkins /var/jenkins_home/casc_configs

# Ansible Collections のインストール（rootユーザーでsystem-wideインストール）
# amazon.aws と community.aws を /usr/share/ansible/collections にインストール
RUN ansible-galaxy collection install amazon.aws community.aws -p /usr/share/ansible/collections

# jenkinsユーザーに戻す
USER jenkins

# Jenkinsホームとポート設定（デフォルト値）
WORKDIR /var/jenkins_home
EXPOSE 8080 50000
