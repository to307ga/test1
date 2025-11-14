# Jenkins × Ansible × EC2（AWS SSM接続）構成ガイド

## 概要
Fargate上のJenkinsからAnsibleを利用し、EC2インスタンスの構成管理を行う際は、AWS Systems Manager (SSM) Session Manager接続が推奨されます。SSH鍵不要・IAM権限のみで安全に管理できます。

---

## メリット
- SSHポート開放・鍵管理不要
- IAM権限のみで接続可能
- セキュリティ向上
- ログ・監査も容易

---

## 必要条件
- EC2インスタンスにSSM Agentインストール済み（Amazon Linux 2は標準搭載）
- IAMロールにSSM関連権限（AmazonSSMManagedInstanceCore）付与
- Jenkins（Fargate）からAWS認証情報（IAMロール/プロファイル）でAnsibleを実行

---

## Ansibleインベントリ例（SSM接続）
```ini
[ec2]
i-0abc123def456ghij

group_vars/ec2.yml:
ansible_connection: aws_ssm
ansible_aws_ssm_profile: default  # 必要に応じてAWS認証情報を指定
```

---

## Playbook例
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

---

## IAMロール・ポリシー設計

### Jenkins（Fargate）用IAMロール
Jenkins（Fargate）からAnsibleでEC2/SSM操作を行う場合、以下の権限が必要です。

#### 必要なポリシー例
- AmazonSSMFullAccess（または必要最小限のSSM権限）
- AmazonEC2ReadOnlyAccess（EC2インスタンス情報取得用）
- その他、必要に応じてタグ・インベントリ・CloudWatch等

#### ポリシーJSON例（最小構成）
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

### EC2インスタンス用IAMロール
EC2側にはSSM Agent用のIAMロール（AmazonSSMManagedInstanceCore）を割り当ててください。

---

## 参考リンク
- [Ansible aws_ssm connection plugin](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ssm_connection.html)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)

---

## 備考
- SSM接続はEC2インスタンスのSSM Agent・IAMロール設定が必須です。
- JenkinsからAnsibleを実行する際は、AWS認証情報の渡し方（環境変数、プロファイル等）に注意してください。
- 将来的には、Jenkinsの再起動に対応するために、コンテナを --restart unless-stopped フラグで起動することをお勧めします
  ```
  docker run -d --restart unless-stopped -p 8081:8080 -p 50001:50000 --name jenkins-poc-lts jenkins-custom:lts
  ```

