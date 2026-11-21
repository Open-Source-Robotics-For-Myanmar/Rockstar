#!/usr/bin/env bash
set -Eeuo pipefail

INTERACTIVE=1
SDK_DEFAULT=${SDK_ROOT:-"$HOME/RK3588_SDK_on_Ubuntu2204"}
TMP_SDK=

usage() {
    cat <<'USAGE'
Create a standalone ARM64 cross-compilation workspace without a target sysroot.

Usage:
  05_create_RK3588_SDK_env_without_sysroot.sh [--help] [--non-interactive]

Interactive mode asks for target-board details and an SDK destination.
The script does not SSH to the board, install host packages, download third-party
libraries, build a sample project, or modify an existing SDK directory.

Environment overrides:
  SDK_ROOT             Absolute destination directory (default: ~/RK3588_SDK_on_Ubuntu2204)
  TARGET_BOARD         Board/model description
  TARGET_COMPATIBLE    Device-tree compatible value
  TARGET_ARCH          Target architecture (arm64 or aarch64; required)
  TARGET_OS            Target OS name
  TARGET_CODENAME      Target OS codename
  TARGET_KERNEL        Target kernel release
  TARGET_GLIBC         Target GNU libc version
  TARGET_LIBSTDCXX     Target libstdc++ runtime version
  CROSS_COMPILE        Cross compiler prefix (default: aarch64-linux-gnu-)
  C_COMPILER           C compiler command
  CXX_COMPILER         C++ compiler command
  AR                   Archiver command
  RANLIB               Ranlib command
  STRIP                Strip command
  PKG_CONFIG           Host pkg-config command
  CMAKE                CMake command
  NINJA                Ninja command
  READELF             Target readelf command
  CONFIRM_CREATE       Set to yes to confirm in --non-interactive mode

The target details are recorded as user-provided metadata. They are not used to
download packages or construct a target sysroot.
USAGE
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

on_exit() {
    local status=$?
    if [[ -n $TMP_SDK && -d $TMP_SDK ]]; then
        rm -rf -- "$TMP_SDK"
    fi
    exit "$status"
}
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for arg in "$@"; do
    case $arg in
        --help|-h) usage; exit 0 ;;
        --non-interactive) INTERACTIVE=0 ;;
        *) fail "Unknown option: $arg (use --help)." ;;
    esac
done

prompt_value() {
    local variable=$1 label=$2 default=${3-} required=${4:-0} reply
    if (( INTERACTIVE )); then
        if [[ -n $default ]]; then
            read -r -p "$label [$default]: " reply || fail "Input ended while asking: $label"
            reply=${reply:-$default}
        else
            read -r -p "$label: " reply || fail "Input ended while asking: $label"
        fi
    else
        reply=$default
    fi
    if (( required )) && [[ -z $reply ]]; then
        fail "$label is required. Set $variable or run interactively."
    fi
    printf -v "$variable" '%s' "$reply"
}

need_command() {
    local label=$1 command_name=$2 resolved
    resolved=$(command -v -- "$command_name") ||
        fail "Missing $label command '$command_name'. Install/configure it on the host, then rerun."
    [[ $resolved != *$'\n'* ]] || fail "Invalid $label command path."
    printf '%s' "$resolved"
}

if [[ $(uname -s) != Linux || $(uname -m) != x86_64 ]]; then
    fail "This script expects a Linux amd64/x86_64 host; detected $(uname -s) $(uname -m)."
fi

HOST_OS=unknown
HOST_OS_VERSION=unknown
if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    HOST_OS=${PRETTY_NAME:-${ID:-unknown}}
    HOST_OS_VERSION=${VERSION_ID:-unknown}
fi

printf 'Host: %s (%s)\n' "$HOST_OS" "$(uname -m)"
printf 'This setup creates a generic ARM64/Linux GNU cross-toolchain workspace.\n'
printf 'It does not create a target sysroot or install/download dependencies.\n\n'

printf '%s\n' \
    'On the TARGET BOARD terminal, run the following read-only commands and keep the output:' \
    '  printf "architecture: "; dpkg --print-architecture' \
    '  cat /etc/os-release' \
    '  printf "kernel: "; uname -r' \
    '  getconf GNU_LIBC_VERSION' \
    '  tr "\0" "\n" < /proc/device-tree/compatible' \
    '  dpkg-query -W -f='"'"'${binary:Package}\t${Version}\t${Architecture}\n'"'"' libc6:arm64 libstdc++6:arm64 libgcc-s1:arm64 2>/dev/null || true' \
    'Use the results below when prompted. If a value is unavailable, enter unknown.'
