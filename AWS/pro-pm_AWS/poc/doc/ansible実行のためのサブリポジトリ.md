# Ansible実行のためのサブリポジトリ管理

## 📋 目次
- [現在の状況](#現在の状況)
- [問題点の整理](#問題点の整理)
- [解決策の選択肢](#解決策の選択肢)
- [推奨アプローチ](#推奨アプローチ)
- [ansible.cfg の整理](#ansiblecfg-の整理)
- [Ansible実行方法](#ansible実行方法)
- [トラブルシューティング](#トラブルシューティング)

## 現在の状況

### ディレクトリ構成
```
/home/tomo/
├── poc/                           # メインプロジェクト（Sceptre等）
│   ├── pyproject.toml             # uv管理（ansible, boto3含む）
│   ├── .venv/                     # uv仮想環境
│   ├── .gitignore                 # ansible-playbooks/ を除外
│   └── ansible-playbooks/         # 実ディレクトリ（.gitignoreで除外済み）
│       ├── ansible.cfg
│       ├── inventory/
│       │   └── aws_ec2.yml
│       ├── group_vars/
│       │   └── all.yml
│       └── *.yml (playbooks)
│
└── ansible-playbooks/             # 元のリポジトリ（ローカルのみ）
    ├── .git/
    └── (上記と同じ内容)
```

### pyproject.toml の依存関係
```toml
dependencies = [
    "ansible>=12.1.0",
    "boto3>=1.40.21",
    "cfn-lint>=1.39.1",
    "click>=8.2.1",
    "pyyaml>=6.0.2",
    "sceptre>=4.5.3",
]
```

### .gitignore の内容
```
venv/
.venv/
ansible-playbooks/
```

## 問題点の整理

### 1. 当初の問題: boto3インポートエラー
**エラー内容:**
```
Failed to import the required Python library (botocore and boto3) on gitea's Python /usr/bin/python3.12
```

**原因:**
- Ansibleの動的インベントリプラグイン（`aws_ec2.yml`）がシステムPythonを使用
- uv仮想環境のboto3が見つからない

**解決方法:**
- `uv run ansible`を使うことで、uv仮想環境のPythonとboto3を使用
- リモートホスト（EC2）用には`ansible_python_interpreter: /usr/bin/python3`を明示

### 2. シンボリックリンクの問題
**問題:**
- `/home/tomo/poc/ansible-playbooks` がシンボリックリンクの場合
- `uv run`が`pyproject.toml`を正しく見つけられない

**解決方法:**
- シンボリックリンクを削除し、実ディレクトリをコピー
- `.gitignore`で`ansible-playbooks/`を除外

### 3. リポジトリ管理の問題
**現状:**
- ansible-playbooksは別リポジトリとして管理したい
- しかし、手動コピーは同期が面倒

**課題:**
- git submoduleを使うべきか？
- 現在はリモートリポジトリが存在しない（ローカルのみ）

## 解決策の選択肢

### オプション1: 現状維持（シンプル）

**構成:**
```
/home/tomo/poc/
└── ansible-playbooks/  # 実ディレクトリ（.gitignoreで除外）

/home/tomo/ansible-playbooks/  # 別リポジトリ（ローカル）
```

**メリット:**
- ✅ シンプル
- ✅ `uv run ansible`が正常に動作
- ✅ すぐに使える

**デメリット:**
- ❌ 変更の同期が手動
- ❌ バージョン管理が曖昧

**同期方法:**
```bash
# ansible-playbooksで変更後
cd /home/tomo/ansible-playbooks
git add .
git commit -m "変更内容"

# pocプロジェクトに反映
cp -r /home/tomo/ansible-playbooks/* /home/tomo/poc/ansible-playbooks/
```

### オプション2: Git Submodule（推奨・要リモートリポジトリ）

**前提条件:**
- ansible-playbooksをGitea等のリモートリポジトリにpush済み

**構成:**
```
/home/tomo/poc/
├── .gitmodules                    # submodule設定
└── ansible-playbooks/             # submodule（git管理）
```

**メリット:**
- ✅ バージョン管理が明確
- ✅ 自動同期可能（`git submodule update`）
- ✅ 変更履歴の追跡が容易
- ✅ pocリポジトリから特定バージョンを参照可能

**デメリット:**
- ❌ リモートリポジトリが必要
- ❌ submoduleの操作が少し複雑

**セットアップ手順:**
```bash
# 1. Giteaでansible-playbooksリポジトリを作成
GITEA_URL=$(aws cloudformation describe-stacks --stack-name poc-poc-ecs-gitea \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' --output text)
echo "Gitea URL: http://${GITEA_URL}"

# ブラウザでGiteaにアクセスし、ansible-playbooksリポジトリを作成

# 2. 元のリポジトリをリモートにpush
cd /home/tomo/ansible-playbooks
git remote add origin http://${GITEA_URL}/tomo/ansible-playbooks.git
git push -u origin main

# 3. pocプロジェクトで既存ディレクトリを削除
cd /home/tomo/poc
rm -rf ansible-playbooks

# 4. .gitignoreから削除（submoduleは追跡する）
sed -i '/ansible-playbooks\//d' .gitignore

# 5. submoduleとして追加
git submodule add http://${GITEA_URL}/tomo/ansible-playbooks.git ansible-playbooks
git submodule init

# 6. コミット
git add .gitmodules .gitignore ansible-playbooks
git commit -m "Add ansible-playbooks as submodule"
```

**日常の使い方:**
```bash
# === submoduleの初期化（clone後など）===
cd /home/tomo/poc
git submodule update --init --recursive

# === submoduleを最新化 ===
cd /home/tomo/poc
git submodule update --remote ansible-playbooks

# === submodule内で変更 ===
cd /home/tomo/poc/ansible-playbooks
# ファイルを編集...
git add .
git commit -m "変更内容"
git push origin main

# === 親リポジトリで参照を更新 ===
cd /home/tomo/poc
git add ansible-playbooks
git commit -m "Update ansible-playbooks submodule to latest"
git push

# === 特定のブランチを追跡 ===
cd /home/tomo/poc
git config -f .gitmodules submodule.ansible-playbooks.branch main
git submodule update --remote
```

### オプション3: モノレポ（非推奨）

ansible-playbooksをpocリポジトリに統合して、別リポジトリとしての管理をやめる。

**デメリット:**
- ❌ 別プロジェクトとして管理できない
- ❌ 要件に合わない

## 推奨アプローチ

### フェーズ1: 現状維持で進める（今すぐ）
1. 現在の構成（実ディレクトリ + .gitignore除外）を継続
2. Ansible Playbookの開発・実行を進める
3. 手動同期で対応

### フェーズ2: Git Submodule化（安定後）
1. ansible-playbooksの開発がある程度落ち着いたら
2. Giteaにリモートリポジトリを作成
3. Git Submoduleに移行

**理由:**
- まずは動作確認・開発を優先
- Git Submoduleは後からでも移行可能
- リモートリポジトリの準備が必要

## ansible.cfg の整理

### 現在の ansible.cfg

場所: `/home/tomo/poc/ansible-playbooks/ansible.cfg`

```ini
[defaults]
inventory = inventory/aws_ec2.yml
host_key_checking = False
deprecation_warnings = False
interpreter_python = auto_silent
# tagsはEC2メタデータから自動取得される変数なので警告を抑制
invalid_reserved_variable_names = []

[inventory]
enable_plugins = amazon.aws.aws_ec2

[ssh_connection]
pipelining = True
```

### 設定の意味

#### [defaults] セクション
- `inventory = inventory/aws_ec2.yml`
  - デフォルトインベントリとしてAWS EC2動的インベントリを使用
  - `-i`オプションを省略可能
  
- `host_key_checking = False`
  - SSH接続時のホストキー確認を無効化
  - SSM接続では不要だが、設定があっても害はない
  
- `deprecation_warnings = False`
  - 非推奨警告を抑制
  - **問題**: まだ警告が表示される（要確認）
  
- `interpreter_python = auto_silent`
  - リモートホストのPythonを自動検出
  - **重要**: group_vars/all.ymlで`ansible_python_interpreter: /usr/bin/python3`を明示しているため、実際にはそちらが優先される
  
- `invalid_reserved_variable_names = []`
  - 予約変数名警告を抑制
  - `tags`変数の警告を抑制するため

#### [inventory] セクション
- `enable_plugins = amazon.aws.aws_ec2`
  - AWS EC2動的インベントリプラグインを有効化

#### [ssh_connection] セクション
- `pipelining = True`
  - Ansible接続の高速化
  - SSM接続では効果が限定的

### 設定の問題点と改善案

#### 問題1: deprecation_warningsが効いていない
**現状:**
```
[WARNING]: Deprecation warnings can be disabled by setting `deprecation_warnings=False` in ansible.cfg.
[DEPRECATION WARNING]: Passing `disable_lookups` to `template` is deprecated.
```

**原因:**
- Ansibleのバージョンによっては設定が無視される
- または設定名が間違っている可能性

**改善案:**
```ini
[defaults]
deprecation_warnings = False
# または
ANSIBLE_DEPRECATION_WARNINGS = False  # 環境変数で設定
```

#### 問題2: interpreter_pythonの設定が冗長
**現状:**
- `ansible.cfg`で`interpreter_python = auto_silent`
- `group_vars/all.yml`で`ansible_python_interpreter: /usr/bin/python3`

**改善案:**
`ansible.cfg`から削除して、`group_vars/all.yml`に一本化
```ini
[defaults]
inventory = inventory/aws_ec2.yml
host_key_checking = False
deprecation_warnings = False
invalid_reserved_variable_names = []
# interpreter_python = auto_silent  # 削除（group_varsで管理）
```

#### 問題3: tagsの予約変数警告
**現状:**
```
[WARNING]: Found variable using reserved name 'tags'.
```

**原因:**
- AWS EC2動的インベントリが`tags`という変数を作成
- Ansibleの予約語と衝突

**改善案:**
`inventory/aws_ec2.yml`で変数名を上書き:
```yaml
compose:
  ansible_host: instance_id
  availability_zone: tags.AvailabilityZone
  instance_id: instance_id
  ec2_tag_name: tags.Name
  ec2_tag_environment: tags.Environment
  ec2_tag_application: tags.Application
  tags: {}  # 既に設定済み：空のdictで上書きして警告を抑制
```

### 推奨ansible.cfg（クリーンアップ版）

```ini
[defaults]
inventory = inventory/aws_ec2.yml
host_key_checking = False
deprecation_warnings = False
# Pythonインタプリタはgroup_vars/all.ymlで管理
invalid_reserved_variable_names = []

[inventory]
enable_plugins = amazon.aws.aws_ec2

[ssh_connection]
pipelining = True
```

## group_vars/all.yml の確認

場所: `/home/tomo/poc/ansible-playbooks/group_vars/all.yml`

```yaml
---
# Common variables for all hosts

# Environment settings
env_name: "poc"
project_code: "poc"

# Application user settings
app_user: "apache"
app_group: "apache"
app_directory: "/var/www/html"

# System settings
timezone: "Asia/Tokyo"
locale: "en_US.UTF-8"

# SSM Connection settings (SSH not used)
ansible_connection: aws_ssm
ansible_aws_ssm_bucket_name: "poc-logs-627642418836-ap-northeast-1"
ansible_aws_ssm_region: "ap-northeast-1"

# Python interpreter for remote hosts (EC2 instances)
ansible_python_interpreter: /usr/bin/python3

# Monitoring settings
cloudwatch_namespace: "POC/Custom"
cloudwatch_log_group: "/aws/ec2/poc"

# Security settings (SSH disabled for SSM-only access)
firewall_enabled: true
ssh_enabled: false

# Package repositories
epel_enabled: true

# Performance tuning
max_parallel_tasks: 10
```

### 重要な設定項目

1. **SSM接続設定**
   - `ansible_connection: aws_ssm` - SSM Session Manager経由で接続
   - `ansible_aws_ssm_bucket_name` - ファイル転送用S3バケット
   - `ansible_aws_ssm_region` - AWSリージョン

2. **Pythonインタプリタ**
   - `ansible_python_interpreter: /usr/bin/python3` - リモートホスト用Python

この設定により、ローカル（Ansibleコントローラー）とリモート（EC2）でPythonを分離：
- **ローカル**: uv仮想環境のPython（boto3含む）
- **リモート**: `/usr/bin/python3`（EC2のシステムPython）

## Ansible実行方法

### 基本コマンド

```bash
# pingテスト
cd /home/tomo/poc/ansible-playbooks
uv run ansible -i inventory/aws_ec2.yml poc_web -m ping

# デフォルトインベントリを使用（ansible.cfgに設定済み）
cd /home/tomo/poc/ansible-playbooks
uv run ansible poc_web -m ping

# Playbook実行
cd /home/tomo/poc/ansible-playbooks
uv run ansible-playbook setup-laravel-environment.yml

# 特定のホストグループに対して
uv run ansible az_ap_northeast_1a -m shell -a "hostname"

# 全ホスト確認
uv run ansible all -m ping

# インベントリ確認
uv run ansible-inventory --list
uv run ansible-inventory --graph
```

### エイリアス設定（オプション）

`~/.bashrc`に追加：
```bash
# Ansible実行用エイリアス
alias ansible-poc='cd /home/tomo/poc/ansible-playbooks && uv run ansible'
alias ansible-playbook-poc='cd /home/tomo/poc/ansible-playbooks && uv run ansible-playbook'
alias ansible-inventory-poc='cd /home/tomo/poc/ansible-playbooks && uv run ansible-inventory'

# 使用例
# ansible-poc poc_web -m ping
# ansible-playbook-poc setup-laravel-environment.yml
```

エイリアス反映：
```bash
source ~/.bashrc
```

## トラブルシューティング

### 1. boto3インポートエラー

**エラー:**
```
Failed to import the required Python library (botocore and boto3)
```

**原因:**
- システムPythonを使用している
- uv環境のboto3が見つからない

**解決策:**
```bash
# uv runで実行
cd /home/tomo/poc/ansible-playbooks
uv run ansible -i inventory/aws_ec2.yml poc_web -m ping

# 仮想環境の確認
cd /home/tomo/poc
uv run which python
uv run python -c "import boto3; print(boto3.__file__)"
```

### 2. SSH接続エラー（SSM接続されない）

**エラー:**
```
Failed to connect to the host via ssh: ssh: Could not resolve hostname i-xxx
```

**原因:**
- `ansible.cfg`が読み込まれていない
- SSM接続設定が適用されていない

**解決策:**
```bash
# ansible.cfgのあるディレクトリから実行
cd /home/tomo/poc/ansible-playbooks
uv run ansible poc_web -m ping

# 設定確認
uv run ansible-config dump | grep -i connection
uv run ansible-inventory --list | grep ansible_connection
```

### 3. tagsの予約変数警告

**警告:**
```
[WARNING]: Found variable using reserved name 'tags'.
```

**原因:**
- AWS EC2動的インベントリが`tags`変数を作成
- Ansibleの予約語と衝突

**解決策:**
`inventory/aws_ec2.yml`で既に対応済み（`tags: {}`で上書き）

### 4. Session Manager Pluginエラー

**エラー:**
```
SessionManagerPlugin is not found.
```

**原因:**
- Session Manager Pluginがインストールされていない

**解決策:**
```bash
# Session Manager Pluginのインストール確認
which session-manager-plugin

# インストールされていない場合
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
sudo yum install -y session-manager-plugin.rpm
```

### 5. SSM接続権限エラー

**エラー:**
```
An error occurred (AccessDeniedException) when calling the StartSession operation
```

**原因:**
- IAMロールにSSM権限がない
- EC2インスタンスにSSM Agentがインストールされていない

**解決策:**
```bash
# SSM Agent状態確認
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=i-xxx" \
  --region ap-northeast-1

# IAM権限確認
aws iam get-role --role-name poc-poc-ec2-EC2Role-xxx
```

## まとめ

### 現在の構成（フェーズ1）
- ✅ `/home/tomo/poc/ansible-playbooks` - 実ディレクトリ（.gitignore除外）
- ✅ `/home/tomo/ansible-playbooks` - 別リポジトリ（ローカル）
- ✅ 手動同期で運用

### 実行方法
```bash
cd /home/tomo/poc/ansible-playbooks
uv run ansible poc_web -m ping
uv run ansible-playbook setup-laravel-environment.yml
```

### 今後の展開（フェーズ2）
1. ansible-playbooksの開発が安定したら
2. Giteaにリモートリポジトリを作成
3. Git Submoduleに移行

これにより、バージョン管理と同期が容易になります。
