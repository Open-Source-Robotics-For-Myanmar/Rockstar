#!/usr/bin/env bash
set -euo pipefail
SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT
mkdir -p "$WORK/scripts/lib" "$WORK/bin"
cp "$SOURCE_DIR"/0*.sh "$WORK/scripts/"
cp "$SOURCE_DIR/lib/common.sh" "$WORK/scripts/lib/"
for f in "$WORK"/scripts/*.sh "$WORK/scripts/lib/common.sh"; do bash -n "$f"; done
# Verify caller variables are assigned, including the confirmation named answer.
bash -s -- "$WORK/scripts/lib/common.sh" <<'CHECK'
set -euo pipefail
source "$1"
ask answer 'Confirmation' <<< 'CONTINUE'
[[ $answer == CONTINUE ]]
ask answer 'Load test' <<< 'RUN'
[[ $answer == RUN ]]
ask port 'Port' 22 <<< ''
[[ $port == 22 ]]
ask confirmation 'Disk confirmation' <<< 'ERASE /dev/fake'
[[ $confirmation == 'ERASE /dev/fake' ]]
check_local() {
    local answer
    ask answer 'Confirmation' <<< 'CONTINUE'
    [[ $answer == CONTINUE ]]
}
check_local
if ask answer 'EOF' < /dev/null; then
    echo 'FAIL: EOF accepted'; exit 1
fi
CHECK
cat > "$WORK/bin/ssh" <<'MOCK'
#!/usr/bin/env bash
set -eu
case " $* " in
  *' -O '*|*' -M '*) exit 0;;
esac
if [[ $* == *'/proc/device-tree/compatible'* ]]; then
    echo "${MOCK_COMPATIBLE:-rockchip,rk3588}"
    exit 0
fi
# Check remote shell syntax without executing it.
bash -n
if [[ ${MOCK_FAIL:-0} == 1 ]]; then exit 7; fi
echo 'MOCK inventory output'
MOCK
chmod +x "$WORK/bin/ssh"
export PATH="$WORK/bin:$PATH"
printf 'board\nuser\n22\na\n0\n' | bash "$WORK/scripts/02_check_hardwares.sh" > "$WORK/hardware.log"
files=$(find "$WORK/scripts/check_results" -name '*.txt' | wc -l)
[[ $files == 14 ]]
! grep -R -q 'REMOTE_EXIT=[1-9]' "$WORK/scripts/check_results"
printf 'board\nroot\n22\n' | bash "$WORK/scripts/03_check_base_dependencies.sh" > "$WORK/dependencies.log"
grep -Rq 'MOCK inventory output' "$WORK/scripts/check_results"
# Ensure SSH errors are reported as failures.
if printf 'board\nroot\n22\n' | MOCK_FAIL=1 bash "$WORK/scripts/03_check_base_dependencies.sh" > "$WORK/failure.log" 2>&1; then
    echo 'FAIL: SSH failure was ignored'; exit 1
fi
grep -q 'REMOTE_EXIT=7' "$WORK/failure.log"
if printf 'board\nroot\n22\n' | MOCK_COMPATIBLE=other bash "$WORK/scripts/03_check_base_dependencies.sh" > "$WORK/board.log" 2>&1; then
    echo 'FAIL: wrong board accepted'; exit 1
fi
# Test disk checks only. Do not run dd, sudo, or disk writes.
sed -n '/^check_disk() {/,/^}/p' "$SOURCE_DIR/01_flash_sdcard.sh" > "$WORK/check-disk.sh"
cat > "$WORK/check-disk-test.sh" <<'CHECK'
set -euo pipefail
source "$1"
DISK=/dev/fake
IMAGE=/tmp/fake.img.xz
findmnt() { echo overlay; }
lsblk() { printf '%s\n' "$MOCK_MOUNT"; }
for MOCK_MOUNT in / /boot /home /var '[SWAP]'; do
    if check_disk >/dev/null 2>&1; then echo "FAIL: accepted $MOCK_MOUNT"; exit 1; fi
done
MOCK_MOUNT=/media/user/SD
check_disk
MOCK_MOUNT=''
check_disk
CHECK
bash "$WORK/check-disk-test.sh" "$WORK/check-disk.sh"
# Reject invalid menu choices before any disk operation.
mkdir -p "$WORK/vendor_images"
printf fixture > "$WORK/vendor_images/sample.img.xz"
if printf '99\n' | bash "$WORK/scripts/01_flash_sdcard.sh" > "$WORK/flash.log" 2>&1; then
    echo 'FAIL: bad image index accepted'; exit 1
fi
echo 'PASS: Bash syntax, 14 menu payloads, dependency payloads, SSH failure, RK3588 guard, mounted-disk guards, invalid image choice.'
