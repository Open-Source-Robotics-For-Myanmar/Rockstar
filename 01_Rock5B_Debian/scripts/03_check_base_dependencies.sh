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
apt-cache policy libc6 libc6-dev libstdc++6 libstdc++-16-dev libgcc-s1 libgcc-16-dev linux-libc-dev
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

package_version() {
    local package=$1
    awk -F '\t' -v package="$package" '$1 == package && $4 == "installed" { print $2; exit }' \
        "$RESULT_DIR/packages.txt"
}
apt_candidate() {
    local package=$1
    awk -v package="$package:" '
        $0 == package { in_package = 1; next }
        in_package && /^[[:space:]]*Candidate:/ { print $2; exit }
        in_package && /^[^[:space:]]/ { exit }
    ' "$RESULT_DIR/apt_policy.txt"
}
first_match() {
    local file=$1 pattern=$2 value
    value=$(grep -m1 -E "$pattern" "$RESULT_DIR/$file.txt" || true)
    if [[ -n $value ]]; then
        printf '%s' "$value"
    else
        printf 'NOT FOUND IN INVENTORY'
    fi
}

OS_NAME=$(sed -n 's/^PRETTY_NAME=//p' "$RESULT_DIR/system.txt" | head -n 1 | tr -d '"')
OS_CODENAME=$(sed -n 's/^VERSION_CODENAME=//p' "$RESULT_DIR/system.txt" | head -n 1)
TARGET_ARCH=$(sed -n 's/^Architecture: //p' "$RESULT_DIR/system.txt" | head -n 1)
KERNEL_RELEASE=$(awk '$1 == "Linux" { print $3; exit }' "$RESULT_DIR/system.txt")
GLIBC_VERSION=$(awk '$1 == "glibc" { print $2; exit }' "$RESULT_DIR/system.txt")
LIBC_PACKAGE_VERSION=$(head -n 1 "$RESULT_DIR/libc6_version.txt")
LIBSTDCXX_VERSION=$(package_version 'libstdc++6:arm64')
LIBGCC_VERSION=$(package_version 'libgcc-s1:arm64')
LIBC_DEV_INSTALLED=$(package_version 'libc6-dev:arm64')
LIBSTDCXX_DEV_INSTALLED=$(package_version 'libstdc++-16-dev:arm64')
LIBC_DEV_CANDIDATE=$(apt_candidate libc6-dev)
LIBSTDCXX_DEV_CANDIDATE=$(apt_candidate libstdc++-16-dev)
LIBGCC_DEV_CANDIDATE=$(apt_candidate libgcc-16-dev)
LINUX_LIBC_DEV_CANDIDATE=$(apt_candidate linux-libc-dev)
NPU_DRIVER=$(sed -n 's/^RKNPU driver: //p' "$RESULT_DIR/kernel_vendor.txt" | head -n 1)
[[ -n $NPU_DRIVER ]] || NPU_DRIVER='Not reported in inventory'
VENDOR_PACKAGES=$(awk -F '\t' 'tolower($1) ~ /(rknn|rga|mpp|mali|opencl|egl|gles)/ && $4 == "installed" { print $1 " " $2 }' \
    "$RESULT_DIR/packages.txt")
[[ -n $VENDOR_PACKAGES ]] || VENDOR_PACKAGES='No matching vendor runtime package names found in dpkg inventory'
VENDOR_LIBRARIES=$(grep -Ei '^[[:space:]]*lib.*(rknn|rga|mpp|mali|opencl|egl|gles)' \
    "$RESULT_DIR/kernel_vendor.txt" | sed 's/^[[:space:]]*//' || true)
[[ -n $VENDOR_LIBRARIES ]] || VENDOR_LIBRARIES='No matching vendor libraries found in loader cache inventory'

cat > "$RESULT_DIR/SDK_REQUIREMENTS.md" <<REQUIREMENTS
# ROCK 5B Cross-Compile SDK / Sysroot Requirements

**Generated:** $(date -Is)  
**Source:** This folder's \`system.txt\`, \`packages.txt\`, \`apt_policy.txt\`, \`libraries.txt\`, \`headers_tools.txt\`, and \`kernel_vendor.txt\`.

## Target baseline

