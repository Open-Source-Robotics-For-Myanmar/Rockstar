#!/usr/bin/env bash
set -Eeuo pipefail

INTERACTIVE=1
SDK_DEFAULT=${SDK_ROOT:-"$HOME/RK3588_SDK_on_Ubuntu2204"}
TMP_SDK=

# Colours are decorative only: plain logs, redirected output and NO_COLOR stay
# ANSI-free. FORCE_COLOR=1 overrides the TTY check when you want coloured logs.
USE_COLOR=0
if [[ -t 1 && -z ${NO_COLOR:-} && ${TERM:-dumb} != dumb ]]; then
    USE_COLOR=1
fi
[[ ${FORCE_COLOR:-} != 1 ]] || USE_COLOR=1
if (( USE_COLOR )); then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[1;31m'
    C_GREEN=$'\033[1;32m'
    C_YELLOW=$'\033[1;33m'
    C_BLUE=$'\033[1;34m'
    C_CYAN=$'\033[1;36m'
else
    C_RESET= C_BOLD= C_DIM= C_RED= C_GREEN= C_YELLOW= C_BLUE= C_CYAN=
fi

help_line() {
    local tag=$1 text=$2 color=${3:-}
    if [[ -n $tag ]]; then
        printf '  %s%-11s%s %s\n' "$color" "$tag" "$C_RESET" "$text"
    else
        printf '               %s%s%s\n' "$color" "$text" "$C_RESET"
    fi
}

# One canonical source for the field text: --help and the prompts both render it.
field_help() {
    case $1 in
        TARGET_BOARD)
            help_line 'On target:' "tr -d '\\0' < /proc/device-tree/model; echo" "$C_GREEN"
            help_line '' "grep -E '^(BOARD_NAME|BOARD)=' /etc/armbian-release" "$C_DIM"
            help_line 'Enter:' 'one line, e.g. "Radxa ROCK 5B". Why: board identity in metadata; no compiler effect.' "$C_YELLOW"
            ;;
        TARGET_COMPATIBLE)
            help_line 'On target:' "tr '\\0' '\\n' < /proc/device-tree/compatible | grep -m1 rk3588" "$C_GREEN"
            help_line '' 'prints one value, e.g. rockchip,rk3588' "$C_DIM"
            help_line 'Enter:' 'ONE line containing rk3588, e.g. "rockchip,rk3588".' "$C_YELLOW"
            help_line 'Why:' 'guard against the wrong SoC; multi-line values break the markdown table.' "$C_BLUE"
            ;;
        TARGET_ARCH)
            help_line 'On target:' 'dpkg --print-architecture (arm64)  |  uname -m (aarch64)' "$C_GREEN"
            help_line 'Enter:' 'arm64 or aarch64 (normalised to aarch64). Why: confirms a 64-bit ARM target.' "$C_YELLOW"
            ;;
        TARGET_OS)
            help_line 'On target:' ". /etc/os-release; printf '%s\\n' \"\$PRETTY_NAME\"" "$C_GREEN"
            help_line 'Enter:' 'e.g. "Debian GNU/Linux 12 (bookworm)". Why: records the target userspace.' "$C_YELLOW"
            ;;
        TARGET_CODENAME)
            help_line 'On target:' ". /etc/os-release; printf '%s\\n' \"\$VERSION_CODENAME\"" "$C_GREEN"
            help_line '' 'if empty, use VERSION_ID or "unknown"' "$C_DIM"
            help_line 'Enter:' 'e.g. "bookworm", "jammy". Why: pins the exact userspace release.' "$C_YELLOW"
            ;;
        TARGET_KERNEL)
            help_line 'On target:' 'uname -r   (not uname -v)' "$C_GREEN"
            help_line 'Enter:' 'e.g. "6.1.115-vendor-rk35xx". Why: kernel UAPI compatibility note (no headers installed).' "$C_YELLOW"
            ;;
        TARGET_GLIBC)
            help_line 'On target:' "getconf GNU_LIBC_VERSION | awk '{print \$2}'" "$C_GREEN"
            help_line '' 'ldd --version | head -n1 prints a whole banner - enter only the number' "$C_DIM"
            help_line 'Enter:' 'version number, e.g. "2.36".' "$C_YELLOW"
            help_line 'Why:' 'ABI check - host cross glibc here is 2.35; the board needs >= that or a matching sysroot.' "$C_BLUE"
            ;;
        TARGET_LIBSTDCXX)
            help_line 'On target:' "dpkg-query -W -f='\${Version}\\n' libstdc++6:arm64" "$C_GREEN"
            help_line '' 'strings /usr/lib/aarch64-linux-gnu/libstdc++.so.6 | grep -m1 GLIBCXX_' "$C_DIM"
            help_line 'Enter:' 'package version, e.g. "12.3.0-1ubuntu1~22.04.3", or the highest GLIBCXX_ symbol.' "$C_YELLOW"
            help_line 'Why:' 'C++ ABI check against host libstdc++ 12.3.0 (GCC 11); older board symbols break C++ binaries.' "$C_BLUE"
            ;;
        SDK_ROOT)
            help_line 'On host:' 'not a board value - choose a LOCAL destination directory.' "$C_GREEN"
            help_line 'Enter:' 'absolute path that does not exist yet, e.g. "$HOME/RK3588_SDK_on_Ubuntu2204".' "$C_YELLOW"
            help_line 'Why:' 'generated files go here; existing directories are never modified.' "$C_BLUE"
            ;;
    esac
}

