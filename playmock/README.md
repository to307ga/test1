# gooID, goo決済, idhub システム Ansible Playbook

* playbookは、gooidサービスのそれぞれのサーバに必要なパッケージを構築するように構成されています。
* 監視ソフトウェアやユーザ管理などは対象外です。（「事前のPuppet」の責務です。）


* playbookを実行するとき、Ansible-vaultのパスワードが必要になります。
https://fgw120.goo.ne.jp/redmine/projects/gooid/wiki/DeveloperAccount
上記のURLからAnsible-Vault passworddで探してください。

# 0. 実行環境

* Frontend Server群は、 `gooid-21-pro-pm-001` からAnsibleを実行します。

```bash
gooid-21-pro-pm-001 # Puppet master 兼、Ansible Controller

      `--(Ansible Playbook Kick via SSH)-->

                # 以下のようなFrontend Server群
                gooid-21-pro-web-00x
                gooid-21-pro-hlp-00x
                ......

                # idhub-21 のFrontend Server群も
                idhub-21-pro-web-00x
                idhub-21-pro-hlp-00x
                ......
```

* Backendサーバ群に対しては、 `gooid-21-pro-log-001` から実行します。（ `gooid-21-pro-pm-001` からはSSHが到達できないため。）

```bash
gooid-21-pro-log-001 # Backendサーバ用、Ansible Controller

      `--(Ansible Playbook Kick via SSH)-->

                # 以下のようなBackend Server群
                gooid-21-pro-mdb-00x
                gooid-21-pro-sdb-00x
                gooid-21-pro-batch-00x
                ......

                # idhub-21 のBackend Server群も
                idhub-21-pro-mdb-00x
                idhub-21-pro-sdb-00x
                idhub-21-pro-batch-00x
                ......
```


# 1. 実行例

## 1.1. （基本形）playbookの実行コマンド

`ansible-playbook -i <inventory_file> <playbook.yml>`

* 商用環境での例:
`ansible-playbook -i inventories/production/inventory.ini gooid_web_server.yml`

* 検証環境での例:
`ansible-playbook -i inventories/development/inventory.ini gooid_web_server.yml`


* HA構成のサーバ (batch, fgw, msg) の場合、/db0配下に対する変更作業はアクティブにのみ作用する。
* ansibleを実行する場合は必ずVIP(末尾000)で実行すること。※playbookが末尾3桁を確認して000以外は/db0配下を変更しない。

* 例としてfgwのアクティブに対してansibleをキックする手順を記述する。（/db0配下も更新される）
`ansible-playbook -i ./inventories/production/inventory.ini gooid_fgw_server.yml --diff -l gooid-21-pro-fgw-000`

* 次の場合、gooid-21-pro-fgw-001がアクティブであったとしても/db0配下は更新されない。
`ansible-playbook -i ./inventories/production/inventory.ini gooid_fgw_server.yml --diff -l gooid-21-pro-fgw-001`

* crontabだけ指定のサーバに配布したい場合
`ansible-playbook -i inventories/production/inventory.ini gooid_batch_server.yml --diff -t cron -l gooid-21-pro-batch-002`

* ネットワーク越しのSSHでPlaybookが実行できない場合
    * ローカルHDDにGit Cloneしておきます。
    * 以下のコマンドを実行します。キーワードは `-c local`

```shell
# gooid-21-pro-fgw-001 内で完結させるPlaybook
$ ansible-playbook -i ./inventories/production/inventory.ini -c local --diff  gooid_fgw_server.yml -l gooid-21-pro-fgw-001 -t httpd_fgw
```


## 1.1.1 /etc/hostsを配布するplaybookの実行コマンド(商用環境のみ)

* gooid-21の全サーバに配布：
`ansible-playbook -i inventories/production/inventory.ini etc_hosts_gooid-21.yml`

* idhub-21の全サーバに配布：
`ansible-playbook -i inventories/production/inventory.ini etc_hosts_idhub-21.yml`

## 1.2. （基本形）playbookのシンタックスチェック:

`ansible-playbook -i <inventory_file> <playbook.yml> --syntax-check`

* 商用環境での例:
`ansible-playbook -i inventories/production/inventory.ini gooid_web_server.yml --syntax-check`

* 検証環境での例:
`ansible-playbook -i inventories/development/inventory.ini gooid_web_server.yml --syntax-check`

## 1.3. dry-run

`ansible-playbook -i <inventory_file> <playbook.yml> --check --diff`

* 例：
`ansible-playbook -i ./inventories/production/inventory.ini --check --diff gooid_web_server.yml`

* （応用1）2台だけピンポイント指定で dry-run
`ansible-playbook -i ./inventories/production/inventory.ini -l 'gooid-21-pro-web-001,gooid-21-pro-web-002' --check --diff gooid_web_server.yml`


* （応用2）httpd_hlpというタグを指定してピンポイントで dry-run
`ansible-playbook -i inventories/production/inventory.ini --check --diff -t httpd_hlp  gooid_web_server.yml`

## 1.9. Tips

### 1.9.1. サーバに設定された変数値を確認するコマンド(全サーバ対象):

* `ansible-inventory` コマンドを使います。
`ansible-inventory -i <inventory_file> --list --yaml`


* 商用環境での例:
`ansible-inventory -i inventories/production/inventory.ini --list --yaml`

* 検証環境での例:
`ansible-inventory -i inventories/development/inventory.ini --list --yaml`

