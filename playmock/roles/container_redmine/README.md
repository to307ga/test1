# Podman 上で Redmine サービスコンテナを構成するにあたっての注意点

この資料は Redmine サービスを Podman コンテナに統合する際の知見をまとめたものです。特に Podman rootless コンテナで運用する方針に従うため docker-compose (podman-compose) は使用できず代わりに Podman Pod を使う必要があったため、Pod化の手順に重点を置いて記述しています。 


## podman-compose ではなく Podman Pod を使う

### コンテナ間ネットワークの問題

Podman の rootless 環境ではコンテナにIPが割り当てられないという制限があります。
これまで docker-compose で構成してきた Redmine と MySQL コンテナ間をサービス名で接続する方法が取れません。

そのため複数のコンテナで構成されるサービスを構築する場合は Pod としてまとめる必要があります。
Pod にまとめることにより、localhost:PORT で各コンテナのサービスにアクセスできます。

## Podman Pod によるサービス構築

Redmine サービスは最終的に systemd による稼働管理を行いますが、Podman Pod で構成する場合は従来のように記述済みのユニットファイルを配布することはできません。これは systemd ユニットファイルを Pod の情報から生成する必要があるためです。

Pod の構築から systemd サービス化までの手順は大まか次のようになります。

※「おおまか」とは、ホストと共有する volume の作成とコンテナへのアタッチなど細かな手順の説明は省略し、Podの構築とsystemdサービス化の手順に特化して説明していることを指します。実際の詳細手順は container_redmine ロールのタスクファイル *.yml を確認してください。

### playbook タスクに必要なリソースを揃える手順

1. Redmine と MySQL のコンテナイメージをビルドする
2. Redmine Pod を作成する
3. Redmine Pod に Redmine と MySQL のコンテナを登録する
4. 作成した Pod を元に Kubernetes YAML ファイルを生成する

### paybook タスクでの Redmine サービスの構築手順

5. Redmine Pod を Kubernetes YAML ファイルで構築し起動する
6. Redmine Pod を元に systemd ユニットファイルを生成する
7. Redmine サービスを登録し起動する

以降、各手順を概説します。

各説明は podman コマンドの実行例で説明しますが、playbook タスクでは可能な限り Containers.Podmanモジュール を使用して記述しています。これは Ansible モジュールを使うことでタスクをコマンドの羅列ではなく状態の遷移として記述しやすいためです。


### 1. Redmine と MySQL のコンテナイメージをビルドする

作業ディレクトリ下にさらにイメージごとのディレクトリを作成し、そこに各コンテナごとの Containerfile を用意します。

例）redmine, mysql ディレクトリを作成し各ディレクトリ下に Containerfile を作成したのち、各ディレクトリをカレントディレクトリして以下のコマンドを実行します。

※各イメージ作成に必要な設定ファイル等は割愛しています。

* redmine イメージの作成

```
$ podman build -t redmine-podman:1.0.0 -f Containerfile .
```

* redmine_db (mysql) イメージの作成

```
$ podman build -t redmine_db-podman:1.0.0 -f ./mysql/Containerfile ./mysql
```


### 2. Redmine Pod を作成する

次のコマンドで redminepod 名の Pod を作成します。

```
$ podman pod create --name redminepod --publish 3000:3000
``` 

### 3. Redmine Pod に Redmine と MySQL のコンテナを登録する

まずコンテナにマウントするボリュームを作成します。

```
$ podman volume create redmine_db_data
$ podman volume create redmine_files
```

次に、以下のコマンドで redminepod に MySQL コンテナを登録します。

```
$ podman run --detach --pod redminepod \
  --env MYSQL_DATABASE=db_redmine \
  --env MYSQL_ROOT_PASSWORD=rootpw \
  --env MYSQL_USER=user_redmine \
  --env MYSQL_PASSWORD=userpw \
  --env TZ='Asia/Tokyo' \
  --volume redmine_db_data:/var/lib/mysql \
  --name redmine_db localhost/redmine_db-podman:1.0.0 mysqld
```

続けて redminepod に Redmine コンテナを登録します。

```
$ podman run --detach --pod redminepod \
  --env http_proxy="プロキシーアドレス:ポート" \
  --env https_proxy="プロキシーアドレス:ポート" \
  --env HTTP_PROXY="プロキシーアドレス:ポート" \
  --env HTTPS_PROXY="プロキシーアドレス:ポート" \
  --env no_proxy="localhost,127.0.0.1" \
  --env NO_PROXY="localhost,127.0.0.1" \
  --env REDMINE_DB_MYSQL=localhost \
  --env REDMINE_DB_DATABASE=db_redmine \
  --env REDMINE_DB_USERNAME=user_redmine \
  --env REDMINE_DB_PASSWORD="userpw" \
  --env REDMINE_DB_ENCODING=utf8mb4 \
  --env TZ="Aisa/Tokyo" \
  --volume redmine_files:/usr/src/redmine/files
  --name redmine localhost/redmine-podman:1.0.0
```

