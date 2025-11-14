# Test Ansible

AWSリソースの構成管理を行うAnsibleプロジェクト

## ディレクトリ構造

```
test-ansible/
├── ansible.cfg              # Ansible設定ファイル
├── inventories/             # インベントリファイル（環境別）
│   ├── poc/                # POC環境
│   │   ├── aws_ec2.yml    # AWS EC2動的インベントリ
│   │   └── group_vars/    # グループ変数
│   └── production/         # 本番環境
├── group_vars/             # グローバルグループ変数
├── host_vars/              # ホスト固有変数
├── roles/                  # Ansibleロール
├── playbooks/              # Playbookファイル
├── files/                  # 静的ファイル
├── templates/              # Jinja2テンプレート
└── vars/                   # 追加変数ファイル
```

## 使用方法

### インベントリの確認

```bash
# 動的インベントリのホスト一覧表示
ansible-inventory --list

# グラフ表示
ansible-inventory --graph
```

### Ping テスト

```bash
# すべてのホストに対してpingモジュール実行
ansible all -m ping

# 特定のグループのみ
ansible env_poc -m ping
```

### Playbook実行

```bash
# Playbook実行
ansible-playbook playbooks/site.yml

# 特定の環境のみ
ansible-playbook -i inventories/poc playbooks/site.yml

# ドライラン（変更なし）
ansible-playbook playbooks/site.yml --check

# 詳細出力
ansible-playbook playbooks/site.yml -v
```

## 接続方式

### AWS Systems Manager (SSM)

- プライベートサブネットのEC2インスタンスに対してSSM経由で接続
- パブリックIPやSSHキー不要
- VPCエンドポイント経由でセキュアに接続

設定例（`group_vars/all.yml`）:
```yaml
ansible_connection: aws_ssm
ansible_aws_ssm_region: ap-northeast-1
ansible_aws_ssm_bucket_name: "poc-poc-ansible-aws-ssm"
ansible_shell_executable: /bin/bash
ansible_remote_tmp: /tmp/.ansible/tmp
```

## Jenkins統合

### Jenkinsパイプライン

`jenkinsfiles/Jenkinsfile` に Jenkins パイプラインの定義があります。

**主な機能:**
1. test-ansibleリポジトリのチェックアウト
2. Python依存関係のインストール（uv sync）
3. 動的インベントリの確認
4. EC2インスタンスへのPingテスト
5. Ansible Playbook実行（vault-password-aws.sh使用）
6. 実行結果の検証

**実行方法:**
1. Jenkinsで新しいパイプラインジョブを作成
2. Pipeline定義を「Pipeline script from SCM」に設定
3. SCMにGitリポジトリを指定
4. Script Pathに `test-ansible/jenkinsfiles/Jenkinsfile` を指定
5. ビルドを実行

**必要な権限:**
Jenkins ECSタスクロールに以下のIAMポリシーが必要:
- `secretsmanager:GetSecretValue` (ansible/vault-password シークレット用)
- `ssm:SendCommand`, `ssm:GetCommandInvocation` (検証用)
- `ec2:DescribeInstances` (動的インベントリ用)

## 必要な権限

実行するIAMユーザー/ロールには以下の権限が必要:

- `ssm:StartSession`
- `ssm:SendCommand`
- `ec2:DescribeInstances`
- `ec2:DescribeTags`

## 参考資料

- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [AWS EC2 Dynamic Inventory](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html)
- [AWS SSM Connection Plugin](https://docs.ansible.com/ansible/latest/collections/community/aws/aws_ssm_connection.html)
