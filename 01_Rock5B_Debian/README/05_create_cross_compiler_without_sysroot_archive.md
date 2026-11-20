# ၀၅ — Sysroot Archive မပါဘဲ Cross-Compile SDK ပြင်ဆင်ခြင်း

ဤနည်းတွင် board မှ `/lib`, `/usr/lib` တို့ကို archive အဖြစ်မကူးဘဲ target OS/release နှင့် version ကိုက်ညီသော ARM64 `.deb` packages များကို amd64 host ပေါ်တွင် ရယူပြီး sysroot ပြင်ဆင်မည်။

**Board ပေါ်တွင် `apt install/upgrade` မလုပ်ပါ။** Package များကို host ပေါ်ရှိ SDK-local directory ထဲ download/extract လုပ်မည်။ Host ပေါ်ရှိ APT configuration, package database နဲ့ installed packages များကိုလည်း မပြောင်းပါ။

အောက်ပါ code blocks များကို **host ပေါ်ရှိ Bash terminal တစ်ခုတည်းတွင် အစဉ်လိုက်** run ပါ။ `SDK`, `BASE`, `LIBC_VERSION` နှင့် APT setting များကို အဆင့်များအကြား ဆက်သုံးမည်။

> ဤဥပမာသည် စစ်ဆေးထားသော ROCK 5B ၏ Ubuntu 26.04 `resolute`, ARM64, glibc `2.43-2ubuntu2.3` အတွက်ဖြစ်သည်။ သင့် inventory တွင် codename/version မတူပါက အောက်ပါ repository နဲ့ version ကို အတည်ပြုပြီးမှ ပြင်ပါ။

## ၁။ Inventory ရလဒ်ကို သတ်မှတ်ရန်

`03_check_base_dependencies.sh` က host ပေါ်သိမ်းထားသော results directory ကို `BASE` ထဲ သတ်မှတ်ပါ။ ဤဥပမာတွင် အောက်ပါဖိုင်များ ရှိရမည်:

```text
system.txt
libc6_version.txt
packages.txt
apt_policy.txt
libraries.txt
kernel_vendor.txt
headers_tools.txt
```

```bash
set -euo pipefail
export BASE="$HOME/path/to/20261120-164734-192.168.1.15.fji2Cn"
export SDK="$HOME/rock5b-sdk-no-archive"
export TARGET=rock@192.168.1.15

if [ -e "$SDK" ]; then
    echo "SDK path already exists; choose a new path or back it up manually: $SDK" >&2
    exit 1
fi
test -s "$BASE/system.txt"
test -s "$BASE/libc6_version.txt"
test -s "$BASE/packages.txt"
grep -E '^(VERSION_CODENAME|UBUNTU_CODENAME)=resolute$' "$BASE/system.txt"
grep -F 'Architecture: arm64' "$BASE/system.txt"
LIBC_VERSION=$(sed -n '1p' "$BASE/libc6_version.txt")
printf 'Target libc6 version: %s\n' "$LIBC_VERSION"
mkdir -p "$SDK"/{base,metadata,sysroot,debs,src,build,stage,apt}
cp "$BASE/system.txt" "$BASE/packages.txt" "$BASE/apt_policy.txt" \
  "$BASE/libraries.txt" "$BASE/kernel_vendor.txt" "$BASE/headers_tools.txt" "$SDK/base/"
cp "$BASE/libc6_version.txt" "$SDK/base/"
```

`libc6_version.txt` တွင် ပထမစာကြောင်းသည် package version ဖြစ်ပြီး နောက်တွင် `REMOTE_EXIT=0` ရှိနိုင်သည်။ အောက်ပါအဆင့်တွင် version ပထမစာကြောင်းကိုသာ အသုံးပြုမည်။ မျှော်မှန်းထားသော version သို့မဟုတ် codename မကိုက်ပါက ဆက်မလုပ်ဘဲ inventory ကိုပြန်စစ်ပါ။

## ၂။ Host တွင် cross-toolchain နှင့် build tools တင်ရန်

ဤအဆင့်သည် **amd64 Ubuntu host** ပေါ်မှာသာ လုပ်ပါ။ Host distro မတူလျှင် package names ကို သက်ဆိုင်ရာ host အတွက်ပြင်ပါ။

```bash
sudo apt update
sudo apt install -y crossbuild-essential-arm64 cmake ninja-build pkg-config \
  python3 file binutils ubuntu-keyring

test "$(dpkg --print-architecture)" = amd64
aarch64-linux-gnu-gcc --version
aarch64-linux-gnu-g++ --version
```