### 4. 作成した Pod を元に Kubernetes YAML ファイルを生成する

次のコマンドで redminepod から Kubernetes ファイル `redminepod.yml` を生成します。

```
$ podman generate kube redminepod > redminepod.yml
```

### 5. Redmine Pod を Kubernetes YAML ファイルで構築し起動する

redminepod.yml を指定して Redmine Pod の構築と起動を行います。

```
$ podman play kube redminepod.yml
```


### 6. Redmine Pod を元に systemd ユニットファイルを生成する

構築した Redmine Pod の情報を元に systemd ユニットファイルを生成します。次のコマンドで `pod-redminepod.service` ユニットファイルとその依存ユニットファイルが生成されます。

```
$ cd ~/.config/systemd/user/
$ podman generate systemd --name redminepod --files --restart-policy=always
```

### 7. Redmine サービスを登録し起動する

次のコマンドで Redmine サービスを有効にし起動します。

```
$ systemctl --user enable pod-redminepod
$ systemctl --user start pod-redminepod
```

## Redmine Pod にデータをリストアする。

Redmine サービスを復旧させるには、DBデータとRedmineコンテンツの添付ファイル群をリストアする必要があります。

### バックアップファイルの取得

gooid-30 サイトにある Redmine のバックアップファイルを gooid-21 サイトのコンテナホストに持ってくることを想定し説明します。

#### 1. SSH転送ルートの設定

ファイルはSSH転送ルートを .ssh/config に記述し、scp コマンドで取得します。以下のような SSH設定を .ssh/config に作ります。

※ユーザーはダミーですが、両サイトで同一の公開鍵で認証するログイン権限を持つユーザーである前提です。IPは本資料執筆時点の物です。

``` .ssh/config
Host *
  ForwardAgent yes
  TCPKeepAlive yes
  ServerAliveInterval 60

# バックアップファイルが保存されている gooid-30 上のホスト
Host gooid-30-dev-log-002
  User scp-user
  Port 22
  ProxyJump gooid-30-bastion

# R-Cloud bastion
Host gooid-30-bastion
  HostName ssh.rc1.pf.goo.ne.jp
  Port 22
  User scp-user
  ProxyJump gooid-21-bastion

# Mitaka-DC bastion
Host gooid-21-bastion
  HostName 172.25.19.147   # internal IP
  User scp-user
  Port 22
```

#### 2. バックアップファイルの取得

バックアップファイルはそれぞれ次のファイル名で格納されています。

* DBデータバックアップファイルのパス:  
"/db0/mysql/mysql-on-$REDMINE_HOST-$DATA_VERSION.sql.gz"

* Redmine添付バックアップファイルのパス:  
"/db0/redmine_files/redmine-data-on-$REDMINE_HOST-$DATA_VERSION.tar.gz"

ここで、  
`REDMINE_HOST` -- Redmineを運用しているホスト名。つまりバックアップ元ホスト  
`DATA_VERSION` -- 通常バックアップを実施した YYYYMMDD 書式の日付  
です。

上記より以下のような scp コマンドをコンテナホストで実行することでバックアップファイルを取得できることになります
```
$ scp gooid-30-dev-log-002:/db0/redmine_files/redmine-data-on-gooid-30-dev-redmine-001-20250707.tar.gz .
$ scp gooid-30-dev-log-002:/db0/mysql/mysql-on-gooid-30-dev-redmine-001-20250707.sql.gz .
```

が、実際はSSH接続ユーザーは直接バックアップファイルにアクセスできません。必要な手続きを含むスクリプトを作成したので以下に示します。これらのコマンドはデフォルトで最新の DATA_VERSION を持つバックアップファイルを取得します。