### 1.9.2. サーバに設定された変数値を確認するコマンド(指定したサーバが対象):

* `ansible-inventory` コマンドを使います。
`ansible-inventory -i <inventory_file> --host <host_server>  --yaml`

* 商用環境での例:
`ansible-inventory -i inventories/production/inventory.ini --host gooid-21-pro-web-001  --yaml`

* 検証環境での例:
`ansible-inventory -i inventories/development/inventory.ini --host gooid-30-dev-web-101  --yaml`

## 2.0. Ansible-Vaultで暗号化されたファイルを編集など

* `ansible-vault` コマンドを使います。

`ansible-vault edit|view|encrypt|decrypt <file_name>`

* 暗号化したファイルを修正する例
`ansible-vault edit private-gooid-21.yml`

* 暗号化されているファイルを編集せずに確認する例
`ansible-vault view private-gooid-21.yml`

* ファイルを暗号化する例
`ansible-vault encrypt private-gooid-21.yml`

* ファイルを復号化する例$
`ansible-vault decrypt private-gooid-21.yml`

# 2. 備考

## 2.1. （初回）Ansibleコントローラ設定・構築手順

* (1) Ansibleをインストールする

```bash
$ sudo yum install ansible
```

* (2) 設定ファイルを編集する。
    * `/etc/ansible/ansible.cfg`

```ini
[defaults]

# 並列度20で実行
forks = 20
# カラーでDiffなどを表示
force_color=true
# /etc/ansible/vault-password へPasswdは記載
vault_password_file=./vault-password


[ssh_connection]

# ......

# AnsibleのSSH接続エラーの回避設定 - Qiita
# https://qiita.com/taka379sy/items/331a294d67e02e18d68d#%E8%AD%A6%E5%91%8A%E3%83%A1%E3%83%83%E3%82%BB%E3%83%BC%E3%82%B8%E3%81%8C%E8%A1%A8%E7%A4%BA%E3%81%95%E3%82%8C%E3%82%8B%E7%8A%B6%E6%B3%81
#
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
```

* Ansible Vaultのパスワードをコントローラ側の上記 `vault_password_file` の部分で設定しているため、CLIでは ` --ask-vault-pass` は不要となっている。

* (3) `vault-password` ファイルを置く
    * 実際のパスワード（下記 `PASSWD` の右辺）は、 [Redmine ＞ DeveloperAccount](https://ticket.id001.goo.ne.jp/projects/gooid/wiki/DeveloperAccount) のWikiに記載されています。

```bash
$ PASSWD="xxxxxx"
$ echo $PASSWD | sudo tee /etc/ansible/vault-password
$ sudo chmod 644 /etc/ansible/vault-password
```

* (4) Git2系 をインストール
    * [CentOS7にGit2系をyumでインストール - Qiita](https://qiita.com/d-dai/items/3cc0c8c81911d5b6cce5) を参考に。（ちょっとめんどくさい。）

```bash
$ sudo yum install https://repo.ius.io/ius-release-el7.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# いったん、最初から入っているGit下位バージョンの削除
$ sudo yum remove perl-Git-1.8.3.1-23.el7_8.noarch git-1.8.3.1-23.el7_8.x86_64 git-1.8.3.1-23.el7_8.x86_6

$ sudo yum install git236
$ git version
git version 2.36.1

# 後始末（余計なRepoを削除）
$ sudo rpm -e ius-release epel-release
```

## 2.2. （初回のみ）自分の作業環境の整備（ワーキングディレクトリなど）

* 要：各人が実施

* (1) gitにProxy設定したり、初回Clone

```bash
# Proxy
# (三鷹の場合)
$ git config --global http.proxy http://infra-20-pro-svn-301:10000/
# (R-Cloudの場合)
$ git config --global http.proxy http://172.17.255.232:8080/


# clone
$ cd ~
$ git clone https://container.wbo110.goo.ne.jp/repo/nttr/playbook.git

# git push/pull するときにBasic認証Passwdを毎回問われないようにする。
# ※ Passwdが平文で保存されます。個人の責任で実施する/しない、を判断してください。
$ cd ~/playbook
$ git config credential.helper store
```

* (2) 追加の ansible モジュールのインストール

本playbookでは Containers.Podman モジュール及び Ansible.Posix モジュールを使用している(特にコンテナ関連ロール)  
これらは Epel に含まれているため通常はAnsibleロールでデプロイされたサーバーに既に入っているはずであるが、
CentOS7など古いディストリビューションのリポジトリには含まれていない場合がある。
そのような場合は ansible_requirements.yml に定義された拡張モジュールを別途インストールする必要がある。

以下の内容で ansible_requirements.yml ファイルを作成する
```bash
cat <<'EOF' > ansible_requirements.yml
collections:
  - name: containers.podman
    version: "1.16.3"
  - name: ansible.posix
    version: "1.5.4" 
EOF
```

ansible-galaxy collection コマンドでモジュールをインストールする。

```bash
ansible-galaxy collection install -r ansible_requirements.yml
```

インストールされたことを確認する。  

```bash
ls ~/.ansible/collections/ansible_collections/containers/podman
ls ~/.ansible/collections/ansible_collections/ansible/posix
```
または、バージョンによっては `collection list` コマンドで一覧を確認することができる。

```bash
ansible-galaxy collection list
```


## 以上
