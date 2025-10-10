# Podman 上で Gitea サービスコンテナを構成する

この資料は Gitea サービスを Podman コンテナにデプロイする手順をまとめたものです。
特に Podman rootless コンテナで運用する方針に従うため docker-compose (podman-compose) は使用できず代わりに Podman Pod を使う必要があります。本資料は docker-compose.yml を元に Podman Pod 化する手順を記述しています。

## podman-compose ではなく Podman Pod を使う

### コンテナ間ネットワークの問題

Podman の rootless 環境ではコンテナにIPが割り当てられないという制限があり、そのためこれまで docker-compose で構成してきた Gitea と MySQL コンテナ間をサービス名で接続する方法が取れません。
関連する複数のコンテナを Pod としてまとめることにより、localhost:PORT で各コンテナのサービスにアクセスすることができます。

## Podman Pod によるサービス構築

Gitea サービスは最終的に systemd による稼働管理を行いますが、Podman Pod で構成する場合は従来のように記述済みのユニットファイルを配布することができず、代わりに `podman generate systemd` コマンドにより、実行中の Pod からユニットファイルを生成します。したがって最終的に構成される playbook タスクが若干複雑です。

※より正確には不可能ではなく、Podman 4.6 以降の Quadlet により事前に記述したサービス設定から systemd ユニットを自動生成させることができます。
しかし現時点では安定版リリースである 4.0 に限定するため Quadlet は利用できません。  
参考：[14.4. podman generate systemd コマンドではなく Quadlet を使用する利点](https://docs.redhat.com/ja/documentation/red_hat_enterprise_linux/9/html/building_running_and_managing_containers/advantages-of-using-quadlets-over-the-podman-generate-systemd-command_assembly_porting-containers-to-systemd-using-podman)

## 手順概要

構築作業は元の gitea サービスホストから入手した docker-compose.yml ファイルの情報を元に行います。

大まかな手順は以下の通りです。

1. [元の docker-compose.yml から情報を入手する](#1.-元の-docker-compose.yml-から情報を入手する)
2. [コンテナイメージ、ボリューム、Pod を作成し、Pod に gitea, mysql コンテナを登録する](#2.-コンテナイメージ、ボリューム、Pod-を作成し、Pod-に-Gitea,-Mysql-コンテナを登録する)
3. [Pod から Kubernetes YAML ファイルを生成する](#3.-Pod-から-Kubernetes-YAML-ファイルを生成する)
4. [Gitea Pod を元に systemd ユニットファイルを生成する](#4.-Gitea-Pod-を元に-systemd-ユニットファイルを生成する)

## 手順詳細

### 1. 元の docker-compose.yml から情報を入手する

gitea 運用ホスト (gooid-30-pro-gitea-003) から入手した docker-compose.yml ファイルは以下の通りです。

/home/gitea/docker-compose.yml

```
version: "3"

networks:
  gitea:
    external: false

volumes:
  gitea:
    driver: local
  mysql:
    driver: local

services:
  server:
    image: gitea/gitea:1.20.3
    container_name: gitea-web
    logging:
      driver: syslog
      options:
        syslog-facility: local6
        tag: "{{.Name}}"
    environment:
      - USER=git
      - USER_UID=1001
      - USER_GID=1001
      - GITEA__database__DB_TYPE=mysql
      - GITEA__database__HOST=db:3306
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__database__PASSWD=gitea
      - GITEA__database__CHARSET=utf8mb4
      - GITEA__server__DOMAIN=repo.id001.goo.ne.jp
      - GITEA__server__SSH_DOMAIN=gooid-30-pro-gitea-001
      - GITEA__server__PROTOCOL=http
      - GITEA__server__HTTP_PORT=3001
      - GITEA__server__SSH_PORT=2222
      - GITEA__server__START_SSH_SERVER=true
      - GITEA__server__SSH_LISTEN_PORT=2222
      - GITEA__server__BUILTIN_SSH_SERVER_USER=git
      - GITEA__server__ROOT_URL=https://repo.id001.goo.ne.jp/
      - GITEA__log__MODE=console, file
      - GITEA__log__LEVEL=Trace
      - GITEA__log__STACKTRACE_LEVEL=Critical
      - GITEA__log__ROUTER_LOG_LEVEL=Debug
      - GITEA__log__ENABLE_ACCESS_LOG=true
      - GITEA__log__ENABLE_SSH_LOG=true
      - GITEA__log__ACCESS=file
      - GITEA__log__COLORIZE=false
      - GITEA__log.console__LEVEL=Debug
      - GITEA__log.console__COLORIZE=false
      - GITEA__log.file__LEVEL=Trace
      - GITEA__log.file__FILE_NAME=trace.log
      - GITEA__log.file__MAX_DAYS=40
      - GITEA__log.file__COLORIZE=false
      - GITEA__mailer__ENABLED=true
      - GITEA__mailer__HOST=172.17.255.238:25
      - GITEA__mailer__FROM=gitea@nttr.co.jp
      - GITEA__mailer__MAILER_TYPE=smtp
      - GITEA__service__ENABLE_NOTIFY_MAIL=true
      - GITEA__admin__DEFAULT_EMAIL_NOTIFICATIONS=enabled
      - GITEA__proxy__PROXY_ENABLED=true
      - GITEA__proxy__PROXY_URL=http://172.17.255.232:8080
      - GITEA__proxy__PROXY_HOSTS=**
      - GITEA__webhook__ALLOWED_HOST_LIST=*
      - GITEA__webhook__PROXY_URL=http://172.17.255.232:8080
      - GITEA__webhook__PROXY_HOSTS=**
      - TMPDIR=/backup
      - HTTP_PROXY=http://172.17.255.232:8080
      - HTTPS_PROXY=http://172.17.255.232:8080
    networks:
      - gitea
    volumes:
      - gitea:/data
      - ./backup:/backup
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "3001:3001"
      - "2222:2222"
    depends_on:
      - db

  db:
    image: mysql:5.7
    container_name: gitea-db
    logging:
      driver: syslog
      options:
        syslog-facility: local6
        tag: "{{.Name}}"
    environment:
      - MYSQL_ROOT_PASSWORD=gitea
      - MYSQL_USER=gitea
      - MYSQL_PASSWORD=gitea
      - MYSQL_DATABASE=gitea
    networks:
      - gitea
    volumes:
      - mysql:/var/lib/mysql
```



### 2. コンテナイメージ、ボリューム、Pod を作成し、Pod に Gitea, MySQL コンテナを登録する

まず、コンテナホストに Gitea コンテナディレクトリを作成し、そこに必要なファイルを作成します。以下は最終的なリソースファイルを含むディレクトリ構成は以下の通りです。

```
/opt/containers/gitea
├── Containerfile
├── containers.conf
├── giteapod.yml
├── mysql
│   ├── Containerfile
│   └── my.cnf
├── storage.conf
├── subgid
└── subuid
```

以降、作業時のカレントディレクトリは `/opt/containers/gitea` を前提とします。

実行例：

```
$ sudo -i -u container_user
$ mkdir gitea
:
```


#### Gitea イメージのビルド

Gitea イメージのビルド用 Containerfile を作り podman build コマンドでイメージ `gitea-podman:1.24.3` を作ります。  
※タグのマイナーバージョン以降を Gitea バージョン 24.3 に合わせています

[gitea/Containerfile](./templates/gitea/Containerfile.j2)


```
$ podman build -t gitea-podman:1.24.3 -f Containerfile .
```

#### MySQL イメージのビルド

MySQL イメージのビルド用 Containerfile を作り podman build コマンドでイメージ `gitea_db-podman:1.8.4` を作ります。  
※タグのマイナーバージョン以降を MySQL バージョン 8.4 に合わせています

mysql ディレクトリには my.cnf も配置します。

[mysql/Containerfile](./templates/mysql/Containerfile.j2)

[mysql/my.cnf](./files/mysql/my.cnf)

```
$ podman build -t gitea_db-podman:1.8.4 -f ./mysql/Containerfile ./mysql
```

#### コンテナ設定ファイルの作成

コンテナ実行時の設定ファイルを作成します。

[containers.conf](./templates/containers.conf.j2)

[storage.conf](./files/storage.conf)

[subgid](./files/subgid)

[subuid](./files/subuid)



#### ボリュームの作成

`gitea_data`, `gitea_backup`, `gitea_db_data` の3つのボリュームを作成します。

```
$ podman volume create gitea_db_data

$ podman volume create gitea_data

$ podman volume create gitea_backup
```


#### Gitea Pod の作成

コンテナを収容する Pod `giteapod` を作成します。ポートマッピングはコンテナではなく Pod に行います。

```
$ podman pod create --name giteapod --publish 3001:3001 --publish 2222:2222
```


#### Gitea Pod に Gitea と MySQL のコンテナを登録する

作成した `giteapod` に Gitea コンテナと MySQL コンテナを登録します。この時コンテナ実行に必要な環境変数を渡します。

```
$ podman run --detach --pod giteapod \
 --env MYSQL_DATABASE=gitea \
 --env MYSQL_ROOT_PASSWORD=gitea \
 --env MYSQL_USER=gitea \
 --env MYSQL_PASSWORD=gitea \
 --volume gitea_db_data:/var/lib/mysql \
 --name gitea_db localhost/gitea_db-podman:1.8.4 mysqld
```

```
$ podman run --detach --pod giteapod \
--env USER=git \
--env USER_UID=1001 \
--env USER_GID=1001 \
--env GITEA__database__DB_TYPE=mysql \
--env GITEA__database__HOST=localhost:3306 \
--env GITEA__database__NAME=gitea \
--env GITEA__database__USER=gitea \
--env GITEA__database__PASSWD=gitea \
--env GITEA__database__CHARSET=utf8mb4 \
--env GITEA__server__DOMAIN=container.wbo110.goo.ne.jp \
--env GITEA__server__SSH_DOMAIN=gooid-21-dev-container-101 \
--env GITEA__server__PROTOCOL=http \
--env GITEA__server__HTTP_PORT=3001 \
--env GITEA__server__SSH_PORT=2222 \
--env GITEA__server__START_SSH_SERVER=true \
--env GITEA__server__SSH_LISTEN_PORT=2222 \
--env GITEA__server__BUILTIN_SSH_SERVER_USER=git \
--env GITEA__server__ROOT_URL=https://container.wbo110.goo.ne.jp/repo/ \
--env GITEA__log__MODE=console,file \
--env GITEA__log__LEVEL=Trace \
--env GITEA__log__STACKTRACE_LEVEL=Critical \
--env GITEA__log__ROUTER_LOG_LEVEL=Debug \
--env GITEA__log__ENABLE_ACCESS_LOG=true \
--env GITEA__log__ENABLE_SSH_LOG=true \
--env GITEA__log__ACCESS=file \
--env GITEA__log__COLORIZE=false \
--env GITEA__log.console__LEVEL=Debug \
--env GITEA__log.console__COLORIZE=false \
--env GITEA__log.file__LEVEL=Trace \
--env GITEA__log.file__FILE_NAME=trace.log \
--env GITEA__log.file__MAX_DAYS=40 \
--env GITEA__log.file__COLORIZE=false \
--env GITEA__mailer__ENABLED=true \
--env GITEA__mailer__SMTP_ADDR=172.17.255.238:25 \
--env GITEA__mailer__FROM=gitea@nttr.co.jp \
--env GITEA__mailer__PROTOCOL=smtp \
--env GITEA__service__ENABLE_NOTIFY_MAIL=true \
--env GITEA__admin__DEFAULT_EMAIL_NOTIFICATIONS=enabled \
--env GITEA__proxy__PROXY_ENABLED=true \
--env GITEA__proxy__PROXY_URL=http://10.23.110.100:10000 \
--env GITEA__proxy__PROXY_HOSTS=** \
--env GITEA__webhook__ALLOWED_HOST_LIST=* \
--env GITEA__webhook__PROXY_URL=http://10.23.110.100:10000 \
--env GITEA__webhook__PROXY_HOSTS=** \
--env TMPDIR=/backup \
--env HTTP_PROXY=http://10.23.110.100:10000 \
--env HTTPS_PROXY=http://10.23.110.100:10000 \
--volume gitea_data:/data \
--volume gitea_backup:/backup \
--name gitea localhost/gitea-podman:1.24.3
```

※ここで `GITEA` から始まる変数は、GITEA__Section__Key=Value と判断され、gitea/conf/app.ini に格納されます（ただし app.ini が存在しなかった場合）  
ただし、app.ini は最終的にデータリストア時に上書きされるので、この時点ではコンテナの初期起動に問題が出なければ良いです。




### 3. Pod から Kubernetes YAML ファイルを生成する

`giteapod.yml` を生成します。

```
$ podman generate kube giteapod > giteapod.yml
```


次に、giteapod Podが問題なく起動できることを確認します。

```
$ podman pod stop giteapod
$ podlan play kube giteapod.yml
$ podman pod ps | grep giteapod | grep Running
```

giteapod, Running を含む行が表示されれば正常です。


### 4. Gitea Pod を元に systemd ユニットファイルを生成する

構築した Gitea Pod の情報を元に systemd ユニットファイルを生成します。次のコマンドで `pod-giteaepod.service` ユニットファイルとその依存ユニットファイルが生成されます。

```
$ cd ~/.config/systemd/user/
$ podman generate systemd --name giteapod --files --restart-policy=always
```

次のコマンドで Gitea サービスを有効にし起動します。

```
$ podman pod stop giteapod
$ systemctl --user enable pod-giteapod
$ systemctl --user start pod-giteapod
```

## Gitea Pod にデータをリストアする

Gitea サービスを運用中のバックアップファイルから復旧します。

### バックアップファイルの取得

gooid-30 サイトにある Gitea のバックアップファイルを gooid-21 サイトのコンテナホストに持ってくることを想定し説明します。

#### 1. SSH転送ルートの設定

ファイルはSSH転送ルートを .ssh/config に記述し、scp コマンドで取得します。以下のような SSH設定を .ssh/config に作ります。

※ユーザーはダミーですが、両サイトで同一の公開鍵で認証するログイン権限を持つユーザーである前提です。IPは本資料執筆時点の物です。

``` .ssh/config
Host *
  ForwardAgent yes
  TCPKeepAlive yes
  ServerAliveInterval 60

# バックアップファイルが保存されている gooid-30 上のホスト
Host gooid-30-*
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

バックアップファイルは gooid-30-pro-gitea-004 に次のファイル名で格納されています。

* バックアップファイルのパス:  
/home/gitea/backup/gitea-dump-$TIMESTAMP.zip

ここで、  
`TIMESTAMP` -- バックアップ日時のエポック秒  
です。

まず準備として、gitea_backup ボリュームへのシンボリックリンクを container_user の gitea ディレクトリ下に作成します。  
container_user で次のスクリプトを実行します。

/opt/containers/gitea/mkln_backup_volume.sh

```
#!/usr/bin/env bash

set -euo pipefail

VOLUME_NAME=gitea_backup

MOUNT_POINT=$(podman volume inspect $VOLUME_NAME | jq -r ".[] | select(.Name == \"$VOLUME_NAME\") | .Mountpoint")

echo "Make a symbolic link: ./backup -> $MOUNT_POINT"

ln -sfn $MOUNT_POINT ./backup

#EOS
```

実行例：

```
$ sudo -i -u container_user
$ cd /opt/containers/gitea
$ mkln_backup_volume.sh
$ exit
```


最新のバックアップファイルを取得し、gitea_backup ボリュームにコピーするスクリプトを以下に示します。  
このスクリプトは container_user ではなく通常ユーザーで実行してください。

get_gitea_backup.sh

```bash
#!/usr/bin/env bash
# -- get_gitea_backup.sh
#    Retrive gitea backup files from Gitea backup server.
#
# usage:
#   get_gitea_backup.sh [TIMESTAMP]
#
#   TIMESTAMP: \d{10} format epoch time string or 'latest'.
#
set -uo pipefail

# Backup file name: "gitea-dump-$TIMESTAMP.zip"
GITEA_HOST=gooid-30-pro-gitea-003
BACKUP_HOST=gooid-30-pro-gitea-004
BACKUP_DIR=/home/gitea/backup

DEFAULT_VERSION=$(date +%s)  # これで取得できるバックアップファイルは有り得ない。初期値として入れているだけ
if [ "${1:-latest}" == "latest" ]; then
  LATESTCMD="cd $BACKUP_DIR && ls -1 gitea-dump-*.zip | sort -r | head -n 1"
  BACKUP_FILE_NAME=$(ssh $BACKUP_HOST "$LATESTCMD")
  if [[ -z "$BACKUP_FILE_NAME" ]];then
    echo "remote process failed on $BACKUP_HOST: CMD='$LATESTCMD'"
    exit 1
  fi
  echo "Latest backup file is '$BACKUP_FILE_NAME'"
else
  DATA_VERSION=${1:-$DEFAULT_VERSION}
  BACKUP_FILE_NAME="gitea-dump-$DATA_VERSION.zip"
fi


# copy gitea backup file from BACKUP_HOST
TMPCOPYCMD="TMPFILE=\$(mktemp) && ( sudo cp $BACKUP_DIR/$BACKUP_FILE_NAME \$TMPFILE && echo \$TMPFILE ) || (rm \$TMPFILE ; echo '')"
REMOTE_TMPFILE=$(ssh $BACKUP_HOST "$TMPCOPYCMD")
if [[ -z "$REMOTE_TMPFILE" ]]; then
  echo "remote process failed on $BACKUP_HOST: CMD='$TMPCOPYCMD'"
  exit 1
fi

#LOCAL_TMPFILE=$(mktemp)
LOCAL_TMPFILE="."
LOCALFILE="./$BACKUP_FILE_NAME"
scp $BACKUP_HOST:"$REMOTE_TMPFILE" "$LOCALFILE" > /dev/null
# echo $LOCALFILE
ssh $BACKUP_HOST "rm '$REMOTE_TMPFILE'"

# move Backup file to backup volume
BACKUP_VOLUME_DIR=/opt/containers/gitea/backup
sudo mv -f $LOCALFILE $BACKUP_VOLUME_DIR/
sudo chown container_user:container_user $BACKUP_VOLUME_DIR/$BACKUP_FILE_NAME

echo $BACKUP_VOLUME_DIR/$BACKUP_FILE_NAME

#EOS
```



#### 3. バックアップファイルを展開する

container_user でバックアップファイルを展開します。

/opt/containers/gitea/backup/extract.sh

```
#!/usr/bin/env bash
# -- extract.sh
#    Extract files into a directory named using the specified zip file (without extension).
#
# Usage:
#    ./extract.sh <ZIP_FILE_NAME>
#
set -euo pipefail

ZIP_NAME=${1:-}

if [[ -z "$ZIP_NAME" ]]; then
  echo "-- Extract files into a directory named using the specified zip file (without extension) --"
  echo "Usage:"
  echo "  ./extract.sh <ZIP_FILE_NAME>"
  exit 1
fi

EXTRACT_DIR=$(basename -s .zip "$ZIP_NAME")

date
pwd

echo "unzip -d $EXTRACT_DIR $ZIP_NAME"
unzip -d $EXTRACT_DIR $ZIP_NAME

#EOS
```

実行例：

```
$ sudo -i -u container_user
$ cd ./gitea/backup
$ ./extract.sh gitea-dump-1753800602.zip
```

#### 4. Gitea DB データのリストア

展開したバックアップファイルに含まれる gitea-db.sql でDBをリストアします。リストア用に次のスクリプトを使います。

/opt/containers/gitea/svc.sh

```
#!/usr/bin/env bash
# -- svc.sh
#    Start|Stop|Restart pod-giteapod.service

set -euo pipefail

SERVICE="pod-giteapod"

ACTION="${1:-status}"

case "$ACTION" in
  start|stop|restart)
    echo "systemctl --user $ACTION $SERVICE"
    systemctl --user $ACTION $SERVICE
    ;;
  status)
    echo "systemctl --user --no-pager --full status $SERVICE"
    systemctl --user --no-pager --full status $SERVICE
    ;;
  *)
    echo "Invalid action: $ACTION" >&2
    echo "Usage:"
    echo "   ./svc.sh [start|stop|restart|status] <- status is default"
    exit 1
    ;;
esac

# EOS
```

/opt/containers/gitea/restoredb.sh

```
#!/usr/bin/env bash
# -- restoredb.sh
#    Restore the Gitea DB data
#
# Usage:
#    ./restoredb.sh <PATH_OF_gitea-db.sql>
#
# 実行前にGitea Pod 内のDBコンテナのみが起動している状態にしてください。
#
set -euo pipefail

SQL_FILE=${1:-}

if [[ -z "$SQL_FILE" ]]; then
  echo "-- Resotre Gitea DB data --"
  echo "Usage:"
  echo "  ./restoredb.sh <PATH_OF_gitea-db.sql>"
  exit 1
fi

GITEA_DB_RUNNING=$( (podman ps | grep -w giteapod-giteadb) || true)
if [[ -z "$GITEA_DB_RUNNING" ]]; then
  echo "Gitea DB コンテナが起動していません。"
  echo "./svc.sh stop でGiteaサービスを停止した後、podman start giteapod-giteadb で起動してください。"
  exit 1
fi

GITEA_RUNNING=$( (podman ps | grep -w giteapod-gitea) || true)
if [[ -n "$GITEA_RUNNING" ]]; then
  echo "Gitea コンテナが起動している状態ではDBリストアできません。"
  echo "./svc.sh stop でGiteaサービスを停止するか、サービス停止後に起動した場合は podman stop giteapod-gitea で停止してください。"
  exit 1
fi


if [[ ! -f "$SQL_FILE" ]]; then
  echo "リストア対象のDBファイルが見つかりませんでした: '$SQL_FILE'"
  exit 1
fi


echo "Restoreing Gitea DB data from '$SQL_FILE'."


podman exec -i giteapod-giteadb mysql --default-character-set=utf8mb4 -u gitea -pgitea gitea < "$SQL_FILE"

echo "Restore done."

# EOS
```

DBデータをリストアするために、MySQLコンテナのみが起動した状態にします。

実行例：

```
$ cd /opt/containers/gitea
$ ./svc.sh stop
$ podman start giteapod-giteadb
$ ./restoredb.sh ./backup/gitea-dump-1753800602/gitea-db.sql
```

#### 5. Gitea データのリストア

DBに続けて、データをリストアします。リストアは container_user ではなく通常ユーザーで次のスクリプトを実行します。

restoredata.sh

```
#!/usr/bin/env bash
# -- restoredata.sh
#    Restore the Gitea data
#
# Usage:
#    ./restoredata.sh <PATH_OF_EXTRACTED>
#
# 注意）
#   ・このスクリプトは通常ユーザーで実行してください。 container_user では実行できません。
#
# 　・実行前にGitea Pod 内のGiteaコンテナが起動していない状態にしてください。
#
set -euo pipefail

PATH_EXTRACTED=${1:-}

if [[ -z "$PATH_EXTRACTED" ]]; then
  echo "-- Resotre Gitea data --"
  echo "Usage:"
  echo "  ./restoredata.sh <PATH_OF_EXTRACTED>"
  exit 1
fi

CONTAINER_USER=container_user

if [[ "$USER" == "$CONTAINER_USER" ]]; then
  echo "ユーザー '$CONTAINER_USER' では実行できません。"
  echo "sudo 実行権限を持つユーザーのワークにこの restoredata.sh をコピーしてから実行してください。"
  exit 1
fi


GITEA_RUNNING=$(sudo -i -u "$CONTAINER_USER" podman ps | grep -w giteapod-gitea || true)
if [[ -n "$GITEA_RUNNING" ]]; then
  echo "Gitea コンテナが起動している状態ではデータをリストアできません。"
  echo "./svc.sh stop でGiteaサービスを停止するか、サービス停止後に起動した場合は podman stop giteapod-gitea で停止してください。"
  exit 1
fi


if sudo -u "$CONTAINER_USER" test ! -d "$PATH_EXTRACTED"; then
  echo "リストア対象のバックアップファイルを展開したディレクトリが見つかりませんでした: '$PATH_EXTRACTED'"
  exit 1
fi


SRCDIR="$PATH_EXTRACTED"
VOLUME_NAME=gitea_data
DSTDIR=$(sudo -i -u "$CONTAINER_USER" podman volume inspect "$VOLUME_NAME" | jq -r ".[] | select(.Name == \"$VOLUME_NAME\") | .Mountpoint")

UID_GIT=101000


echo "Restoreing Gitea data from '$SRCDIR' to '$DSTDIR'"

sudo rsync -a "$SRCDIR/data/" "$DSTDIR/gitea/"

sudo rsync -a "$SRCDIR/log/" "$DSTDIR/gitea/log/"

sudo chown -R $UID_GIT:$UID_GIT "$DSTDIR/gitea/"


sudo rsync -a "$SRCDIR/repos/" "$DSTDIR/git/repositories/"

sudo chown -R $UID_GIT:$UID_GIT $DSTDIR/git/repositories


echo "Restore done."

# EOS
```

データのリストアは gitea コンテナが起動していない状態で行います。

実行例：

```
$ ./restoredata.sh /opt/containers/gitea/backup/gitea-dump-1753800602
```

データのリストアが完了したらGiteaサービスを起動します。

```
$ sudo -i -u container_user
$ cd gitea
$ ./svc.sh start
```


#### 6. Giteaサービスの調整

Gitea の設定は giteapod-gitea コンテナ内の /data/gitea/conf/app.ini を稼働環境に応じて調整が必要です。  
以下に調整対象の項目を列挙します。

* [server] セクション
  * SSH_DOMAIN = gooid-21-dev-container-101
* [mailer] セクション
  * SMTP_ADDR = 172.17.255.238:25
  * HOST = 172.17.255.238:25


## リバースプロキシの設定

Gitea サービスへのWebアクセスはリバースプロキシ経由で行います。
リバースプロキシには以下のような設定が必要です。

前提：  
公開ホスト名： container.wbo110.goo.ne.jp  
コンテナホスト名： gooid-21-dev-container-101 (内部名)

* Apache 2.4 httpd

/etc/httpd/conf.d/container.wbo110.goo.ne.jp.conf 抜粋

```
    <Location /repo>
        ProxyPass http://gooid-21-dev-container-101:3000 nocanon
    </Location>
```



## 以上