`dpkg --print-architecture` သည် `amd64` ဖြစ်ကြောင်း စစ်ပါ။ `crossbuild-essential-arm64` သည် host ပေါ်တွင် cross compiler တင်ပေးသည်။ ဤ package များကို host ပေါ်တွင်သာ တင်သဖြင့် target board ကို မပြောင်းလဲစေပါ။

## ၃။ SDK အတွက် သီးခြား APT ပတ်ဝန်းကျင် ပြင်ဆင်ရန်

Target သည် Ubuntu 26.04 `resolute` ဖြစ်သောကြောင့် ARM64 packages များကို Ubuntu Ports မှရယူပါ။ APT source list, index, state နှင့် download cache ကို `$SDK/apt` အောက်တွင် သီးခြားထားပါ။ ဤအဆင့်တွင် `sudo` မသုံးသလို host system package များလည်း မတင်ပါ။

```bash
mkdir -p "$SDK/apt/lists/partial" "$SDK/apt/cache/archives/partial" "$SDK/apt/empty"
touch "$SDK/apt/status"
cat > "$SDK/apt/isolated.conf" <<CONF
Dir::Etc::parts "$SDK/apt/empty";
Dir::Etc::main "/dev/null";
CONF
cat > "$SDK/apt/sources.list" <<'LIST'
deb [arch=arm64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] https://ports.ubuntu.com/ubuntu-ports resolute main universe
deb [arch=arm64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] https://ports.ubuntu.com/ubuntu-ports resolute-updates main universe
deb [arch=arm64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] https://ports.ubuntu.com/ubuntu-ports resolute-security main universe
LIST

APT_OPTS=(
  -o APT::Architecture=arm64
  -o APT::Architectures::=arm64
  -o Dir::Etc::sourcelist="$SDK/apt/sources.list"
  -o Dir::Etc::sourceparts="$SDK/apt/empty"
  -o Dir::State::lists="$SDK/apt/lists"
  -o Dir::State::status="$SDK/apt/status"
  -o Dir::Cache="$SDK/apt/cache"
  -o Debug::NoLocking=1
)
APT_CONFIG="$SDK/apt/isolated.conf" apt-get "${APT_OPTS[@]}" update
```

ဒီ source list သည် သင့် host ရှိ source list ကို မသုံးပါ။ Target OS က Armbian ဖြစ်သော်လည်း ဤအဆင့်သည် ၎င်း၏ Ubuntu base (`resolute`) packages များကိုသာ ရယူသည်။ Armbian သို့မဟုတ် အခြား vendor မှ package ကိုလိုပါက မှန်ကန်သော repository/keyring ကိုစစ်ပြီးမှ သီးခြားထည့်ပါ။

## ၄။ Target ARM64 development packages များ download လုပ်ရန်

စတင်ရန် glibc development files နဲ့ userspace kernel API headers ကိုယူပါ။ `libc6-dev` ကို board ၏ `libc6` version နှင့် **အတိအကျတူအောင်** ရွေးပါ။ APT dependency resolution သည် လိုအပ်သော ARM64 `.deb` ဖိုင်များကို SDK ၏ သီးခြား cache ထဲ download လုပ်မည်ဖြစ်ပြီး host သို့မဟုတ် board ပေါ်တွင် install မလုပ်ပါ။

```bash
LIBC_VERSION=$(sed -n '1p' "$BASE/libc6_version.txt")
APT_CONFIG="$SDK/apt/isolated.conf" apt-cache "${APT_OPTS[@]}" \
  policy libc6-dev:arm64 linux-libc-dev:arm64
TARGET_PACKAGES=(
  "libc6-dev:arm64=$LIBC_VERSION"
  linux-libc-dev:arm64
)
# App လိုအပ်သော target development package များကို ဤစာရင်းတွင် ထပ်ထည့်ပါ။
APT_CONFIG="$SDK/apt/isolated.conf" apt-get "${APT_OPTS[@]}" \
  --download-only --no-install-recommends install "${TARGET_PACKAGES[@]}"
```

ဥပမာ `libssl-dev:arm64` သို့မဟုတ် `libgpiod-dev:arm64` လို package ထပ်ထည့်မည်ဆိုပါက `apt-get` command မ run မီ `TARGET_PACKAGES` array ထဲထည့်ပြီး အထက်ပါ `apt-cache policy` ကို ထို package အမည်ဖြင့် run ကာ candidate ကို စစ်ပါ။ Ubuntu repository တွင်မရှိသော RKNN/RGA/MPP လို vendor packages များအတွက် ကိုက်ညီသော SDK/runtime ကို vendor ရင်းမြစ်မှ ရယူပါ။

