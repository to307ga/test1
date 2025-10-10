#!/bin/bash
###############################################################################
#  処理名：不要ファイル削除（コンテナ）
###############################################################################
# ログファイルの設定
echo "----- podman cleanup スクリプト開始 $(date) -----"

# 停止中のコンテナをリストアップ
su - container_user -c 'stopped_containers=$(podman ps -aq --filter "status=exited")'

# 停止中のコンテナがある場合、処理を終了
if [ ! -z "$stopped_containers" ]; then
    echo "停止中のコンテナが存在します。処理を終了します。"
    echo "停止中のコンテナ: $stopped_containers"
    echo "----- Podman prune スクリプト終了 $(date) -----"
    exit 0
fi

# 停止中のコンテナがない場合、未使用リソースの削除を実行
echo "停止中のコンテナはありません。未使用リソースを削除します。"

# 未使用のコンテナを削除
echo "未使用のコンテナを削除します..."
su - container_user -c 'podman container prune -f'

# 未使用のイメージを削除
echo "未使用のイメージを削除します..."
su - container_user -c 'podman image prune -f'

# 未使用のボリュームを削除
echo "未使用のボリュームを削除します..."
su - container_user -c 'podman volume prune -f'

# 未使用のネットワークを削除
echo "未使用のネットワークを削除します..."
su - container_user -c 'podman network prune -f'

# 1週間以上未使用のビルドキャッシュを削除
echo "1週間以上未使用のビルドキャッシュを削除します..."
su - container_user -c 'podman builder prune -f --filter "until=168h"'

# 完了メッセージ
echo "----- podman cleanup スクリプト終了 $(date) -----"
