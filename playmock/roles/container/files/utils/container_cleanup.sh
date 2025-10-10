#!/usr/bin/env bash
# -- container_cleanup.sh
#    未使用コンテナ等不要リソースの削除
#
# Usage:
#    sudo /opt/containers/utils/container_cleanup.sh
#
set -u

### Begin -- setup environment
# Suppress ShellCheck warnings (e.g. SC2034,SC1091) for the following { ... } block.
# The braces ensure the suppression applies only to this limited scope.
# shellcheck disable=SC2034
{
    LOG_TAGNAME="container-utils-cleanup"
    CONTAINER_USER="container_user"
}
COMMAND_PATH=$(cd "$(dirname "$(realpath "$0")")" && pwd)
CONTAINER_HOME=$(cd "$(realpath "$COMMAND_PATH/..")" && pwd)
UTILS_HOME=$(cd "$(realpath "$CONTAINER_HOME/utils")" && pwd)
LIB_PATH=$(cd "$(realpath "$UTILS_HOME/lib")" && pwd)
# shellcheck disable=SC1091
{
    source "$LIB_PATH/journal.sh"
    source "$LIB_PATH/rotate_files.sh"
    source "$LIB_PATH/container_utils.sh"
}
### End -- setup environment

#
# Start
#
log_start

#
# Step 1. 停止しているコンテナが存在する場合は安全のためクリーンアップしない
#
stopped_containers=($(container_list_stopped_containers))
container_stopped_containers_exist
RESULT=${?:-}
if [ "$RESULT" != "0" ]; then
    log_warn "Cleanup process aborted due to the presence of stopped container(s). This is to prevent accidental deletion of necessary resources."
    log_warn "Stopped container(s): ${stopped_containers[*]}"
    exit 0
fi

#
# Step 2. 未使用のコンテナを削除
# 'podman container prune -f'
#
log_info "Prune containers."
params=(container prune -f)
container_ctl "${params[@]}"

#
# Step 3. 未使用のイメージを削除
# 'podman image prune -f'
#
log_info "Prune container images."
params=(image prune -f)
container_ctl "${params[@]}"

#
# Step 4. 未使用のボリュームを削除
# 'podman volume prune -f'
#
log_info "Prune container volumes."
params=(volume prune -f)
container_ctl "${params[@]}"

#
# Step 5. 未使用のネットワークを削除
# 'podman network prune -f'
#
log_info "Prune container networks."
params=(network prune -f)
container_ctl "${params[@]}"

#
# Step 6. 1週間以上未使用のビルドキャッシュを削除
# 'podman builder prune -f --filter "until=168h"'
#
log_info "Prune containers build cache older than one week."
params=(builder prune -f --filter "until=168h")
container_ctl "${params[@]}"

#
# End
#
log_end