`apt-get` က အတိအကျကိုက်ညီသော `libc6-dev` version ကို မတွေ့ပါက အခြား version ကို အတင်းမသုံးပါနှင့်၊ board ကို upgrade မလုပ်ပါနှင့်။ ထို version ၏ Ubuntu archive/snapshot မှ ARM64 `.deb` ကို ရှာဖွေအတည်ပြုပြီးမှ ဆက်လုပ်ပါ။
`linux-libc-dev` သည် userspace kernel API headers သာဖြစ်ပြီး လက်ရှိ `6.1.115-vendor-rk35xx` kernel module တည်ဆောက်ရန်လိုသည့် kernel headers မဟုတ်ပါ။

## ၅။ Packages များကို sysroot ထဲ extract လုပ်ရန်

Download လုပ်ထားသော package တစ်ခုစီ၏ အမည်၊ version နဲ့ architecture ကို မှတ်တမ်းတင်ပြီးမှ extract လုပ်ပါ။

```bash
shopt -s nullglob
DEBS=("$SDK/apt/cache/archives/"*.deb)
(( ${#DEBS[@]} > 0 )) || { echo 'No target .deb packages downloaded.' >&2; exit 1; }
: > "$SDK/metadata/target-packages.tsv"
for deb in "${DEBS[@]}"; do
    arch=$(dpkg-deb -f "$deb" Architecture)
    case "$arch" in
        arm64|all) ;;
        *) echo "Unexpected package architecture $arch: $deb" >&2; exit 1 ;;
    esac
    dpkg-deb -f "$deb" Package Version Architecture \
      | paste -sd $'\t' - >> "$SDK/metadata/target-packages.tsv"
    dpkg-deb -x "$deb" "$SDK/sysroot"
done
sha256sum "${DEBS[@]}" > "$SDK/metadata/target-packages.sha256"
```

Absolute symlink များ host system ဆီမထွက်သွားစေရန် sysroot အတွင်းသို့ ပြန်ညွှန်ပါ:

```bash
python3 - "$SDK/sysroot" <<'PY'
import os
import sys

root = os.path.abspath(sys.argv[1])
for directory, dirs, files in os.walk(root, followlinks=False):
    for name in dirs + files:
        path = os.path.join(directory, name)
        if os.path.islink(path):
            target = os.readlink(path)
            if target.startswith("/"):
                os.unlink(path)
                os.symlink(os.path.relpath(root + target, directory), path)
PY
```

လိုအပ်တဲ့ glibc development files ရှိကြောင်း စစ်ပါ:

```bash
test -e "$SDK/sysroot/usr/include/stdio.h"
find "$SDK/sysroot" \( -name crt1.o -o -name libc.so \) -print
```

## ၆။ လိုအပ်သော target runtime libraries ကို ထည့်ရန်

Package-based sysroot သည် **မိမိ download လုပ်ထားသော package များသာ** ပါသည်။ Archive နည်းလမ်းနှင့်မတူဘဲ board ရှိ `/usr/lib`, `/usr/local/lib`, `/opt` တို့ကို အလိုအလျောက် ကူးယူမည်မဟုတ်ပါ။

- App ၏ `DT_NEEDED` dependencies အတွက်လိုအပ်သော shared library တစ်ခုစီ၏ ARM64 runtime package ကို download/extract လုပ်ပါ သို့မဟုတ် app package ထဲသီးခြားထည့်ရန် ပြင်ဆင်ပါ။
- Library ကို link လုပ်ရန် header နဲ့ development symlink လိုပါက သက်ဆိုင်ရာ `-dev:arm64` package ကိုပါ download/extract လုပ်ပါ။
- RKNN/RGA/MPP ကဲ့သို့ vendor runtime များသည် Ubuntu repository တွင်မရှိခြင်း သို့မဟုတ် board ပေါ်တွင် လက်ဖြင့်တင်ထားခြင်း ဖြစ်နိုင်သည်။ ထိုအခါ သင့်လျော်သော ARM64 runtime, headers, libraries ကို vendor ထံမှ သီးခြားရယူပြီး license နဲ့ version ကိုက်ညီမှုကို စစ်ပါ။
- `/dev` device များ၊ kernel module, firmware နဲ့ driver တို့သည် sysroot library မဟုတ်ပါ။ App library ထည့်ခြင်းက လိုအပ်သော driver ကို ဖြည့်ပေးမည်မဟုတ်ပါ။ Kernel module build လုပ်ရန် vendor kernel `6.1.115-vendor-rk35xx` နဲ့ကိုက်ညီသော kernel source/build headers လိုအပ်သည်။

