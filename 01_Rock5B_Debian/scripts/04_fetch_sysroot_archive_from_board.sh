#!/usr/bin/env bash
# Fetch a sysroot archive from the target board over SSH.
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib/common.sh"

connect_board root
ARCHIVE_DIR="$SCRIPT_DIR/sysroot_archive"
mkdir -p "$ARCHIVE_DIR"
chmod 700 "$ARCHIVE_DIR"

ARCHIVE_STAMP=$(date +%Y%m%d-%H%M%S)
ARCHIVE_HOST=${SSH_HOST//:/_}
ARCHIVE_PATH="$ARCHIVE_DIR/rock5b-sysroot-${ARCHIVE_HOST}-${ARCHIVE_STAMP}.tar"
[[ ! -e $ARCHIVE_PATH ]] || {
    echo "Archive already exists; refusing to overwrite: $ARCHIVE_PATH" >&2
    exit 1
}
TEMP_ARCHIVE=$(mktemp "$ARCHIVE_DIR/.sysroot-archive.XXXXXX")

cleanup_fetch() {
    rm -f -- "${TEMP_ARCHIVE:-}"
    if [[ -n ${RESULT_DIR:-} ]]; then
        rmdir -- "$RESULT_DIR" 2>/dev/null || true
    fi
    finish_ssh
}
trap cleanup_fetch EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "Fetching target libraries and headers from $SSH_TARGET ..."
if ssh "${SSH_OPTIONS[@]}" "$SSH_TARGET" 'LC_ALL=C bash -s' > "$TEMP_ARCHIVE" <<'REMOTE'
set -eu
command -v tar >/dev/null 2>&1 || {
    echo 'Required command is missing on the board: tar' >&2
    exit 127
}
set --
for path in lib lib64 usr/lib usr/include usr/share/pkgconfig usr/local/lib usr/local/include; do
    if [ -e "/$path" ] || [ -L "/$path" ]; then
        set -- "$@" "$path"
    fi
done
[ "$#" -gt 0 ] || {
    echo 'No expected library/header paths found on the board.' >&2
    exit 1
}
exec tar --numeric-owner -C / -cf - -- "$@"
REMOTE
then
    :
else
    rc=$?
    echo "Archive transfer failed (SSH/remote tar exit $rc); no archive was saved." >&2
    exit "$rc"
fi

[[ -s $TEMP_ARCHIVE ]] || {
    echo 'Received an empty archive; refusing to save it.' >&2
    exit 1
}
if ! tar -tf "$TEMP_ARCHIVE" >/dev/null; then
    echo 'Received data is not a valid tar archive; refusing to save it.' >&2
    exit 1
fi

mv -- "$TEMP_ARCHIVE" "$ARCHIVE_PATH"
TEMP_ARCHIVE=''
(
    cd -- "$ARCHIVE_DIR"
    sha256sum "${ARCHIVE_PATH##*/}" > "${ARCHIVE_PATH##*/}.sha256"
)
echo "Archive saved: $ARCHIVE_PATH"
echo "Checksum saved: $ARCHIVE_PATH.sha256"