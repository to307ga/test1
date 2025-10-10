#!/usr/bin/env bash
# -- container_utils.sh
#    Utilities for container operation.
#
# 実行ユーザー: 任意(sudoers)
# コンテナ管理ユーザー: container_user
# コンテナ管理コマンド: podman
#
set -u

# guard: prevent multiple sourcing
if [ -n "${__CONTAINER_UTILS_LOADED+x}" ]; then
    return 0
fi
__CONTAINER_UTILS_LOADED=1
# setup environment
__MYLIB_PATH="${BASH_SOURCE[0]}"
__MYLIB_DIR="$(cd "$(dirname "$__MYLIB_PATH")" && pwd)"
# shellcheck source=/dev/null
source "$__MYLIB_DIR/journal.sh"

# Container control command
CONTAINERCTL=podman
CONTAINER_USER=container_user

#
# Functions
#

# container_ctl <command_and_args>
#
# Exit Code =0: Success
#          !=0: Fail
#
function container_ctl() {
    local command_and_args=("$@")
    
    if [[ -z "${command_and_args[*]}" ]]; then
        log_error "Error: container_ctl(): Parameter ('command_and_args') is required."
        return 1
    fi
    
    log_debug "container_ctl(): sudo -i -u $CONTAINER_USER $CONTAINERCTL ${command_and_args[*]}"

    sudo -i -u "$CONTAINER_USER" "$CONTAINERCTL" "${command_and_args[@]}" \
        1> >(log_info_stream) \
        2> >(log_error_stream)
}


# container_exists <container_name>
#
# Exit Code =0: Success
#          !=0: Fail
#
function container_exists() {
    local container_name="${1:-}"
    
    if [[ -z "$container_name" ]]; then
        log_error "Error: container_exists(): Parameter #1('container_name') is required."
        return 1
    fi
    
    sudo -i -u "$CONTAINER_USER" "$CONTAINERCTL" ps --format "{{.Names}} {{.Status}}" | \
    grep -q "^$container_name Up .*$" \
        1> >(log_info_stream) \
        2> >(log_error_stream)
}

# container_exec <parameters>
#
# Usage:
#   params=(opt1 opt2 optN $CONTAINER_NAME command arg1 arg2 argN)
#   container_exec "${params[@]}"
#
# Exit Code =0: Success
#          !=0: Fail
#
function container_exec() {
    local params=("$@")
    
    if [[ -z "${params[*]}" ]]; then
        log_error "Error: container_exec(): Parameter #1('params') is required."
        return 1
    fi

    log_debug "container_exec(): sudo -i -u '$CONTAINER_USER' '$CONTAINERCTL' exec ${params[*]}"

    sudo -i -u "$CONTAINER_USER" "$CONTAINERCTL" exec "${params[@]}" \
        1> >(log_info_stream) \
        2> >(log_error_stream)
}

# container_start <container_name>
#
# Exit Code =0: Success
#          !=0: Fail
#
function container_start() {
    local container_name="${1:-}"
 
    if [[ -z "$container_name" ]]; then
        log_error "Error: container_start(): Parameter #1('container_name') is required."
        return 1
    fi

    command_and_args=("start" "$container_name")
    container_ctl "${command_and_args[@]}"
}

# container_stop <container_name>
#
# Exit Code =0: Success
#          !=0: Fail
#
function container_stop() {
    local container_name="${1:-}"

    if [[ -z "$container_name" ]]; then
        log_error "Error: container_stop(): Parameter #1('container_name') is required."
        return 1
    fi

    command_and_args=("stop" "$container_name")
    container_ctl "${command_and_args[@]}"
}

# container_copy <[container:]source> <[container:]destination>
# 
# Exit Code =0: Success
#          !=0: Fail
#
function container_copy() {
    local src="${1:-}"
    local dest="${2:-}"
    
    if [[ -z "$src" ]]; then
        log_error "Error: container_copy(): Parameter #1('source') is required."
        return 1
    fi
    
    if [[ -z "$dest" ]]; then
        log_error "Error: container_copy(): Parameter #2('destination') is required."
        return 1
    fi
    
    sudo -i -u "$CONTAINER_USER" "$CONTAINERCTL" cp "$src" "$dest" \
        1> >(log_info_stream) \
        2> >(log_error_stream)
}


# container_volume_mountpoint <volume_name>
#
# Return   指定ボリュームのマウントポイント(ローカルストレージのパス)
# Exit Code =0: Success
#          !=0: Fail
#
function container_volume_mountpoint() {
    local volume_name="${1:-}"

    if [[ -z "$volume_name" ]]; then
        log_error "Error: container_volume_mountpoint(): Parameter #1('volume_name') is required."
        echo "$?"
    fi

    sudo -i -u "$CONTAINER_USER" "$CONTAINERCTL" volume inspect "$volume_name"  | \
        jq -r ".[] | select(.Name == \"$volume_name\") | .Mountpoint" \
        2> >(log_error_stream)
}


