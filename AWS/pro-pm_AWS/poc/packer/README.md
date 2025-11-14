# Immutable AMI Builder

このディレクトリには、Immutable方式でのゴールデンAMI作成に必要なファイルが含まれています。

## 🎯 **設計方針**

### AMIの役割分離
- **Golden AMI**: OS + ミドルウェア + 基本設定のみ
- **アプリケーション**: Gitea管理 → Jenkins経由で別途デプロイ

### 統合フロー
1. **AMI作成**: Packer + Ansible（ミドルウェア設定）
2. **インフラ展開**: CloudFormation/Sceptre（新しいAMI使用）
3. **アプリデプロイ**: Jenkins + Ansible（Giteaからアプリコード取得）
4. **Blue-Green切替**: Load Balancer経由でトラフィック移行

## 📁 ディレクトリ構成

```
packer/
├── golden-ami.pkr.hcl          # Packerテンプレート
├── ansible/                   # Ansible設定
│   ├── site.yml              # メインPlaybook
│   ├── inventory/            # インベントリファイル
│   └── roles/               # Ansibleロール
│       ├── base/            # ベースシステム設定
│       ├── security/        # セキュリティ設定
│       ├── monitoring/      # 監視設定
│       └── middleware/      # ミドルウェア設定（Apache, PHP, Node.js）
└── README.md                # このファイル
```

## 🚀 使用方法

### 1. 事前準備

#### AWS認証情報の設定
```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=ap-northeast-1
```

#### 必要なツールのインストール
```bash
# Packer
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install packer

# Ansible
pip install ansible-core
ansible-galaxy collection install community.general
ansible-galaxy collection install amazon.aws
```

### 2. AMI作成の実行

#### 基本的な実行
```bash
cd packer
packer build golden-ami.pkr.hcl
```

#### パラメータを指定した実行
```bash
packer build \
    -var 'environment=poc' \
    -var 'project_code=myproject' \
    -var 'ami_version=v1.0.0' \
    golden-ami.pkr.hcl
```

### 3. Jenkins CI/CDでの実行

Jenkinsfileが用意されているため、Jenkinsパイプラインとして実行できます：

1. Jenkins画面で新しいPipelineジョブを作成
2. Pipeline定義を「Pipeline script from SCM」に設定
3. このリポジトリを指定し、Script Pathを `jenkins/Jenkinsfile` に設定
4. パラメータを設定してビルド実行

## 🔧 設定のカスタマイズ

### Packerテンプレートの修正

`golden-ami.pkr.hcl` の variables セクションで以下をカスタマイズできます：

- `base_ami_name_filter`: ベースAMIの選択条件
- `instance_type`: ビルド用インスタンスタイプ
- `ssh_username`: SSH接続ユーザー名

### Ansible設定の追加

新しいロールを追加する場合：

1. `ansible/roles/` 下に新しいロールディレクトリを作成
2. `ansible/site.yml` にロールを追加
3. 必要に応じてタグを設定

### セキュリティ設定

本番環境では以下の設定を追加することを推奨：

- IAM Instanceプロファイルの使用
- VPC内のプライベートサブネットでのビルド
- セキュリティグループの最小化
- AMIの暗号化

## 📊 監視・ログ

### ビルドログの確認
```bash
# Packerログの有効化
export PACKER_LOG=1
export PACKER_LOG_PATH=./packer.log

# ビルド実行
packer build golden-ami.pkr.hcl

# ログ確認
tail -f packer.log
```

### AMI情報の確認
```bash
# 作成されたAMIの確認
aws ec2 describe-images \
    --owners self \
    --filters "Name=tag:Project,Values=poc" \
    --query 'Images[*].[ImageId,Name,CreationDate]' \
    --output table
```

## 🔄 Blue-Green デプロイとの連携

作成されたAMIは自動的にLaunch Templateに設定され、Blue-Green デプロイメントで使用されます：

1. **Green環境作成**: 新しいAMIでAutoScaling Groupを作成
2. **ヘルスチェック**: アプリケーションの動作確認
3. **トラフィック切替**: Load Balancerでトラフィックを段階的に移行
4. **Blue環境削除**: 旧環境のクリーンアップ

## 🚨 トラブルシューティング

### よくある問題

#### 1. SSM接続エラー
```bash
# SSM Agentが動作しているか確認
aws ssm describe-instance-information \
    --filters "Key=PingStatus,Values=Online"
```

#### 2. Ansible実行エラー
```bash
# Ansible設定のテスト
ansible-playbook -i inventory ansible/site.yml --check
```

#### 3. AMI作成失敗
```bash
# Packerテンプレートの検証
packer validate golden-ami.pkr.hcl

# 詳細ログの確認
PACKER_LOG=1 packer build golden-ami.pkr.hcl
```

## 📚 参考リンク

- [Packer Documentation](https://www.packer.io/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [AWS EC2 AMI Builder](https://www.packer.io/plugins/builders/amazon/ebs)
- [Blue-Green Deployment with AWS](https://aws.amazon.com/blogs/compute/bluegreen-deployments-with-amazon-ecs/)

---

**注意**: 本設定はPOC環境用です。本番環境では適切なセキュリティ設定とアクセス制御を実装してください。
