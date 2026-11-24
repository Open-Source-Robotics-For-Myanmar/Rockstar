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
            help_line 'ရည်ရွယ်ချက်:' 'SDK ကို ဘယ် board အတွက် ပြင်ဆင်ထားသလဲ မှတ်တမ်းတင်ဖို့ board/model အမည် လိုပါတယ်။' "$C_BLUE"
            help_line 'အလုပ်လုပ်ပုံ:' 'Device tree ထဲက model ကို ဖတ်ပြီး tr က စာသားအဆုံးရှိ NUL ကို ဖယ်ပေးပါတယ်။ Armbian သုံးထားမှ အောက်က အစားထိုး command ကို သုံးပါ။' "$C_BLUE"
            help_line 'အရေးကြီးပုံ:' 'Board များစွာရှိတဲ့အခါ SDK မှတ်တမ်း မရောစေဖို့ပါ။ ဒီအမည်ထည့်တာက driver သို့မဟုတ် compiler ကို အလိုအလျောက် မရွေးပေးပါ။' "$C_BLUE"
            help_line 'On target:' 'tr -d '"'"'\0'"'"' < /proc/device-tree/model; echo' "$C_GREEN"
            help_line Alternative: 'grep -E '"'"'^(BOARD_NAME|BOARD)='"'"' /etc/armbian-release' "$C_GREEN"
            help_line Enter: 'ဥပမာ Radxa ROCK 5B ကို တစ်ကြောင်းတည်း ထည့်ပါ။' "$C_YELLOW"
            ;;
        TARGET_COMPATIBLE)
            help_line 'ရည်ရွယ်ချက်:' 'Board ရဲ့ SoC က ဒီ SDK ရည်ရွယ်ထားတဲ့ RK3588 ဟုတ်မဟုတ် စစ်ဖို့ပါ။' "$C_BLUE"
            help_line 'အလုပ်လုပ်ပုံ:' 'Device tree ရဲ့ compatible စာရင်းကို Linux က hardware နဲ့ driver ကိုက်ညီမှု ရွေးရာမှာ သုံးပါတယ်။ tr က NUL ခြားထားတဲ့စာရင်းကို တစ်ကြောင်းစီခွဲပြီး grep က rk3588 ပါတဲ့ ပထမတန်ဖိုးကို ထုတ်ပါတယ်။' "$C_BLUE"
            help_line 'အရေးကြီးပုံ:' 'မတူတဲ့ SoC အတွက် SDK မှားဆောက်ခြင်းကို တားပေးပါတယ်။ ဒီ script က ထည့်ထားတဲ့စာသားမှာ rk3588 ပါမပါပဲ စစ်ပြီး board ကို ကိုယ်တိုင်ချိတ်စစ်တာ မဟုတ်ပါ။' "$C_BLUE"
            help_line 'On target:' 'tr '"'"'\0'"'"' '"'"'\n'"'"' < /proc/device-tree/compatible | grep -m1 rk3588' "$C_GREEN"
            help_line Enter: 'ဥပမာ rockchip,rk3588 — rk3588 ပါတဲ့ တန်ဖိုးတစ်ကြောင်းသာ ထည့်ပါ။ Output မရရင် board ကို ပြန်စစ်ပါ၊ unknown မထည့်ပါနဲ့။' "$C_YELLOW"
            ;;
        TARGET_ARCH)
            help_line 'ရည်ရွယ်ချက်:' 'Target OS က 64-bit ARM program ကို run နိုင်မယ့် architecture ဟုတ်မဟုတ် သိဖို့ပါ။' "$C_BLUE"
            help_line 'အလုပ်လုပ်ပုံ:' 'dpkg က OS packages ရဲ့ architecture ကို ပြပါတယ်။ uname -m က kernel ရဲ့ architecture ကို ပြပါတယ်။ arm64 နဲ့ aarch64 က ဒီနေရာမှာ 64-bit ARM ကို ရည်ညွှန်းပါတယ်။' "$C_BLUE"
            help_line 'အရေးကြီးပုံ:' 'SDK က AArch64 compiler ကို သုံးတာမို့ x86_64 သို့မဟုတ် 32-bit ARM OS အတွက် မကိုက်ပါ။ Script က arm64/aarch64 ကိုသာ လက်ခံပြီး aarch64 အဖြစ် မှတ်တမ်းတင်ပါတယ်။' "$C_BLUE"
            help_line 'On target:' 'dpkg --print-architecture' "$C_GREEN"
            help_line Cross-check: 'uname -m' "$C_GREEN"
            help_line Enter: 'arm64 သို့မဟုတ် aarch64။ နှစ်ခုကွဲနေရင် userspace က 32-bit ဖြစ်မဖြစ် စစ်ပါ၊ kernel output တစ်ခုတည်းကို မမှီခိုပါနဲ့။' "$C_YELLOW"
            ;;
        TARGET_OS)
            help_line 'ရည်ရွယ်ချက်:' 'Target ပေါ်က Linux distribution အမည်နဲ့ version ကို မှတ်တမ်းထားဖို့ပါ။' "$C_BLUE"
            help_line 'အလုပ်လုပ်ပုံ:' '/etc/os-release ထဲက PRETTY_NAME ကို ဖတ်ထုတ်ပါတယ်။ ဒါက Debian/Ubuntu စတဲ့ OS userspace အမည်ဖြစ်ပြီး kernel version နဲ့ မတူပါ။' "$C_BLUE"
            help_line 'အရေးကြီးပုံ:' 'နောက်ပိုင်း library/package ရှာတဲ့အခါ၊ အခြားစက်မှာ ပြန်ဆောက်တဲ့အခါ ဘယ် OS အတွက်လဲ သိနိုင်ပါတယ်။ ဒီတန်ဖိုးက compiler libraries ကို မပြောင်းပေးပါ။' "$C_BLUE"
            help_line 'On target:' '. /etc/os-release; printf '"'"'%s\n'"'"' "$PRETTY_NAME"' "$C_GREEN"
            help_line Enter: 'ဥပမာ Debian GNU/Linux 12 (bookworm)။ မသိရင် unknown ထည့်နိုင်ပါတယ်။' "$C_YELLOW"
            ;;
        TARGET_CODENAME)
            help_line 'ရည်ရွယ်ချက်:' 'Distribution ရဲ့ release အမည်တိုကို သိမ်းဖို့ပါ၊ ဥပမာ Debian ရဲ့ bookworm။' "$C_BLUE"
            help_line 'အလုပ်လုပ်ပုံ:' '/etc/os-release ထဲက VERSION_CODENAME ကို ထုတ်ပါတယ်။ မရှိရင် VERSION_ID ကို သုံးပါတယ်။' "$C_BLUE"
            help_line 'အရေးကြီးပုံ:' 'OS အမည်တူပေမဲ့ release မတူရင် package/library version တွေ ကွာနိုင်ပါတယ်။ မှန်တဲ့ release အတွက် documentation နဲ့ package repository ကို ရှာဖို့ အထောက်အကူဖြစ်ပြီး repository ကို ဒီ script က မပြောင်းပါ။' "$C_BLUE"
            help_line 'On target:' '. /etc/os-release; printf '"'"'%s\n'"'"' "${VERSION_CODENAME:-$VERSION_ID}"' "$C_GREEN"
            help_line Enter: 'ဥပမာ bookworm၊ jammy သို့မဟုတ် version number။ Output မရှိရင် unknown ထည့်ပါ။' "$C_YELLOW"
            ;;
        TARGET_KERNEL)
            help_line 'ရည်ရွယ်ချက်:' 'Target မှာ လက်ရှိ run နေတဲ့ Linux kernel release ကို မှတ်တမ်းထားဖို့ပါ။' "$C_BLUE"
            help_line 'အလုပ်လုပ်ပုံ:' 'uname -r က လက်ရှိ boot လုပ်ထားတဲ့ kernel release ကို ပြပါတယ်။ uname -v က build အသေးစိတ်ဖြစ်လို့ ဒီ input အတွက် မသုံးပါ။' "$C_BLUE"
            help_line 'အရေးကြီးပုံ:' 'Camera/NPU driver၊ ioctl နဲ့ kernel interface ဆိုင်ရာ ပြဿနာရှာရာမှာ လိုပါတယ်။ Version ထည့်ရုံနဲ့ kernel headers/driver မတင်ပေးသလို kernel module build အတွက်လည်း ဒီ SDK တစ်ခုတည်း မလုံလောက်ပါ။' "$C_BLUE"
            help_line 'On target:' 'uname -r' "$C_GREEN"
            help_line Enter: 'ဥပမာ 6.1.115-vendor-rk35xx။ မသိရင် unknown ထည့်ပါ။' "$C_YELLOW"
            ;;
        TARGET_GLIBC)
            help_line 'ရည်ရွယ်ချက်:' 'Target ရဲ့ C runtime library (glibc) version ကို သိဖို့ပါ။ Program ရဲ့ file I/O၊ memory နဲ့ system call wrapper စတဲ့ အခြေခံလုပ်ဆောင်ချက်တွေကို ပံ့ပိုးပါတယ်။' "$C_BLUE"
            help_line 'အလုပ်လုပ်ပုံ:' 'getconf က GNU libc version ကို ထုတ်ပြီး awk က version နံပါတ်ကိုသာ ရွေးပါတယ်။ Dynamic binary ကို run တဲ့အခါ လိုအပ်တဲ့ GLIBC symbol versions တွေ target library မှာ ရှိရပါတယ်။' "$C_BLUE"
            help_line 'အရေးကြီးပုံ:' 'ဒီ SDK က target sysroot မသုံးဘဲ host cross-toolchain ရဲ့ libraries နဲ့ link လုပ်ပါတယ်။ Target မှာ binary လိုတဲ့ version မရှိရင် GLIBC_x.y not found ဖြစ်နိုင်ပါတယ်။ ဒီ input ကို သိမ်းထားတာသာဖြစ်ပြီး ABI ကို အလိုအလျောက် မစစ်၊ မပြင်ပေးပါ။' "$C_BLUE"
            help_line 'On target:' 'getconf GNU_LIBC_VERSION | awk '"'"'{print $2}'"'"'' "$C_GREEN"
            help_line Enter: 'ဥပမာ 2.36 — နံပါတ်သာထည့်ပါ။ GNU libc မရှိ သို့မဟုတ် မသိရင် unknown ထည့်နိုင်ပေမဲ့ GNU toolchain နဲ့ ကိုက်ညီမှုကို သီးခြားစစ်ရပါမယ်။' "$C_YELLOW"
            ;;
        TARGET_LIBSTDCXX)
            help_line 'ရည်ရွယ်ချက်:' 'Target ရဲ့ C++ runtime library (libstdc++) version ကို သိဖို့ပါ။ std::string၊ containers၊ streams စတဲ့ C++ library လုပ်ဆောင်ချက်တွေကို ပံ့ပိုးပါတယ်။' "$C_BLUE"
            help_line 'အလုပ်လုပ်ပုံ:' 'dpkg-query က installed package version ကို ပြပါတယ်။ အစားထိုး command က library ထဲက GLIBCXX version အမှတ်အသားတွေကို version အလိုက်စီပြီး အမြင့်ဆုံးကို ထုတ်ပါတယ်။ Package version နဲ့ GLIBCXX symbol version က တန်ဖိုးအမျိုးအစား မတူပါ။' "$C_BLUE"
            help_line 'အရေးကြီးပုံ:' 'Cross compiler နဲ့ build ထားတဲ့ C++ binary က target မှာမရှိတဲ့ symbol ကို လိုရင် GLIBCXX_x.y.z not found ဖြစ်နိုင်ပါတယ်။ ဒီမှတ်တမ်းတစ်ခုတည်းနဲ့ ABI ကိုက်ညီမှု မအာမခံနိုင်ဘဲ binary လိုတဲ့ symbols နဲ့ target library ကို သီးခြားတိုက်စစ်ရပါတယ်။' "$C_BLUE"
            help_line 'On target:' 'dpkg-query -W -f='"'"'${Version}\n'"'"' libstdc++6:arm64' "$C_GREEN"
            help_line Alternative: 'strings /usr/lib/aarch64-linux-gnu/libstdc++.so.6 | grep -E '"'"'^GLIBCXX_[0-9]+(\.[0-9]+)*$'"'"' | sort -V | tail -n 1' "$C_GREEN"
            help_line Enter: 'Installed package version သို့မဟုတ် ဥပမာ GLIBCXX_3.4.30 ကို ထည့်ပါ။ Library path က စက်အလိုက်ကွာနိုင်ပါတယ်။ မရှိ/မသိရင် unknown ထည့်ပါ။ Script က runtime library ကို install မလုပ်ပေးပါ။' "$C_YELLOW"
            ;;
        SDK_ROOT)
            help_line 'ရည်ရွယ်ချက်:' 'SDK workspace အသစ်ကို build host ပေါ်မှာ ဘယ်နေရာဖန်တီးမလဲ သတ်မှတ်ဖို့ပါ။ Target board ရဲ့ folder လမ်းကြောင်း မဟုတ်ပါ။' "$C_BLUE"
            help_line 'အလုပ်လုပ်ပုံ:' 'ဒီ folder ထဲမှာ env.sh၊ CMake toolchain၊ metadata နဲ့ libraries ထားဖို့ prefix directory တို့ကို ဖန်တီးပါတယ်။ Folder မရှိသေးရဘဲ parent directory မှာ ရေးခွင့်ရှိရပါတယ်။' "$C_BLUE"
            help_line 'အရေးကြီးပုံ:' 'ရှိပြီးသား project/files တွေ မထိခိုက်စေဖို့ ရှိနေပြီးသား destination ကို ငြင်းပါတယ်။' "$C_BLUE"
            help_line 'On host:' pwd "$C_GREEN"
            help_line Enter: 'ဥပမာ /home/your-user/RK3588_SDK_new လို absolute path အသစ်ကို ထည့်ပါ။ pwd က လက်ရှိ folder ကိုကြည့်ဖို့သာဖြစ်ပြီး အဲဒီရှိပြီးသား folder ကို destination အဖြစ် မထည့်ပါနဲ့။' "$C_YELLOW"
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