# container_list_stopped_containers
#
# Usage:
#   stopped=$(container_list_stopped_containers)
#   echo "${stopped[@]}"
#    
# Return   停止中のコンテナ情報のリスト
#
function container_list_stopped_containers() {
    sudo -i -u "$CONTAINER_USER" "$CONTAINERCTL" ps -qa --format "{{.Names}}" --filter "status=exited" \
        2> >(log_error_stream)
}

# container_stopped_container_exists
#
# Exit Code =0: 停止中のコンテナ無し
#          !=0: 停止中のコンテナ有り
#
function container_stopped_containers_exist() {
    stopped=$(container_list_stopped_containers)
    if [[ -z "${stopped[*]}" ]]; then
        return 0 # No stopped containers
    else
        return 1
    fi
}


# container_wait_until_active <container_name> <heartbeat_cmd> [timeout_seconds:10] [interval_seconds:3]
#
# Exit Code =0: Success
#          !=0: Fail
#
function container_wait_until_active() {
    local container_name="${1:-}"
    local heartbeat_cmd="${2:-}"
    local timeout_seconds="${3:-10}"
    local interval_seconds="${4:-3}"

    if [[ -z "$container_name" ]]; then
        log_error "Error: container_wait_until_active(): Parameter #1('container_name') is required."
        return 1
    fi
    if [[ -z "$heartbeat_cmd" ]]; then
        log_error "Error: container_wait_until_active(): Parameter #1('heartbeat_cmd') is required."
        return 1
    fi
    if (( timeout_seconds < 1 )); then
        log_error "Error: container_wait_until_active(): Parameter #3('timeout_seconds') must be greater than or equal 1."
        return 1
    fi
    if (( interval_seconds < 1 )); then
        log_error "Error: container_wait_until_active(): Parameter #4('interval_seconds') must be greater than or equal 1."
        return 1
    fi

    local max_retries=$((timeout_seconds / interval_seconds))
    local count=0

    params=(
        "$container_name"
        "sh" "-c" "$heartbeat_cmd"
    )

    # until sudo -i -u "$CONTAINER_USER" "$CONTAINERCTL" exec "${params[@]}" >/dev/null 2>&1; do
    until container_exec "${params[@]}"; do
        count=$((count + 1))
        if [ "$count" -ge "$max_retries" ]; then
            log_error "Error: Timeout waiting for container '$container_name' to become active."
            return 1
        else
            log_info "container_wait_until_active(): Heartbeat command failed on container '$container_name' (attempt $count/$max_retries)"
        fi
        sleep "$interval_seconds"
    done
}


#
# --- Main: for testing directly via console.
#
if [[ "$(basename "$0")" == "container_utils.sh" ]]; then
    # shellcheck disable=SC2034
    LOG_OUTPUT_MODE="std"  # ログ出力先をコンソールに： stdout/stderr for journal.sh
    # shellcheck disable=SC2034
    LOG_LEVEL=debug

    CONTAINER_NAME="${1:-}"
    ACTION="${2:-}"
    shift 2
    REST_ARGS=("$@")

    if [[ -z "$CONTAINER_NAME" ]]; then
        echo "Usage: $0 <container_name> [[start|stop]|exec [command arg1 arg2 ...]]"
        echo "  container_name : Container name"
        echo "  start|stop     : Start or Stop container"
        echo "  exec           : Execute command in container"
        echo "  command argN   : Command and arguments to execute in container (for 'exec' action)"
        exit 1
    fi

    container_exists "$CONTAINER_NAME"
    RESULT=${?:-}
    if [[ "$RESULT" == "0" ]]; then
        echo "Container '$CONTAINER_NAME' is present and active."
    else
        echo "Container '$CONTAINER_NAME' is not present."
    fi

    container_volume_mountpoint "jenkins_home"

    container_list_stopped_containers

    container_stopped_containers_exist
    RESULT=${?:-}
    if [[ "$RESULT" == "0" ]]; then
        echo "All containers are running."
    else
        echo "There are stopped containers."
    fi

    if [[ -z "$ACTION" ]]; then
        exit 0
    fi
    case "$ACTION" in
        start)
            echo "Starting container '$CONTAINER_NAME'..."
            container_start "$CONTAINER_NAME"
            echo "Container '$CONTAINER_NAME' started."
            ;;
        stop)
            echo "Stopping container '$CONTAINER_NAME'..."
            container_stop "$CONTAINER_NAME"
            echo "Container '$CONTAINER_NAME' stopped."
            ;;
        exec) 
            echo "Executing command in container '$CONTAINER_NAME' ${REST_ARGS[*]}"
            args=("$CONTAINER_NAME")
            args+=("${REST_ARGS[@]}")
            container_exec "${args[@]}"
            echo "Command executed in container '$CONTAINER_NAME'."
            ;;
        *)
            echo "Error: Unknown action '$ACTION'. Use 'start','stop' or 'exec'."
            exit 1
            ;;
    esac

fi

# EOS