get_redmine_backup.sh
```bash
#!/usr/bin/env bash
# -- get_redmine_backup.sh
#    Retrive redmine backup files from redmine backup server.
#
# usage:
#   get_redmine_backup.sh [DATA_VERSION]
#
#   DATA_VERSION: YYYYMMDD format date string or 'latest'.
#
set -uo pipefail

# Backup file name: "redmine-data-on-$REDMINE_HOST-$DATA_VERSION.tar.gz"
REDMINE_HOST=gooid-30-pro-redmine-002
BACKUP_HOST=gooid-30-dev-log-002

DEFAULT_VERSION=$(date +%Y%m%d)
if [ "${1:-latest}" == "latest" ]; then
  LATESTCMD="cd /db0/redmine_files && ls -1 redmine-data-on-$REDMINE_HOST-*.tar.gz | sort -r | head -n 1"
  BACKUP_FILE_NAME=$(ssh $BACKUP_HOST "$LATESTCMD")
  if [[ -z "$BACKUP_FILE_NAME" ]];then
    echo "remote process failed on $BACKUP_HOST: CMD='$LATESTCMD'"
    exit 1
  fi
  echo "Latest backup file is '$BACKUP_FILE_NAME'"
else
  DATA_VERSION=${1:-$DEFAULT_VERSION}
  BACKUP_FILE_NAME="redmine-data-on-$REDMINE_HOST-$DATA_VERSION.tar.gz"
fi


# copy redmine backup file from BACKUP_HOST
TMPCOPYCMD="TMPFILE=\$(mktemp) && ( sudo cp /db0/redmine_files/$BACKUP_FILE_NAME \$TMPFILE && echo \$TMPFILE ) || (rm \$TMPFILE ; echo '')"
REMOTE_TMPFILE=$(ssh $BACKUP_HOST "$TMPCOPYCMD")
if [[ -z "$REMOTE_TMPFILE" ]]; then
  echo "remote process failed on $BACKUP_HOST: CMD='$TMPCOPYCMD'"
  exit 1
fi

#LOCAL_TMPFILE=$(mktemp)
LOCAL_TMPFILE="."
LOCALFILE="./$BACKUP_FILE_NAME"
scp $BACKUP_HOST:"$REMOTE_TMPFILE" "$LOCALFILE" > /dev/null
echo $LOCALFILE
ssh $BACKUP_HOST "rm '$REMOTE_TMPFILE'"

#EOS
```

get_redmine_db_backup.sh
```bash
#!/usr/bin/env bash
# -- get_redmine_db_backup.sh
#    Retrive redmine mysql db backup files from redmine backup server.
#
# usage:
#   get_redmine_db_backup.sh [DATA_VERSION]
#
#   DATA_VERSION: YYYYMMDD format date string or 'latest'.
#
set -uo pipefail

# Backup file name: "mysql-on-$REDMINE_HOST-$DATA_VERSION.sql.gz"
REDMINE_HOST=gooid-30-pro-redmine-002
BACKUP_HOST=gooid-30-dev-log-002

DEFAULT_VERSION=$(date +%Y%m%d)
if [ "${1:-latest}" == "latest" ]; then
  LATESTCMD="cd /db0/mysql && ls -1 mysql-on-$REDMINE_HOST-*.sql.gz | sort -r | head -n 1"
  BACKUP_FILE_NAME=$(ssh $BACKUP_HOST "$LATESTCMD")
  if [[ -z "$BACKUP_FILE_NAME" ]];then
    echo "remote process failed on $BACKUP_HOST: CMD='$LATESTCMD'"
    exit 1
  fi
  echo "Latest backup file is '$BACKUP_FILE_NAME'"
else
  DATA_VERSION=${1:-$DEFAULT_VERSION}
  BACKUP_FILE_NAME="mysql-on-$REDMINE_HOST-$DATA_VERSION.sql.gz"
fi


# copy redmine backup file from BACKUP_HOST
TMPCOPYCMD="TMPFILE=\$(mktemp) && ( sudo cp /db0/mysql/$BACKUP_FILE_NAME \$TMPFILE && echo \$TMPFILE ) || (rm \$TMPFILE ; echo '')"
REMOTE_TMPFILE=$(ssh $BACKUP_HOST "$TMPCOPYCMD")
if [[ -z "$REMOTE_TMPFILE" ]]; then
  echo "remote process failed on $BACKUP_HOST: CMD='$TMPCOPYCMD'"
  exit 1
fi

#LOCAL_TMPFILE=$(mktemp)
LOCAL_TMPFILE="."
LOCALFILE="./$BACKUP_FILE_NAME"
scp $BACKUP_HOST:"$REMOTE_TMPFILE" "$LOCALFILE" > /dev/null
echo $LOCALFILE
ssh $BACKUP_HOST "rm '$REMOTE_TMPFILE'"

#EOS
```


#### 3. Redmine添付ファイルバックアップのリストア

コンテナホストに取得したバックアップファイル `redmine-data-on-gooid-30-dev-redmine-001-20250707.tar.gz` がカレントディレクトリにある想定で、以下にリストア手順を示します。

