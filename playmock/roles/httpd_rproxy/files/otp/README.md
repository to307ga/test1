# 2要素認証

## 概要

* `mod_authn_otp` Apacheモジュールを利用し、2要素認証を実現します。
* 従来型のHTTP基本認証で下記のようにパスワード文字列の末尾にTOTP（Time-based One-Time Password＝時刻に基づいて生成される使い捨てパスワード）を付加するものです。

`${passwd}NNNNNN`

## A. ユーザー登録手順

* OTP認証する際のユーザーアカウントの登録方法。 

### 大まかな流れ

* ユーザを作成する。
* 成果物をPlaybookリポジトリへコミット・格納する。
* 検証/商用の全rproxyサーバへ、同一の認証情報ファイルを配布する。
* 対象ユーザに伝える。

### 1. ユーザ作成

#### コマンド

``` plaintext
add_otpuser.sh [USERNAME] [PASSWORD]
  USERNAME: 作成するユーザー名(必須)
  PASSWORD: ユーザーのパスワード(省略可能、省略した場合はランダムに作成)
```

#### 実行例

(![note 1](https://api.iconify.design/fxemoji/roundpushpin.svg)1)

``` shell
# rproxyサーバのどこかで実行します。
# ここでは、 gooid-21-dev-rproxy-101
[k5ito@gooid-21-dev-rproxy-101 ~]$ sudo /etc/httpd/otp/add_otpuser.sh hoge

認証ユーザーを作成しました
User: hoge
Password: srNS8VvJ

認証アプリへの登録は以下のQRコードまたは秘密鍵を利用してください
秘密鍵: 7E2GQHIYYWMY26I5

================================= 
[[ ここにQRコードが表示される ]]

```

### 2. 成果物ファイルを、 Playbookリポジトリへ格納

* 作成されるユーザー情報は以下のファイルに追加されます。
  * /etc/httpd/otp/user.pin    apache:apache 0600 : Basic認証パスワード
  * /etc/httpd/otp/user.token  apache:apache 0600 : TOTPトークン情報 & セッション情報

* これらファイルを
  - Playbook リポジトリへ格納します。
  - その後、ansible-playbook コマンドで、全ての rproxy サーバへ配置します。

<details>

<summary>開く：（詳細なコマンド例）</summary>

```bash
# ここでは、 gooid-21-pro-pm-101
# あらかじめ git clone されているサーバ。
# masterブランチから派生した、hotfix ブランチを作っておく。
[k5ito@gooid-21-pro-pm-101 ~/playbook]$ git branch -b hotfix/otp-user-add-$(date +'%Y%m%d')

# 成果物をまとめてひぱってくる。
[k5ito@gooid-21-pro-pm-101 ~]$ ssh -A gooid-21-dev-rproxy-101 "sudo tar -C /etc/httpd/otp -cf - users.{pin,token}" | tar -C ~/playbook/roles/httpd_rproxy/files/otp -xvf -

# users.* ファイルは暗号化
[k5ito@gooid-21-pro-pm-101 ~]$ ansible-vault encrypt ~/playbook/roles/httpd_rproxy/files/otp/users.{pin,token}

Encryption successful

###
# (略) git commit + push + pull requestからmasterへマージ
###

```

</details>

### 3. 検証/商用の全rproxyサーバへ、同一の認証情報ファイルを配布する


<details>

<summary>開く：（詳細なコマンド例）</summary>

```bash
# ansible-playbook コマンドで全サーバへ配布
# （タグを局所的につけているため、Dry Runなしで実行）

# 検証
[k5ito@gooid-21-pro-pm-101 ~]$ ansible-playbook -i inventories/development/inventory.ini --diff -t otp gooid_rproxy_server.yml 2>&1 | tee /var/tmp/$USER.txt

# 商用
[k5ito@gooid-21-pro-pm-101 ~]$ ansible-playbook -i inventories/production/inventory.ini --diff -t otp gooid_rproxy_server.yml 2>&1 | tee /var/tmp/$USER.txt
[k5ito@gooid-21-pro-pm-101 ~]$ ansible-playbook -i inventories/production/inventory.ini --diff -t otp idhub_rproxy_server.yml 2>&1 | tee /var/tmp/$USER.txt
```

</details>

![warning](https://api.iconify.design/fluent-color/warning-32.svg) これを実施すると、各ユーザが認証したTimestampなどが書き換えられてしまい、認証セッションの有効期限が短くなったり長くなってしまう可能性がある。

* 検証環境 `gooid-21-dev-rproxy-101` で生成した `users.token` ファイルが、商用 `gooid-21-pro-rproxy-001` へコピーされると、商用環境独自で保持していた認証の中間データが上書きされてしまう。

### 4. 対象ユーザに伝える。

* 前述 (![note 1](https://api.iconify.design/fxemoji/roundpushpin.svg)1) `実行例` を参照。
* Teams のDMで伝える。
  * Username, Password, 秘密鍵 の部分をペースト。
  * QRコードは、スクショして画像で渡す。



## B. mod_authn_otp ApacheモジュールのRPMパッケージ作成方法

### 大まかな流れ

1. Dockerのソースをコンテナのホストへコピー
2. docker run でRPMパッケージが生成される。
3. Yumレポジトリへ生成されたRPMパッケージを配置し、レポジトリを更新。

### 1. Dockerのソース一式をコンテナホストへコピー

* 対象ディレクトリは、 [../docker](../docker)
* コンテナホストへコピーします。

```bash
$ scp -rp roles/httpd_rproxy/files/docker gooid-21-dev-container-101:~/
```

### 2. docker run でRPMパッケージを生成

* ラッパーシェルが存在しています。それを実行します。

```bash
# コピーした先のホスト、 gooid-21-dev-container-101 にて
$ cd ~/docker
$ ./build-mod_authn_otp.sh

.......

RPMs are ready in ./rpms/
```

（参考）このDockerの中でやっていること、概要

<details>

<summary>開く</summary>

* `mod_authn_otp` のGithubからソースをclone。
* RPM SPECファイル `roles/httpd_rproxy/files/docker/files/mod_authn_otp.spec` で、rpmbuild。
</details>


* ビルドされたRPMを確認してください。
  - ./rpms/x86_64/ にはビルドされたRPMが格納されています。
  - ./rpms/SRPMS/ にはソースRPMが格納されています。

### 3. Yumレポジトリへ生成されたRPMパッケージをコピー

  - 2025-08-05現在、Yum Repositoryサーバは gooid-21-dev-repo-101 です。
  - rpms/x86_64/mod_authn_otp-X.X.X-N.el8.x86_64.rpm を、そのリモートサーバの /var/www/html/yum_repo/8/ に何らかの手段でアップロードしてください。

<details>

<summary>開く：（gooid-21-dev-container-101から、gooid-21-dev-repo-101 へ、mod_authn_otp-X.X.X-N.el8.x86_64.rpm をアップロードする場合のコマンド例）</summary>

```bash
$ FILE=mod_authn_otp-1.1.12-1.el8.x86_64.rpm
$ cat rpms/x86_64/$FILE | ssh -A gooid-21-dev-repo-101 "cat - | sudo tee /var/www/html/yum_repo/8/$FILE > /dev/null"
```

</details>


* Yum repositoryを更新します。
  - Yum repositoryサーバ（例： `gooid-21-dev-repo-101` ）へログインします。
  - /var/www/html/yum_repo/8/ ディレクトリに移動します。
  - `createrepo -v` コマンドを実行して、Yum repositoryを更新します。
