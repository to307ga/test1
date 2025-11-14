# Ansible環境構築手順

## 目次
0. [初期セットアップ](#0-初期セットアップ)
1. [AWS Secrets Manager設定](#1-aws-secrets-manager設定)
2. [暗号化ファイル作成](#2-暗号化ファイル作成)
3. [インベントリ設定](#3-インベントリ設定)
4. [Playbook作成](#4-playbook作成)
5. [ローカル実行テスト](#5-ローカル実行テスト)
6. [Jenkins統合](#6-jenkins統合)

---

## 0. 初期セットアップ

### 0.1 Python依存関係のインストール

```bash
cd /home/t-tomonaga/AWS/test-ansible

# uv sync でPython依存関係とAnsibleコレクションをインストール
uv sync
```

**インストールされるパッケージ:**
- ansible>=12.1.0 (Ansibleコレクション amazon.aws, community.aws, ansible.posix を含む)
- boto3>=1.40.21
- botocore>=1.34.21
- jmespath>=1.0.1
- pyyaml>=6.0.2

### 0.2 インストール確認

```bash
# Ansibleバージョン確認
uv run ansible --version

# インストールされたコレクション確認
uv run ansible-galaxy collection list
```

**必要なコレクション（自動的にインストールされる）:**
- amazon.aws: AWS EC2動的インベントリ、SSM接続プラグイン
- community.aws: AWS追加モジュール
- ansible.posix: POSIX互換モジュール

---

## 1. AWS Secrets Manager設定

### 1.1 シークレット作成

Ansible Vaultのパスワードを AWS Secrets Manager に格納します。

```bash
# シークレット新規作成
aws secretsmanager create-secret \
  --name ansible/vault-password \
  --description "Ansible Vault password for test-ansible project" \
  --secret-string '{"password":"XXXXXXXXX"}' \
  --region ap-northeast-1
```

**説明:**
- `--name ansible/vault-password`: シークレット名を指定（Jenkins の vault-password-aws.sh が参照）
- `--secret-string '{"password":"XXXXXXXXX"}'`: .vault_pass ファイルと同じパスワードを設定
- `--region ap-northeast-1`: 東京リージョンに作成

**エラーが発生した場合（シークレットが既に存在する場合）:**

```bash
# 既存シークレットの値を更新
aws secretsmanager put-secret-value \
  --secret-id ansible/vault-password \
  --secret-string '{"password":"XXXXXXXXX"}' \
  --region ap-northeast-1
```

### 1.2 シークレット確認

```bash
# シークレットが正しく作成されたか確認
aws secretsmanager get-secret-value \
  --secret-id ansible/vault-password \
  --region ap-northeast-1 \
  --query SecretString \
  --output text
```

**期待される出力:** `XXXXXXXXX`

### 1.3 vault-password-aws.sh の動作確認

Jenkins コンテナ内で vault-password-aws.sh が正しく動作するか確認します。

```bash
# 環境変数設定
export AWS_VAULT_SECRET_NAME="ansible/vault-password"
export AWS_REGION="ap-northeast-1"

# スクリプト実行（Jenkins コンテナ内で）
/usr/local/bin/vault-password-aws.sh
```

**期待される出力:** `XXXXXXXXX`

---

## 2. 暗号化ファイル作成

### 2.1 vars/secret.yml 作成

暗号化する秘密情報を含むファイルを作成します。

```bash
cd /home/t-tomonaga/AWS/test-ansible

# 暗号化前のファイル作成（一時的）
cat > vars/secret.yml.tmp <<'EOF'
---
# 暗号化される秘密情報
secret_message: "Hello from Ansible Vault"
EOF

# .vault_pass を使用して暗号化
ansible-vault encrypt vars/secret.yml.tmp \
  --vault-password-file .vault_pass \
  --output vars/secret.yml

# 一時ファイル削除
rm vars/secret.yml.tmp
```

**説明:**
- `ansible-vault encrypt`: ファイルを暗号化
- `--vault-password-file .vault_pass`: パスワードファイルを指定（ローカル環境用）
- `--output vars/secret.yml`: 暗号化後のファイル名

### 2.2 暗号化ファイル確認

```bash
# 暗号化されたファイルの内容表示（暗号化された状態）
cat vars/secret.yml

# 暗号化されたファイルの内容を復号して表示
ansible-vault view vars/secret.yml --vault-password-file .vault_pass
```

**期待される出力（復号後）:**
```yaml
---
secret_message: "Hello from Ansible Vault"
```

---

## 3. インベントリ設定

### 3.1 動的インベントリの確認

AWS EC2 の動的インベントリが正しく動作するか確認します。

```bash
cd /home/t-tomonaga/AWS/test-ansible

# すべてのホストを一覧表示
ansible-inventory --list

# グラフ形式で表示
ansible-inventory --graph

# 特定のホストの変数を確認
ansible-inventory --host <instance-id>
```

### 3.2 フィルタリング条件

`inventories/poc/aws_ec2.yml` で以下のタグによるフィルタリングが可能：
- **Name**: pochub-001, pochub-002, pochub-003
- **Environment**: poc
- **AvailabilityZone**: ap-northeast-1a, ap-northeast-1c, ap-northeast-1d

---

## 4. Playbook作成

### 4.1 playbooks/test1.yml

以下の処理を行う Playbook:
1. ansible ping で疎通確認
2. 暗号化ファイル (vars/secret.yml) を読み込み
3. `/tmp/{{ inventory_hostname }}_ansible` ファイルを作成し、復号した文字列を書き込む

Playbook は別途作成します（後述）。

---

## 5. ローカル実行テスト

### 5.1 接続テスト（ping）

```bash
cd /home/t-tomonaga/AWS/test-ansible

# すべてのホストに ping
ansible all -m ping

# 特定のグループに ping
ansible env_poc -m ping
```

### 5.2 Playbook 実行（ローカル環境）

**注意:** `ansible.cfg`に`vault_password_file = /usr/local/bin/vault-password-aws.sh`が設定されているため、`--vault-password-file`オプションは不要です。direnvで環境変数が自動設定されていれば、そのまま実行できます。

```bash
# 通常実行（vault-password-fileオプション不要）
uv run ansible-playbook playbooks/test1.yml

# 詳細出力
uv run ansible-playbook playbooks/test1.yml -vv

# ドライラン（変更なし）
uv run ansible-playbook playbooks/test1.yml --check

# Diffも表示（変更内容を確認）
uv run ansible-playbook playbooks/test1.yml --check --diff
```

**補足: ローカル環境で`.vault_pass`を使う場合**

direnvやAWS Secrets Managerを使わず、ローカルの`.vault_pass`ファイルを使う場合：

```bash
# ansible.cfgを一時的に上書き
ansible-playbook playbooks/test1.yml \
  --vault-password-file .vault_pass
```

### 5.3 結果確認

```bash
# EC2 インスタンスに SSM 経由で接続してファイル確認
# (connect-gitea.sh などで EC2 に接続後)

# ファイルの存在確認
ls -l /tmp/*_ansible

# ファイルの内容確認
cat /tmp/<hostname>_ansible
```

**期待される内容:** `Hello from Ansible Vault`

---

## 6. Jenkins統合

### 6.1 IAM ポリシー確認

Jenkins の ECS タスクロールに以下の権限が必要です：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:ap-northeast-1:*:secret:ansible/vault-password-*"
    }
  ]
}
```

### 6.2 権限確認コマンド

```bash
# Jenkins タスクロールの確認
aws ecs describe-task-definition \
  --task-definition poc-poc-ecs-jenkins-TaskDefinition \
  --query 'taskDefinition.taskRoleArn' \
  --output text

# ロールにアタッチされたポリシーを確認
aws iam list-attached-role-policies \
  --role-name <タスクロール名>

# ポリシーの内容を確認
aws iam get-policy-version \
  --policy-arn <ポリシーARN> \
  --version-id v1
```

### 6.3 Jenkinsfile 作成

vault-password-aws.sh を使用した Jenkins パイプラインを作成します（後述）。

### 6.4 Jenkins から実行

```groovy
// Jenkinsfile 内で
environment {
    AWS_VAULT_SECRET_NAME = 'ansible/vault-password'
    AWS_REGION = 'ap-northeast-1'
}

steps {
    sh '''
        ansible-playbook playbooks/test1.yml \
          --vault-password-file /usr/local/bin/vault-password-aws.sh
    '''
}
```

---

## トラブルシューティング

### エラー: "Secret not found"

**原因:** AWS Secrets Manager にシークレットが存在しない、または名前が間違っている

**解決策:**
```bash
# シークレット一覧を確認
aws secretsmanager list-secrets \
  --region ap-northeast-1 \
  --query 'SecretList[?contains(Name, `ansible`)].Name'
```

### エラー: "ERROR! Decryption failed"

**原因:** vault パスワードが間違っている

**解決策:**
```bash
# .vault_pass の内容確認
cat .vault_pass

# AWS Secrets Manager の値確認
aws secretsmanager get-secret-value \
  --secret-id ansible/vault-password \
  --region ap-northeast-1 \
  --query SecretString \
  --output text

# 両方が一致していることを確認
```

### エラー: "Failed to connect to the host via aws_ssm"

**原因:** SSM VPC エンドポイントが設定されていない、またはインスタンスに SSM エージェントがインストールされていない

**解決策:**
```bash
# VPC エンドポイント確認
aws ec2 describe-vpc-endpoints \
  --filters "Name=service-name,Values=com.amazonaws.ap-northeast-1.ssm" \
  --region ap-northeast-1

# インスタンスの SSM エージェント状態確認
aws ssm describe-instance-information \
  --filters "Key=tag:Environment,Values=poc" \
  --region ap-northeast-1
```

---

## 7. direnv によるローカル環境変数管理

### 7.1 direnv とは何か

`direnv`は**ディレクトリごとに環境変数を自動的に読み込む/解除するツール**です。

**なぜdirenvを使用するのか？**

ローカル環境でAnsibleを実行する際、`vault-password-aws.sh`は以下の環境変数を必要とします：
- `AWS_VAULT_SECRET_NAME`: Secrets Managerのシークレット名
- `AWS_REGION`: AWSリージョン

**従来の方法の問題点：**
```bash
# 毎回手動で設定する必要がある
export AWS_VAULT_SECRET_NAME='ansible/vault-password'
export AWS_REGION='ap-northeast-1'
ansible-playbook playbooks/test1.yml --vault-password-file /usr/local/bin/vault-password-aws.sh

# または .env ファイルを毎回読み込む
source .env
ansible-playbook playbooks/test1.yml --vault-password-file /usr/local/bin/vault-password-aws.sh
```

**direnvを使う利点：**
- ✅ `test-ansible`ディレクトリに**入ると自動で環境変数が設定**される
- ✅ ディレクトリから**出ると自動で環境変数が解除**される
- ✅ 他のプロジェクトの環境変数と混在しない
- ✅ 手動で`source`や`export`を実行する必要がない

**Jenkins との整合性：**
- Jenkins: Jenkinsfileの`environment`で環境変数を設定
- ローカル: direnvで`.envrc`から環境変数を自動読み込み
- →**両方で同じスクリプト（vault-password-aws.sh）が動作**

### 7.2 direnv のインストール

```bash
# ホームディレクトリの.local/binにインストール
mkdir -p ~/.local/bin
export bin_path=~/.local/bin
curl -sfL https://direnv.net/install.sh | bash
```

**インストール先:** `~/.local/bin/direnv`

### 7.3 bash への統合

```bash
# .bashrc に direnv フックを追加
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

# 設定を再読み込み
source ~/.bashrc

# インストール確認
direnv version
```

**期待される出力:** `2.37.1` （またはそれ以降のバージョン）

### 7.4 .envrc ファイルの作成

プロジェクトルートに`.envrc`ファイルを作成します：

```bash
cd /home/t-tomonaga/AWS/test-ansible

# .envrc ファイルを作成
cat > .envrc << 'EOF'
# Ansible Vault用環境変数
export AWS_VAULT_SECRET_NAME='ansible/vault-password'
export AWS_REGION='ap-northeast-1'
EOF
```

### 7.5 .envrc の許可

セキュリティのため、初回のみ`.envrc`を明示的に許可する必要があります：

```bash
cd /home/t-tomonaga/AWS/test-ansible
direnv allow .
```

**出力例:**
```
direnv: loading ~/AWS/test-ansible/.envrc
direnv: export +AWS_REGION +AWS_VAULT_SECRET_NAME
```

### 7.6 動作確認

```bash
# test-ansible ディレクトリに移動
cd /home/t-tomonaga/AWS/test-ansible
# → direnv: loading ~/AWS/test-ansible/.envrc
# → direnv: export +AWS_REGION +AWS_VAULT_SECRET_NAME

# 環境変数が設定されていることを確認
echo $AWS_VAULT_SECRET_NAME
# → ansible/vault-password

echo $AWS_REGION
# → ap-northeast-1

# 親ディレクトリに移動
cd ..
# → direnv: unloading

# 環境変数が解除されていることを確認
echo $AWS_VAULT_SECRET_NAME
# → （空）

[t-tomonaga@gooid-21-pro-pm-101 AWS]$ cd /home/t-tomonaga/AWS/test-ansible
direnv: loading ~/AWS/test-ansible/.envrc
direnv: export +AWS_REGION +AWS_VAULT_SECRET_NAME
[t-tomonaga@gooid-21-pro-pm-101 test-ansible]$ 
[t-tomonaga@gooid-21-pro-pm-101 test-ansible]$ cd ..
direnv: unloading
[t-tomonaga@gooid-21-pro-pm-101 AWS]$ 

```

### 7.7 direnv を使った Ansible 実行

direnv設定後は、ディレクトリに入るだけで環境変数が自動設定されます：

```bash
# ディレクトリに移動（自動で環境変数設定）
cd /home/t-tomonaga/AWS/test-ansible

# Ansibleを実行（source や export 不要！）
uv run ansible-playbook playbooks/test1.yml \
  --vault-password-file /usr/local/bin/vault-password-aws.sh \
  --check --diff
```

### 7.8 .gitignore の設定

`.envrc`は環境固有のファイルなので、Gitにコミットしません：

```bash
# .gitignore に追加（既に追加済み）
# Environment variables
.env
.envrc
```

### 7.9 セキュリティに関する注意

**direnv のセキュリティ機能：**
- `.envrc`は`direnv allow`で明示的に許可しない限り自動実行されない
- リポジトリをクローンした際、他人の`.envrc`が勝手に実行されることはない
- `.envrc`を変更した場合、再度`direnv allow`が必要

**機密情報の取り扱い：**
- ✅ Secret名やリージョン名は`.envrc`に記載してもOK
- ❌ **実際のパスワードや認証情報は絶対に書かない**
- ✅ AWS認証情報は別途`aws configure`や`aws_mfa_credentials`で管理

### 7.10 トラブルシューティング

**エラー: "direnv: error .envrc is blocked"**

**原因:** `.envrc`が許可されていない

**解決策:**
```bash
cd /home/t-tomonaga/AWS/test-ansible
direnv allow .
```

**エラー: "AWS_VAULT_SECRET_NAME environment variable is required"**

**原因:** direnvが正しく動作していない、または`.envrc`が読み込まれていない

**解決策:**
```bash
# direnvが正しくインストールされているか確認
direnv version

# .bashrcにフックが追加されているか確認
grep direnv ~/.bashrc

# 新しいシェルを起動して試す
bash
cd /home/t-tomonaga/AWS/test-ansible

# 手動で環境変数を確認
echo $AWS_VAULT_SECRET_NAME
```

---

## 参考資料

- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [AWS Secrets Manager CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/secretsmanager/)
- [AWS SSM Connection Plugin](https://docs.ansible.com/ansible/latest/collections/community/aws/aws_ssm_connection.html)
- [direnv Documentation](https://direnv.net/)
- [direnv GitHub Repository](https://github.com/direnv/direnv)
