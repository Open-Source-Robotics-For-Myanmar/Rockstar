#!/usr/bin/env bash
# OpenSSH prompts for passwords through /dev/tty. Passwords are not logged.
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

ask() {
    local _ask_variable=$1 _ask_prompt=$2 _ask_default=${3-} _ask_reply
    read -r -p "$_ask_prompt${_ask_default:+ [$_ask_default]}: " _ask_reply || return 1
    printf -v "$_ask_variable" '%s' "${_ask_reply:-$_ask_default}"
}
need() {
    command -v "$1" >/dev/null 2>&1 || { echo "Missing host command: $1" >&2; exit 1; }
}
finish_ssh() {
    if [[ -n ${SSH_SOCKET-} ]]; then
        ssh "${SSH_OPTIONS[@]}" -O exit "$SSH_TARGET" >/dev/null 2>&1 || true
        rm -rf -- "$SESSION_DIR"
    fi
}
connect_board() {
    need ssh
    need tee
    ask SSH_HOST 'Board IP / hostname'
    ask SSH_USER 'SSH username' "${1:-mr_robot}"
    ask SSH_PORT 'SSH port' 22
    [[ $SSH_HOST =~ ^[a-zA-Z0-9][a-zA-Z0-9._:-]*$ ]] || { echo 'Invalid IP address or hostname.'; exit 1; }
    [[ $SSH_USER =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]] || { echo 'Invalid username.'; exit 1; }
    [[ $SSH_PORT =~ ^[0-9]{1,5}$ ]] && (( 10#$SSH_PORT >= 1 && 10#$SSH_PORT <= 65535 )) || { echo 'Invalid port.'; exit 1; }
    SESSION_DIR=$(mktemp -d /tmp/rock5b-ssh.XXXXXX)
    SSH_SOCKET="$SESSION_DIR/control"
    SSH_TARGET="$SSH_USER@$SSH_HOST"
    SSH_OPTIONS=(-p "$SSH_PORT" -o ConnectTimeout=15 -o ServerAliveInterval=15
        -o ServerAliveCountMax=3 -o ControlPath="$SSH_SOCKET"
        -o StrictHostKeyChecking=ask)
    trap finish_ssh EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    echo 'SSH uses your key or prompts for a password.'
    ssh "${SSH_OPTIONS[@]}" -M -N -f -o ControlPersist=600 "$SSH_TARGET"
    # Keep host key verification enabled.
    local compatible
    compatible=$(ssh "${SSH_OPTIONS[@]}" "$SSH_TARGET" "tr '\\0' '\\n' < /proc/device-tree/compatible")
    if [[ $compatible != *rk3588* ]]; then
        echo 'Not an RK3588 / RK3588S board. Stopping.' >&2
        exit 1
    fi
    local results_root="$SCRIPT_DIR/check_results"
    mkdir -p "$results_root"
    chmod 700 "$results_root"
    RESULT_DIR=$(mktemp -d "$results_root/$(date +%Y%m%d-%H%M%S)-${SSH_HOST//:/_}.XXXXXX")
    echo "Logs: $RESULT_DIR"
}
run_remote() {
    local name=$1 rc
    # Send shell code through stdin without creating files on the board.
    if ssh "${SSH_OPTIONS[@]}" "$SSH_TARGET" 'LC_ALL=C bash -s' 2>&1 | tee "$RESULT_DIR/$name.txt"; then
        rc=0
    else
        rc=$?
    fi
    printf '\nREMOTE_EXIT=%s\n' "$rc" | tee -a "$RESULT_DIR/$name.txt"
    if (( rc != 0 )); then
        echo "Check failed: $name (exit $rc)" >&2
    fi
    return "$rc"
}