| Item | Detected value |
|---|---|
| Board model | $(first_match system '^Model:') |
| OS | ${OS_NAME:-NOT FOUND IN INVENTORY} |
| OS codename | ${OS_CODENAME:-NOT FOUND IN INVENTORY} |
| Target architecture | ${TARGET_ARCH:-NOT FOUND IN INVENTORY} |
| Kernel release | ${KERNEL_RELEASE:-NOT FOUND IN INVENTORY} |
| glibc runtime | ${GLIBC_VERSION:-NOT FOUND IN INVENTORY} |
| libc6:arm64 package version | ${LIBC_PACKAGE_VERSION:-NOT FOUND IN INVENTORY} |
| Dynamic loader | $(first_match system '^lrwx.*ld-linux-aarch64') |
| libstdc++6:arm64 runtime version | ${LIBSTDCXX_VERSION:-NOT FOUND IN PACKAGE INVENTORY} |
| libgcc-s1:arm64 runtime version | ${LIBGCC_VERSION:-NOT FOUND IN PACKAGE INVENTORY} |

## Required in the target sysroot

1. **ARM64 glibc development files:** \`libc6-dev:arm64=${LIBC_PACKAGE_VERSION:-UNKNOWN}\`.
   - Installed on target: ${LIBC_DEV_INSTALLED:-not installed/not in package inventory}.
   - Candidate in the board's APT inventory: ${LIBC_DEV_CANDIDATE:-NOT REPORTED}.
   - Use this exact libc version. If unavailable, stop and locate the matching package/archive.
2. **Matching runtime baseline:** \`libc6\`, loader, \`libstdc++6\` (${LIBSTDCXX_VERSION:-version not inventoried}),
   and \`libgcc-s1\` (${LIBGCC_VERSION:-version not inventoried}). Preserve the board's runtime libraries
   when using the archive method; when using packages, obtain matching ARM64 runtime packages.
3. **C++ headers and compiler runtime:** obtain target files compatible with the \`libstdc++6\` version above.
   - Installed on target: ${LIBSTDCXX_DEV_INSTALLED:-not installed/not in package inventory}.
   - GCC 16 development package candidates: \`libstdc++-16-dev=${LIBSTDCXX_DEV_CANDIDATE:-NOT REPORTED}\`,
     \`libgcc-16-dev=${LIBGCC_DEV_CANDIDATE:-NOT REPORTED}\`.
   - Verify availability/version before use; the host cross-compiler's default C++ headers/runtime may not match.
4. **Optional Linux UAPI headers:** \`linux-libc-dev:arm64\` candidate is ${LINUX_LIBC_DEV_CANDIDATE:-NOT REPORTED}.
   Add only if the app directly needs these headers. They are not kernel-module build headers. Compare the
   version/API with kernel ${KERNEL_RELEASE:-NOT REPORTED}; kernel modules require matching vendor kernel source/build headers.
5. Add only the app's required ARM64 library development packages (each library's \`-dev\` package/headers)
   and runtime libraries. These cannot be determined exactly until the app's dependency list is known.

## Host-only toolchain requirements

Do **not** install these on the board. On the amd64 host, install \`crossbuild-essential-arm64\` (or an
equivalent AArch64 cross-toolchain), \`cmake\`, \`ninja-build\`, \`pkg-config\`, \`binutils\`, and the host's
normal build utilities. Confirm the compiler's C++ runtime/ABI against the target runtime above.

## Vendor/hardware items to verify

- **RKNPU driver:** ${NPU_DRIVER}
- **Matching installed package names:** ${VENDOR_PACKAGES}
- **Matching loader-cache libraries:** ${VENDOR_LIBRARIES}

The NPU kernel driver does not prove that the RKNN user-space runtime, headers, or SDK are installed.
For RKNN/RGA/MPP/GPU use, identify the exact ARM64 runtime and development headers required by the app,
check compatibility with the board driver, and add them separately if absent.

## Method-specific input

- **Archive method:** copy target runtime libraries and symlinks into the sysroot, then add missing \`-dev\` headers.
- **No-archive method:** download/extract only the required ARM64 \`.deb\` packages into the sysroot. Inventory
  versions are requirements, not the package files themselves. Never put amd64 libraries in the target sysroot.

## Important limitation

This is a board baseline, not a complete app-specific SDK bill of materials. Review app dependencies,
plugins loaded with \`dlopen()\`, models/data, and vendor runtime requirements before declaring the SDK complete.
Do not install development packages on the board solely to build on the host.
REQUIREMENTS

cat > "$RESULT_DIR/README.txt" <<'NOTE'
These results are a read-only inventory, not an SDK build or hardware PASS.
No package updates, installations, driver changes, or debugfs mounts were performed.
Check each output for permission and command errors.
Runtime completeness requires the application dependency list.
Start with SDK_REQUIREMENTS.md for the target baseline and sysroot/toolchain inputs.
Logs may contain IP/MAC addresses, package versions, and device paths. Review before sharing.
NOTE
echo "Done. Logs: $RESULT_DIR"
echo "SDK/sysroot requirements: $RESULT_DIR/SDK_REQUIREMENTS.md"
