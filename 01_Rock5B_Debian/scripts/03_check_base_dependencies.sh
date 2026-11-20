#!/usr/bin/env bash
# Save the base system inventory on the host for cross-SDK setup.
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib/common.sh"
connect_board root
# Use a regular user if root login is disabled. Permission errors are logged.
run_remote system <<'REMOTE'
set -u
export LC_ALL=C
date -Is
id
cat /etc/os-release
uname -a
printf '\nArchitecture: '; dpkg --print-architecture
getconf GNU_LIBC_VERSION
printf '\nModel: '; tr '\0' '\n' < /proc/device-tree/model
printf '\nKernel command line:\n'; cat /proc/cmdline
printf '\nLoader:\n'; ls -l /lib/ld-linux-aarch64.so.1
printf '\nCPU:\n'; lscpu
printf '\nStorage:\n'; df -hT
printf '\nTools:\n'
for cmd in sh bash tar scp ldd ldconfig gcc g++ cmake pkg-config make python3; do command -v "$cmd" || true; done
REMOTE
run_remote packages <<'REMOTE'
set -eu
dpkg-query -W -f='${binary:Package}\t${Version}\t${Architecture}\t${db:Status-Status}\n'
REMOTE
run_remote libc6_version <<'REMOTE'
set -eu
dpkg-query -W -f='${Version}\n' libc6:arm64
REMOTE
run_remote apt_policy <<'REMOTE'
set -u
# Read the cache only. Do not update or install packages.
apt-cache policy
apt-cache policy libc6 libc6-dev libstdc++6 libgcc-s1 linux-libc-dev
printf '\nPackage health:\n'
dpkg --audit
printf '\nHeld packages:\n'
apt-mark showhold
REMOTE
run_remote libraries <<'REMOTE'
set -u
printf 'Loader cache:\n'
ldconfig -p 2>&1 || true
printf '\nLibrary files / symlinks:\n'
for dir in /usr/lib /usr/local/lib /opt; do
    [ -d "$dir" ] || continue
    find "$dir" \( -type f -o -type l \) \
        \( -name '*.so' -o -name '*.so.*' -o -name '*.a' -o -name '*.pc' \) \
        -printf '%p -> %l\n' 2>&1
done
printf '\nBase runtime package files:\n'
dpkg-query -L libc6:arm64 libstdc++6:arm64 libgcc-s1:arm64 2>&1 || true
printf '\nRuntime ABI symbols (if strings is available):\n'
if command -v strings >/dev/null; then
    for lib in /usr/lib/aarch64-linux-gnu/libc.so.6 /usr/lib/aarch64-linux-gnu/libstdc++.so.6; do
        [ -f "$lib" ] || continue
        echo "$lib"
        strings "$lib" | grep -E '^(GLIBC_|GLIBCXX_|CXXABI_)[0-9.]+$' | sort -Vu
    done
else
    echo 'BLOCKED: strings is missing. Copy libraries to the host to inspect ABI symbols.'
fi
REMOTE
run_remote headers_tools <<'REMOTE'
set -u
printf 'Development files:\n'
for dir in /usr/include /usr/local/include /usr/share/pkgconfig /usr/lib/pkgconfig /usr/lib/aarch64-linux-gnu/pkgconfig /usr/lib/aarch64-linux-gnu/cmake; do
    [ -d "$dir" ] || continue
    find "$dir" \( -type f -o -type l \) -printf '%p -> %l\n' 2>&1
done
printf '\nBinary locations:\n'
for dir in /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin; do
    [ -d "$dir" ] || continue
    find "$dir" -maxdepth 1 \( -type f -o -type l \) -printf '%p -> %l\n'
done
printf '\nTool versions (if available):\n'
for cmd in gcc g++ cmake pkg-config; do
    if command -v "$cmd" >/dev/null; then "$cmd" --version; fi
done
REMOTE
run_remote kernel_vendor <<'REMOTE'
set -u
printf 'Loaded modules:\n'; cat /proc/modules
printf '\nKernel module directory:\n'; ls -ld "/lib/modules/$(uname -r)" 2>&1
printf '\nKernel config (if available):\n'
if [ -r "/boot/config-$(uname -r)" ]; then
    grep -Ei 'CONFIG_(ARM64|DRM|ROCKCHIP|RKNPU|MALI|VIDEO|IOMMU)' "/boot/config-$(uname -r)"
elif [ -r /proc/config.gz ] && command -v zcat >/dev/null; then
    zcat /proc/config.gz | grep -Ei 'CONFIG_(ARM64|DRM|ROCKCHIP|RKNPU|MALI|VIDEO|IOMMU)'
else
    echo 'BLOCKED: kernel config is unavailable.'
fi
printf '\nVendor libraries:\n'
ldconfig -p 2>/dev/null | grep -Ei 'rknn|rga|mpp|mali|OpenCL|EGL|GLES' || true
printf '\nNPU driver:\n'
find /sys/bus/platform/drivers -maxdepth 1 -iname '*npu*'
for p in /sys/kernel/debug/rknpu/version /sys/kernel/debug/rknpu/load; do
    if [ -r "$p" ]; then echo "$p"; cat "$p"; fi
done
REMOTE
cat > "$RESULT_DIR/README.txt" <<'NOTE'
These results are a read-only inventory, not an SDK build or hardware PASS.
No package updates, installations, driver changes, or debugfs mounts were performed.
Check each output for permission and command errors.
Runtime completeness requires the application dependency list.
To copy a sysroot to the host, follow README/03_check_base_dependencies.md.
Logs may contain IP/MAC addresses, package versions, and device paths. Review before sharing.
NOTE
echo "Done. Logs: $RESULT_DIR"