print_field_help() {
    local key=$1 item field title
    if [[ $key == ALL ]]; then
        printf '%s%s%s\n' "$C_BOLD" 'HOW TO COLLECT EVERY PROMPTED VALUE' "$C_RESET"
        printf '%s\n' \
            'Run each "On target" command on the TARGET BOARD (the RK3588 board), not on the' \
            'build host. Enter only the value, not the label and not the whole command.' \
            'Every target value is metadata only: metadata/*.txt, metadata/target-baseline.md' \
            'and the summary. Nothing here downloads, installs or configures the compiler.' \
            'Use "unknown" when unavailable; board/model, compatible and architecture are checked.'
        printf '\n'
        for item in \
            'TARGET_BOARD|1) Target board/model' \
            'TARGET_COMPATIBLE|2) Device-tree compatible value' \
            'TARGET_ARCH|3) Target architecture (arm64/aarch64)' \
            'TARGET_OS|4) Target OS name' \
            'TARGET_CODENAME|5) Target OS codename' \
            'TARGET_KERNEL|6) Target kernel release' \
            'TARGET_GLIBC|7) Target GNU libc version' \
            'TARGET_LIBSTDCXX|8) Target libstdc++ runtime version' \
            'SDK_ROOT|9) SDK workspace path (HOST, not the board)'; do
            field=${item%%|*}
            title=${item#*|}
            printf '%s%s%s\n' "$C_BOLD$C_CYAN" "$title" "$C_RESET"
            field_help "$field"
            printf '\n'
        done
    else
        field_help "$key"
    fi
}

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
  READELF              Target readelf command
  CONFIRM_CREATE       Set to yes to confirm in --non-interactive mode

USAGE
    print_field_help ALL
    cat <<'USAGE'
Configuration is printed for review at the end; type "yes" to create the
workspace. In --non-interactive mode, set every TARGET_* variable plus
SDK_ROOT and CONFIRM_CREATE=yes; the values are never guessed.

The target details are recorded as user-provided metadata. They are not used to
download packages or construct a target sysroot.
USAGE
}

