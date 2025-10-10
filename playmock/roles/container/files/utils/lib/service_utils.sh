#!/usr/bin/env bash
# -- service_utils.sh
#    Utilities for service operation.
#
# 実行ユーザー: 任意(sudoers)
# サービス管理ユーザー: container_user
#
set -u

# guard: prevent multiple sourcing
if [ -n "${__MY_SERVICE_LOADED+x}" ]; then
    return 0
fi
__MY_SERVICE_LOADED=1
# setup environment
__MYLIB_PATH="${BASH_SOURCE[0]}"
__MYLIB_DIR="$(cd "$(dirname "$__MYLIB_PATH")" && pwd)"
# shellcheck source=/dev/null
source "$__MYLIB_DIR/journal.sh"

# Constants
SERVICE_USER=container_user

#
# Functions
#

# service_cmd <service_name> <command>
#
# Uasge:
#   $output=$(service_cmd "pod-some-container.service" start|stop|restart|is-active)
#   result=${?:-}
#   echo "$output"
#
# Exit Code =0: Success
#          !=0: Fail
#
function service_cmd() {
    local service_name="${1:-}"
    local cmd="${2:-}"

    if [[ -z "$service_name" ]]; then
        log_error "Error: service_cmd(): Parameter #1('service_name') is required."
        return 1
    fi
    if [[ -z "$cmd" ]]; then
        log_error "Error: service_cmd(): Parameter #2('cmd') is required."
        return 1
    fi

    sudo -i -u "$SERVICE_USER" systemctl --user "$cmd" "$service_name" \
        2> >(log_error_stream)
}

# service_start <service_name>
#
# Uasge:
#   $output=$(service_start "pod-some-container.service")
#   result=${?:-}
#   echo "$output"
#
# Exit Code =0: Success
#          !=0: Fail
#
function service_start() {
    local service_name="${1:-}"

    if [[ -z "$service_name" ]]; then
        log_error "Error: service_start(): Parameter #1('service_name') is required."
        return 1
    fi

    service_cmd "$service_name" "start"
}

# service_stop <service_name>
#
# Uasge:
#   $output=$(service_stop "pod-some-container.service")
#   result=${?:-}
#   echo "$output"
#
# Exit Code =0: Success
#          !=0: Fail
#
function service_stop() {
    local service_name="${1:-}"

    if [[ -z "$service_name" ]]; then
        log_error "Error: service_stop(): Parameter #1('service_name') is required."
        return 1
    fi

    service_cmd "$service_name" "stop"
}

# service_restart <service_name>
#
# Uasge:
#   $output=$(service_restart "pod-some-container.service")
#   result=${?:-}
#   echo "$output"
#
# Exit Code =0: Success
#          !=0: Fail
#
function service_restart() {
    local service_name="${1:-}"

    if [[ -z "$service_name" ]]; then
        log_error "Error: service_restart(): Parameter #1('service_name') is required."
        return 1
    fi

    service_cmd "$service_name" "restart"
}

# service_is_active <service_name>
#
# Uasge:
#   $output=$(service_is_active "pod-some-container.service")
#   result=${?:-}
#   echo "$output"
#
# Exit Code =0: Active
#          !=0: Inactive/Failed/Not found
#
function service_is_active() {
    local service_name="${1:-}"

    if [[ -z "$service_name" ]]; then
        log_error "Error: service_is_active(): Parameter #1('service_name') is required."
        return 1
    fi

    service_cmd "$service_name" "is-active"
}


# service_wait_until_active <service_name> [timeout_seconds:10] [interval_seconds:3]
# Uasge:
#   service_wait_until_active "pod-some-container.service" [timeout_seconds:10] [interval_seconds:3]
#   result=${?:-}
#
# Exit Code =0: Success
#          !=0: Fail
#
function service_wait_until_active() {
    local service_name="${1:-}"
    local timeout_seconds="${2:-10}"
    local interval_seconds="${3:-3}"

    if [[ -z "$service_name" ]]; then
        log_error "Error: service_wait_until_active(): Parameter #1('service_name') is required."
        return 1
    fi
    if (( timeout_seconds < 1 )); then
        log_error "Error: service_wait_until_active(): Parameter #2('timeout_seconds') must be greater than or equal 1."
        return 1
    fi
    if (( interval_seconds < 1 )); then
        log_error "Error: service_wait_until_active(): Parameter #3('interval_seconds') must be greater than or equal 1."
        return 1
    fi

    local elapsed=0
    while true; do
        service_is_active "$service_name"
        result=${?:-}
        if [[ $result -eq 0 ]]; then
            return 0
        fi
        if (( elapsed >= timeout_seconds )); then
            log_error "Error: Timeout waiting for service '$service_name' to become active."
            return 1
        fi
        sleep "$interval_seconds"
        elapsed=$(( elapsed + interval_seconds ))
    done
}



#
# --- Main: for testing directly via console.
#
if [[ "$(basename "$0")" == "service_utils.sh" ]]; then
 
    SERVICE_NAME="${1:-}"
    COMMAND="${2:-is-active}"

    # shellcheck disable=SC2034
    LOG_OUTPUT_MODE="std"  # ログ出力先をコンソールに： stdout/stderr for journal.sh


    if [[ -z "$SERVICE_NAME" ]]; then
        echo "Usage: $0 <service_name> <start|stop|restart|is-active|wait-until-active> [timeout_seconds] [interval_seconds]"
        exit 1
    fi

    case "$COMMAND" in
        start)
            service_start "$SERVICE_NAME"
            ;;
        stop)
            service_stop "$SERVICE_NAME"
            ;;
        restart)
            service_restart "$SERVICE_NAME"
            ;;
        is-active)
            service_is_active "$SERVICE_NAME"
            ;;
        wait-until-active)
            TIMEOUT_SECONDS="${3:-10}"
            INTERVAL_SECONDS="${4:-3}"
            service_wait_until_active "$SERVICE_NAME" "$TIMEOUT_SECONDS" "$INTERVAL_SECONDS"
            ;;
        *)
            echo "Usage: $0 <service_name> <start|stop|restart|is-active|wait-until-active> [timeout_seconds] [interval_seconds]"
            exit 1
            ;;
    esac
    RESULT=${?:-}
    if [[ "$RESULT" == "0" ]]; then
        echo "Success service command '$COMMAND' for '$SERVICE_NAME'."
    else
        echo "Failed service command '$COMMAND' for '$SERVICE_NAME'."
    fi

fi
# EOS