※リストア作業時にRedmineサービスが使用中でなければ、サービスを停止する必要はありません。停止する場合は以下のコマンドを実行します。

```
$ systemctl --user stop pod-redminepod.service
```

#### 3-1. redmine_files ボリュームのマウントポイント(ディレクトリ)の取得

コンテナユーザーで podman volume inspect コマンドを実行し、添付ファイルを格納するディレクトリとそのディレクトリ オーナーの UID,GID を取得します。

```
$ sudo -u container_user -s
$ cd ~
$ podman volume inspect redmine_files | jq -r '.[0].Mountpoint'
/opt/containers/.local/share/containers/storage/volumes/redmine_files/_data
$ ls -la /opt/containers/.local/share/containers/storage/volumes/redmine_files/_data
合計 0
drwxr-xr-x 2         100998         100998  6  9月 13  2022 .
drwx------ 3 container_user container_user 19  7月  7 11:31 ..
$ exit
$
```

#### 3-2. バックアップファイルの展開とボリュームへのコピー

バックアップファイルをカレントディレクトリに展開した後、ボリュームへコピーします。

```
$ tar zxf redmine-data-on-gooid-30-dev-redmine-001-20250707.tar.gz
```

カレントディレクトリに展開された redmine_files ディレクトリ下のファイルをボリュームへコピーし、UID,GIDを調整します。

```
$ sudo rsync -a ./redmine_files/ /opt/containers/.local/share/containers/storage/volumes/redmine_files/_data/
$ sudo chown -R 100998:100998 /opt/containers/.local/share/containers/storage/volumes/redmine_files/_data/
$ rm -rf redmine_files
```


#### 4. DBのバックアップのリストア

カレントディレクトリにDBバックアップ `mysql-on-gooid-30-dev-redmine-001-20250707.sql.gz` カレントディレクトリにある想定で、以下にリストア手順を示します。

#### 4-1. コンテナユーザーで操作するため、バックアップファイルをコピーする

以下のようにバックアップファイルをコピーしコンテナユーザーで作業します。

```
$ sudo mkdir -p /opt/containers/redmine/backups
$ sudo cp mysql-on-gooid-30-dev-redmine-001-20250707.sql.gz /opt/containers/redmine/backups/
$ sudo -u container_user -s
$ cd /opt/containers/redmine/backups
```

#### 4-2. DBコンテナのみ起動し、DBをリストアする

```
$ systemctl --user stop pod-redminepod.service
$ podman start redminepod-redminedb
$ zcat mysql-on-gooid-30-dev-redmine-001-20250707.sql.gz  | podman exec -i redminepod-redminedb mysql -u root -prootpw
$ podman stop redminepod-redminedb
```

#### 5. Redmine サービスの起動

Redmineサービスを起動し、アクセスできることを確認する

```
$ systemctl --user start pod-redminepod
$ systemctl --user status pod-redminepod
```

サービスが起動していることが確認できたら curl コマンドで Redmine へのアクセスを確認します。

```
$ curl -i http://localhost:3000/ticket
HTTP/1.1 302 Found
X-Frame-Options: SAMEORIGIN
X-XSS-Protection: 1; mode=block
X-Content-Type-Options: nosniff
X-Download-Options: noopen
X-Permitted-Cross-Domain-Policies: none
Referrer-Policy: strict-origin-when-cross-origin
Content-Type: text/html; charset=utf-8
Location: http://localhost:3000/ticket/login?back_url=http%3A%2F%2Flocalhost%3A3000%2Fticket
Cache-Control: no-cache
X-Request-Id: 795f328d-9843-463a-9702-39435e9da159
X-Runtime: 0.055390
Content-Length: 150

<html><body>You are being <a href="http://localhost:3000/ticket/login?back_url=http%3A%2F%2Flocalhost%3A3000%2Fticket">redirecte
```

上記のように /ticket/login へのリダイレクトが返れば正常です。


## リバースプロキシの設定

Redmine サービスへのWebアクセスはリバースプロキシ経由で行います。
リバースプロキシには以下のような設定が必要です。

前提：  
公開ホスト名： container.wbo110.goo.ne.jp  
コンテナホスト名： gooid-21-dev-container-101 (内部名)

* Apache 2.4 httpd

/etc/httpd/conf.d/container.wbo110.goo.ne.jp.conf 抜粋

```
    <Location /ticket>
        ProxyPass http://gooid-21-dev-container-101:3000/ticket nocanon
        ProxyPassReverse http://gooid-21-dev-container-101:3000/ticket
    </Location>
```


## 以上