printf '\n'

prompt_value TARGET_BOARD 'Target board/model' "${TARGET_BOARD:-}" 1
prompt_value TARGET_COMPATIBLE 'Device-tree compatible value' "${TARGET_COMPATIBLE:-}" 1
[[ ${TARGET_COMPATIBLE,,} == *rk3588* ]] ||
    fail "Device-tree compatible value must identify RK3588, not '$TARGET_COMPATIBLE'."
prompt_value TARGET_ARCH 'Target architecture (arm64/aarch64)' "${TARGET_ARCH:-}" 1
case ${TARGET_ARCH,,} in
    arm64|aarch64) TARGET_ARCH=aarch64 ;;
    *) fail "Target architecture must be arm64/aarch64, not '$TARGET_ARCH'." ;;
esac
prompt_value TARGET_OS 'Target OS name' "${TARGET_OS:-unknown}" 1
prompt_value TARGET_CODENAME 'Target OS codename' "${TARGET_CODENAME:-unknown}" 1
prompt_value TARGET_KERNEL 'Target kernel release' "${TARGET_KERNEL:-unknown}" 1
prompt_value TARGET_GLIBC 'Target GNU libc version' "${TARGET_GLIBC:-unknown}" 1
prompt_value TARGET_LIBSTDCXX 'Target libstdc++ runtime version' "${TARGET_LIBSTDCXX:-unknown}" 1

CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
C_COMPILER=${C_COMPILER:-"${CROSS_COMPILE}gcc"}
CXX_COMPILER=${CXX_COMPILER:-"${CROSS_COMPILE}g++"}
AR=${AR:-"${CROSS_COMPILE}ar"}
RANLIB=${RANLIB:-"${CROSS_COMPILE}ranlib"}
STRIP=${STRIP:-"${CROSS_COMPILE}strip"}
PKG_CONFIG=${PKG_CONFIG:-pkg-config}
CMAKE=${CMAKE:-cmake}
NINJA=${NINJA:-ninja}
READELF=${READELF:-"${CROSS_COMPILE}readelf"}

C_COMPILER=$(need_command 'AArch64 C compiler' "$C_COMPILER")
CXX_COMPILER=$(need_command 'AArch64 C++ compiler' "$CXX_COMPILER")
AR=$(need_command 'AArch64 archiver' "$AR")
RANLIB=$(need_command 'AArch64 ranlib' "$RANLIB")
STRIP=$(need_command 'AArch64 strip' "$STRIP")
PKG_CONFIG=$(need_command 'pkg-config' "$PKG_CONFIG")
CMAKE=$(need_command 'CMake' "$CMAKE")
NINJA=$(need_command 'Ninja' "$NINJA")
READELF=$(need_command 'AArch64 readelf' "$READELF")

CXX_MACHINE=$("$CXX_COMPILER" -dumpmachine) ||
    fail "Could not query target triple from $CXX_COMPILER."
[[ $CXX_MACHINE == *aarch64* ]] ||
    fail "C++ compiler target '$CXX_MACHINE' is not AArch64."
[[ $CXX_MACHINE == *linux* ]] ||
    fail "C++ compiler target '$CXX_MACHINE' is not Linux."
C_MACHINE=$("$C_COMPILER" -dumpmachine) ||
    fail "Could not query target triple from $C_COMPILER."
[[ $C_MACHINE == *aarch64* ]] ||
    fail "C compiler target '$C_MACHINE' is not AArch64."
[[ $C_MACHINE == *linux* ]] ||
    fail "C compiler target '$C_MACHINE' is not Linux."
C_COMPILER_VERSION=$("$C_COMPILER" --version | sed -n '1p')
CXX_COMPILER_VERSION=$("$CXX_COMPILER" --version | sed -n '1p')

if [[ -z ${SDK_ROOT:-} ]]; then
    prompt_value SDK_ROOT 'Absolute SDK workspace path' "$SDK_DEFAULT" 1
else
    prompt_value SDK_ROOT 'Absolute SDK workspace path' "$SDK_ROOT" 1