Board ပေါ်တွင်တင်ထားသော package အမည်/version နဲ့ လက်ဖြင့်တင်ထားသော vendor files များကို ခွဲသိရန် `packages.txt`, `libraries.txt`, `kernel_vendor.txt` inventory များကို တွဲဖတ်ပါ။ `libraries.txt` ထဲက file အားလုံးကို မျက်ကန်းကူးမည့်အစား app က တကယ်သုံးသော dependency များကိုသာ ထည့်ပါ။

## ၇။ CMake toolchain ဖိုင်ပြင်ရန်

```bash
cat > "$SDK/toolchain-arm64.cmake" <<'CMAKE'
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)
set(SDK_ROOT "$ENV{SDK}")
if(NOT SDK_ROOT)
  message(FATAL_ERROR "SDK environment variable is required")
endif()
set(CMAKE_SYSROOT "${SDK_ROOT}/sysroot")
set(CMAKE_FIND_ROOT_PATH "${CMAKE_SYSROOT}" "${SDK_ROOT}/stage")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(ENV{PKG_CONFIG_PATH} "")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "${CMAKE_SYSROOT}")
set(ENV{PKG_CONFIG_LIBDIR} "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/pkgconfig:${CMAKE_SYSROOT}/usr/lib/pkgconfig:${CMAKE_SYSROOT}/usr/share/pkgconfig")
CMAKE
```

Build မလုပ်မီ `SDK` variable ကို export လုပ်ထားပါ။ Toolchain ၏ C++ headers/runtime များသည် host ပေါ်ရှိ ARM64 cross compiler မှ ရနိုင်သော်လည်း board ၏ `libstdc++` version နဲ့ အလိုအလျောက်တူမည်ဟု မဆိုလိုပါ။ Compiler library path နဲ့ build ၏ ABI လိုအပ်ချက်များကို စစ်ပါ။

## ၈။ ရိုးရိုး C program ဖြင့် smoke test လုပ်ရန်

```bash
export SDK
cat > "$SDK/src/smoke.c" <<'C'
#include <stdio.h>
int main(void) {
    puts("ROCK 5B ARM64 sysroot test");
    return 0;
}
C

aarch64-linux-gnu-gcc --sysroot="$SDK/sysroot" \
  "$SDK/src/smoke.c" -o "$SDK/build/smoke"
file "$SDK/build/smoke"
aarch64-linux-gnu-readelf -l "$SDK/build/smoke" | grep interpreter
aarch64-linux-gnu-readelf -d "$SDK/build/smoke" | grep NEEDED
aarch64-linux-gnu-readelf --version-info "$SDK/build/smoke"
```

Binary သည် ARM64 ဖြစ်ပြီး interpreter သည် `/lib/ld-linux-aarch64.so.1` ဖြစ်ရမည်။ `readelf` မှ `GLIBC_*` လိုအပ်ချက်များကို target runtime နဲ့ နှိုင်းယှဉ်ပါ။ Host ၏ `ldd` ကို ARM64 binary အပေါ် မသုံးပါနှင့်။ နောက်ဆုံးတွင် [၀၆ — Sample deploy/test](06_deploy_sample_cpp.md) အဆင့်များအတိုင်း board ပေါ်မှာ run စမ်းပါ။

## ၉။ SDK ကိုမှတ်တမ်းတင်ပြီး အတည်ပြုရန်

- [ ] Board ကို package install/update မလုပ်ဘဲထားသည်။
- [ ] `system.txt`, `libc6_version.txt`, `packages.txt` နဲ့ APT source codename ကို SDK metadata ထဲ သိမ်းထားသည်။
- [ ] Download လုပ်ထားသော package များ၏ architecture `arm64`, version နဲ့ SHA256 ကို မှတ်တမ်းတင်ထားသည်။
- [ ] Sysroot ထဲ host/x86_64 library မဝင်ကြောင်း `file`/`readelf` ဖြင့် စစ်ထားသည်။
- [ ] လိုအပ်သော app နှင့် vendor runtime dependencies ကို စာရင်းပြုစုထားသည်။
- [ ] Cross-compiled app ကို board ပေါ်တွင် စမ်းသပ်ပြီး `not found` / ABI error မရှိကြောင်း အတည်ပြုထားသည်။

Inventory သာဖြင့် vendor `.so` အားလုံး သို့မဟုတ် app ၏ dependency အားလုံး ပါဝင်ကြောင်း မအာမခံနိုင်ပါ။ App code, `dlopen()` plugins, model files နှင့် hardware feature တစ်ခုချင်းစီကို သီးခြားစစ်ဆေးပါ။