fail() {
    printf '%sERROR:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
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
    local variable=$1 label=$2 default=${3-} required=${4:-0} reply prompt
    if (( INTERACTIVE )); then
        if [[ -n $default ]]; then
            prompt="${C_CYAN}${label}${C_RESET} [${default}]: "
        else
            prompt="${C_CYAN}${label}${C_RESET}: "
        fi
        read -r -p "$prompt" reply || fail "Input ended while asking: $label"
        reply=${reply:-$default}
    else
        reply=$default
    fi
    if (( required )) && [[ -z $reply ]]; then
        fail "$label is required. Set $variable or run interactively."
    fi
    printf -v "$variable" '%s' "$reply"
}

prompt_field() {
    local variable=$1 label=$2 default=${3-}
    printf '\n%s=== %s ===%s\n' "$C_BOLD$C_CYAN" "$label" "$C_RESET"
    field_help "$variable"
    prompt_value "$variable" "$label" "$default" 1
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

printf '%sHost:%s %s (%s)\n' "$C_BOLD" "$C_RESET" "$HOST_OS" "$(uname -m)"
printf '%sThis setup creates a generic ARM64/Linux GNU cross-toolchain workspace.%s\n' "$C_DIM" "$C_RESET"
printf '%sIt does not create a target sysroot or install/download dependencies.%s\n\n' "$C_DIM" "$C_RESET"

printf '%s%s%s\n' "$C_BOLD" 'On the TARGET BOARD terminal, run read-only commands and keep the output.' "$C_RESET"
printf '%s\n' \
    'Each prompt below shows the exact command, an example value, and why it is needed.' \
    'Use "unknown" for unavailable values. Run this script with --help for the full guide.'
printf '\n'

prompt_field TARGET_BOARD 'Target board/model' "${TARGET_BOARD:-}"
prompt_field TARGET_COMPATIBLE 'Device-tree compatible value' "${TARGET_COMPATIBLE:-}"
[[ ${TARGET_COMPATIBLE,,} == *rk3588* ]] ||
    fail "Device-tree compatible value must identify RK3588, not '$TARGET_COMPATIBLE'."
prompt_field TARGET_ARCH 'Target architecture (arm64/aarch64)' "${TARGET_ARCH:-}"
case ${TARGET_ARCH,,} in
    arm64|aarch64) TARGET_ARCH=aarch64 ;;
    *) fail "Target architecture must be arm64/aarch64, not '$TARGET_ARCH'." ;;
esac
prompt_field TARGET_OS 'Target OS name' "${TARGET_OS:-unknown}"
prompt_field TARGET_CODENAME 'Target OS codename' "${TARGET_CODENAME:-unknown}"
prompt_field TARGET_KERNEL 'Target kernel release' "${TARGET_KERNEL:-unknown}"
prompt_field TARGET_GLIBC 'Target GNU libc version' "${TARGET_GLIBC:-unknown}"
prompt_field TARGET_LIBSTDCXX 'Target libstdc++ runtime version' "${TARGET_LIBSTDCXX:-unknown}"

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

prompt_field SDK_ROOT 'Absolute SDK workspace path (on host)' "$SDK_DEFAULT"
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

${C_BOLD}${C_CYAN}Review the setup configuration:${C_RESET}
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

${C_YELLOW}Important:${C_RESET} these board values are metadata only. The SDK will use the host
cross-compiler's built-in headers/libraries and will not match a target sysroot.
Third-party libraries (including RKNN and libdatachannel) are not installed.
SUMMARY

if [[ ${CONFIRM_CREATE:-} != yes ]]; then
    if (( INTERACTIVE )); then
        read -r -p "${C_YELLOW}Create this SDK workspace?${C_RESET} Type yes to continue: " CONFIRM_CREATE ||
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

printf '\n%sSDK environment created:%s %s\n' "$C_GREEN" "$C_RESET" "$SDK_ROOT"
printf '%sActivate in this terminal with:%s\n  source "%s/env.sh"\n' "$C_BOLD" "$C_RESET" "$SDK_ROOT"
printf 'Build a smoke-test project by following README/08_build_smoke_test_project.md.\n'