fi
[[ $SDK_ROOT == /* ]] || fail "SDK_ROOT must be an absolute path."
[[ $SDK_ROOT != / ]] || fail "SDK_ROOT cannot be the filesystem root."
[[ $SDK_ROOT != *$'\n'* ]] || fail "SDK_ROOT cannot contain a newline."

while [[ -e $SDK_ROOT || -L $SDK_ROOT ]]; do
    if (( ! INTERACTIVE )); then
        fail "SDK path already exists: $SDK_ROOT. Choose a new SDK_ROOT; existing files are never overwritten."
    fi
    printf 'SDK path already exists; it will not be modified: %s\n' "$SDK_ROOT" >&2
    prompt_value SDK_ROOT 'Choose a different absolute SDK workspace path' '' 1
    [[ $SDK_ROOT == /* && $SDK_ROOT != / && $SDK_ROOT != *$'\n'* ]] ||
        fail "SDK_ROOT must be an absolute non-root path without a newline."
done

cat <<SUMMARY

Review the setup configuration:
  Host OS:              $HOST_OS ($HOST_OS_VERSION, x86_64)
  Target board:         $TARGET_BOARD
  Device compatible:    $TARGET_COMPATIBLE
  Target architecture:  $TARGET_ARCH
  Target OS/codename:   $TARGET_OS / $TARGET_CODENAME
  Target kernel:         $TARGET_KERNEL
  Target glibc:          $TARGET_GLIBC
  Target libstdc++:      $TARGET_LIBSTDCXX
  Cross C compiler:      $C_COMPILER ($C_MACHINE)
  Cross C++ compiler:    $CXX_COMPILER ($CXX_MACHINE)
  SDK workspace:        $SDK_ROOT

Important: these board values are metadata only. The SDK will use the host
cross-compiler's built-in headers/libraries and will not match a target sysroot.
Third-party libraries (including RKNN and libdatachannel) are not installed.
SUMMARY

if [[ ${CONFIRM_CREATE:-} != yes ]]; then
    if (( INTERACTIVE )); then
        read -r -p 'Create this SDK workspace? Type yes to continue: ' CONFIRM_CREATE ||
            fail 'Input ended before confirmation.'
    else
        fail 'Set CONFIRM_CREATE=yes to create the workspace in non-interactive mode.'
    fi
fi
[[ $CONFIRM_CREATE == yes ]] || fail 'Cancelled; no SDK workspace was created.'

SDK_PARENT=$(dirname -- "$SDK_ROOT")
SDK_NAME=$(basename -- "$SDK_ROOT")
mkdir -p -- "$SDK_PARENT"
TMP_SDK=$(mktemp -d -- "$SDK_PARENT/.${SDK_NAME}.tmp.XXXXXX")
mkdir -p -- "$TMP_SDK"/{bin,toolchains,src,build,prefix/include,prefix/lib,metadata,models}

printf -v q_cc '%q' "$C_COMPILER"
printf -v q_cxx '%q' "$CXX_COMPILER"
printf -v q_ar '%q' "$AR"
printf -v q_ranlib '%q' "$RANLIB"
printf -v q_strip '%q' "$STRIP"
printf -v q_pkg_config '%q' "$PKG_CONFIG"

cat > "$TMP_SDK/env.sh" <<ENV
export RK3588_SDK="\$(cd -- "\$(dirname -- "\${BASH_SOURCE[0]}")" && pwd)"
export CC=$q_cc
export CXX=$q_cxx
export AR=$q_ar
export RANLIB=$q_ranlib
export STRIP=$q_strip
export PKG_CONFIG="\$RK3588_SDK/bin/rk3588-pkg-config"
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH LD_LIBRARY_PATH
unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS CMAKE_PREFIX_PATH
unset PKG_CONFIG_PATH PKG_CONFIG_LIBDIR PKG_CONFIG_SYSROOT_DIR
ENV

cat > "$TMP_SDK/bin/rk3588-pkg-config" <<'PKGCONFIG'
#!/usr/bin/env bash
set -Eeuo pipefail
sdk_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export PKG_CONFIG_PATH=
export PKG_CONFIG_LIBDIR="$sdk_dir/prefix/lib/pkgconfig:$sdk_dir/prefix/share/pkgconfig"
unset PKG_CONFIG_SYSROOT_DIR
PKGCONFIG
printf 'exec %s "$@"\n' "$q_pkg_config" >> "$TMP_SDK/bin/rk3588-pkg-config"
chmod 0755 "$TMP_SDK/bin/rk3588-pkg-config"

cat > "$TMP_SDK/toolchains/rk3588.cmake" <<CMAKE
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER "$C_COMPILER")
set(CMAKE_CXX_COMPILER "$CXX_COMPILER")
set(CMAKE_AR "$AR")
set(CMAKE_RANLIB "$RANLIB")
set(CMAKE_STRIP "$STRIP")
set(CMAKE_C_FLAGS_INIT "-march=armv8-a -mtune=generic")
set(CMAKE_CXX_FLAGS_INIT "-march=armv8-a -mtune=generic")
get_filename_component(RK3588_SDK_ROOT "\${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(CMAKE_FIND_ROOT_PATH "\${RK3588_SDK_ROOT}/prefix")
list(PREPEND CMAKE_PREFIX_PATH "\${RK3588_SDK_ROOT}/prefix")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_FIND_USE_PACKAGE_REGISTRY FALSE)
set(CMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY FALSE)
set(PKG_CONFIG_EXECUTABLE "\${RK3588_SDK_ROOT}/bin/rk3588-pkg-config"
    CACHE FILEPATH "Target pkg-config" FORCE)
CMAKE

{
    printf 'Host OS: %s (%s)\n' "$HOST_OS" "$HOST_OS_VERSION"
    printf 'Host architecture: %s\n' "$(uname -m)"
    printf 'C compiler: %s\n' "$C_COMPILER"
    printf 'C compiler target: %s\n' "$C_MACHINE"
    printf 'C compiler version: %s\n' "$C_COMPILER_VERSION"
    printf 'C++ compiler: %s\n' "$CXX_COMPILER"
    printf 'C++ compiler target: %s\n' "$CXX_MACHINE"
    printf 'C++ compiler version: %s\n' "$CXX_COMPILER_VERSION"
    printf 'CMake: %s\n' "$CMAKE"
    printf 'Ninja: %s\n' "$NINJA"
    printf 'pkg-config: %s\n' "$PKG_CONFIG"
    printf 'readelf: %s\n' "$READELF"
} > "$TMP_SDK/metadata/host.txt"

{
    printf 'Board/model: %s\n' "$TARGET_BOARD"
    printf 'Device-tree compatible: %s\n' "$TARGET_COMPATIBLE"
    printf 'Architecture: %s\n' "$TARGET_ARCH"
    printf 'OS: %s\n' "$TARGET_OS"
    printf 'Codename: %s\n' "$TARGET_CODENAME"
    printf 'Kernel: %s\n' "$TARGET_KERNEL"
    printf 'GNU libc: %s\n' "$TARGET_GLIBC"
    printf 'libstdc++ runtime: %s\n' "$TARGET_LIBSTDCXX"
    printf 'Input method: manually provided by user; not verified over SSH\n'
} > "$TMP_SDK/metadata/target.txt"

{
    printf '# Target baseline (user-provided)\n\n'
    printf '| Item | Value |\n|---|---|\n'
    printf '| Board/model | %s |\n' "$TARGET_BOARD"
    printf '| Device-tree compatible | %s |\n' "$TARGET_COMPATIBLE"
    printf '| Architecture | %s |\n' "$TARGET_ARCH"
    printf '| OS | %s |\n' "$TARGET_OS"
    printf '| Codename | %s |\n' "$TARGET_CODENAME"
    printf '| Kernel | %s |\n' "$TARGET_KERNEL"
    printf '| GNU libc | %s |\n' "$TARGET_GLIBC"
    printf '| libstdc++ runtime | %s |\n' "$TARGET_LIBSTDCXX"
    printf '\nThese values were entered by the user and were not independently verified.\n'
    printf 'This workspace uses the host cross-compiler built-in target files; it is not a target-matched sysroot.\n'
    printf 'Third-party libraries and hardware runtimes are not included.\n'
} > "$TMP_SDK/metadata/target-baseline.md"

mv -Tn -- "$TMP_SDK" "$SDK_ROOT"
[[ ! -e $TMP_SDK ]] ||
    fail "SDK destination appeared during setup; no existing files were overwritten: $SDK_ROOT"
TMP_SDK=

printf '\nSDK environment created: %s\n' "$SDK_ROOT"
printf 'Activate in this terminal with:\n  source "%s/env.sh"\n' "$SDK_ROOT"
printf 'Build a smoke-test project by following README/08_build_smoke_test_project.md.\n'