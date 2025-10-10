# Ansible Role: container

このロールは RockyLinux や RHEL ベースのシステムに対して、
`container-tools:rhel8` モジュールストリームを有効化し、関連パッケージグループをインストールします。
docker-compose と podman-compose 両方入れているのでどちらも使えます。  

## 対応環境

- OS: RockyLinux 8+, RHEL 8+
- 必須パッケージ: dnf
- 権限: root（become を使用）

## インストールされるツール群

このロールでは以下のようなツールが含まれる `@container-tools:rhel8` パッケージグループが一括インストールされます：

- podman
- buildah
- skopeo
- fuse-overlayfs
- quadlet
- containers-common など

## 使い方

```yaml
- name: コンテナホスト 
  hosts: gooid_container
  environment: "{{ proxy_env }}"
  roles:
    - role: container
```
## コンテナ実行環境について

### コンテナ実行ユーザ

container_user  
uid=1000  
gid=1000     
ホームディレクトリは/opt/containers です  

### マウントタイプ

ファイルやディレクトリをホストマシンとコンテナとで共有させる手段として
主にPodman Volumeとbind mountがありますが
原則Podman Volumeを採用しています。  
ボリュームの管理をホストマシンではなく、
Podmanによって行われるためrootless環境下で発生しがちな問題解決（主にネームスペースの整合性）を
オフロードしてくれることを期待して採用しています。  
マウントタイプには他にもtempfs mountがありますが永続化目的では使用できないので使いません。  
Podman Volume は作成時に任意の場所を指定可能ですが今回はデフォルトの ~/.local/share/containers/storage/volumes/ 以下に作成しています。  

### Proxy 設定について

proxy設定はcontainer.conf のenvで登録しないと有効になりません。  
シェル実行時等色々試しましたが無駄でした。  
ホスト側・コンテナ側それぞれのcontainer.confに登録しています。  
