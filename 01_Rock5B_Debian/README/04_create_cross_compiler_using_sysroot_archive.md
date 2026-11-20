# ၀၄ — Sysroot Archive သုံးပြီး Cross-Compile SDK ပြင်ဆင်ခြင်း

ဤနည်းတွင် board ၏ runtime libraries/headers ကို archive အဖြစ် host ဆီကူးပြီး ARM64 cross-toolchain နှင့်ပေါင်းသုံးမည်။ **Host x86_64/amd64 → ROCK 5B ARM64** ဖြစ်သည်။ GCC ကို source မှပြန်ဆောက်ခြင်းမဟုတ်ဘဲ host ပေါ်ရှိ native cross-toolchain packages ကိုသုံးမည်။

**Board မှာ package install/update မလုပ်ပါ။** App နှင့် app libraries ကို host မှ build လုပ်မည်။ Board ၏ kernel၊ glibc/loader နှင့် သက်ဆိုင်ရာ drivers ကို ဆက်သုံးမည်။ Vendor binary runtime အချို့ကို source မှ build မရနိုင်၍ compatible ARM64 binary သီးခြားလိုနိုင်သည်။

အောက်ပါ code blocks များကို **host ပေါ်ရှိ Bash terminal တစ်ခုတည်းတွင် အစဉ်လိုက်** run ပါ။ `SDK` နှင့် APT setting များကို အဆင့်များအကြား ဆက်သုံးမည်။

## ၁။ Inventory နှင့် SSH သတ်မှတ်ရန်

[၀၃](03_check_base_dependencies.md) ကို run ပြီးရရှိသော result folder ကို `BASE` ထဲထည့်ပါ။ `TARGET` ကို သင့် SSH user/IP ဖြင့်ပြင်ပါ။

```bash
set -euo pipefail
export BASE="$HOME/path/to/20261120-164734-192.168.1.15.fji2Cn"
export TARGET=rock@192.168.1.15
export SDK="$HOME/rock5b-sdk-archive"
mkdir -p "$SDK/base"

test -s "$BASE/system.txt"
test -s "$BASE/packages.txt"
grep -E '^(VERSION_CODENAME|UBUNTU_CODENAME)=resolute$' "$BASE/system.txt"
grep -F 'Architecture: arm64' "$BASE/system.txt"
sed -n '1p' "$BASE/libc6_version.txt" > "$SDK/base/libc6.version"
cp "$BASE/system.txt" "$BASE/packages.txt" "$BASE/apt_policy.txt" "$SDK/base/"
```

Inventory ထဲရှိ codename သည် `resolute` မဟုတ်ပါက နောက်ပိုင်း APT source list ကို ကိုက်ညီအောင်ပြင်ပါ၊ သို့မဟုတ် target distro အတွက် သင့်လျော်သော repository ကိုသုံးပါ။

## ၂။ Host tools တင်ရန်

[၀၃](03_check_base_dependencies.md) မှ baseline ကို အရင်ယူပါ။ အောက်ပါ package install command သည် Ubuntu host အတွက်ဖြစ်ပြီး **host ပေါ်မှာသာ** run ပါ။ Host distro ၏ package name/version မတူလျှင် မိမိ distro အတွက် ပြင်ဆင်ပါ။

```bash
sudo apt update
sudo apt install -y crossbuild-essential-arm64 cmake ninja-build pkg-config \
  python3 file binutils openssh-client ubuntu-keyring
mkdir -p "$SDK"/{sysroot,src,build,stage,metadata}
aarch64-linux-gnu-g++ --version | tee "$SDK/metadata/compiler.txt"
test "$(dpkg --print-architecture)" = amd64
```

## ၃။ Board မှ archive ကို host ဆီကူးရန်

SSH user သည် အောက်ပါ directory များကို ဖတ်နိုင်ရမည်။ Archive ကို remote board ပေါ်တွင်မဖန်တီးဘဲ SSH stream ဖြင့် host ဆီကူးသည်။ Board တွင် package update/install မလုပ်ပါ။

```bash
set -o pipefail
ssh "$TARGET" 'sh -s' > "$SDK/base/target-libs.tar" <<'SH'
set -eu
cd /
set --
for p in lib lib64 usr/lib usr/include usr/share/pkgconfig usr/local/lib usr/local/include; do
    if [ -e "$p" ] || [ -L "$p" ]; then
        set -- "$@" "$p"
    fi
done
tar -cf - "$@"
SH

test -s "$SDK/base/target-libs.tar"
tar -tf "$SDK/base/target-libs.tar" > "$SDK/metadata/archive-files.txt"
sha256sum "$SDK/base/target-libs.tar" > "$SDK/metadata/target-libs.tar.sha256"
```

SSH/tar အမှား သို့မဟုတ် permission error ဖြစ်လျှင် ဆက်မလုပ်ပါနှင့်။ `/opt` အောက်တွင် manually-installed vendor files ရှိပါက ဤစာရင်းတွင် မပါနိုင်သဖြင့် app လိုအပ်သောဖိုင်များကို သီးခြားစစ်ဆေးပါ။

## ၄။ Target sysroot ပြင်ရန်

`sysroot` = host ပေါ်က build headers/libraries။ `stage` = board သို့ပို့မည့် app ဖိုင်များ။ **Sysroot အကုန် deploy မလုပ်ပါ။**

```bash
test -s "$SDK/base/target-libs.tar"
if [ -e "$SDK/sysroot" ] && [ -n "$(find "$SDK/sysroot" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    echo "Sysroot path is not empty; back it up and choose an empty path: $SDK/sysroot" >&2
    exit 1
fi
mkdir -p "$SDK/sysroot"
tar -tf "$SDK/base/target-libs.tar" > "$SDK/metadata/archive-files.txt"
tar --no-same-owner -xf "$SDK/base/target-libs.tar" -C "$SDK/sysroot"
```

Sysroot အဟောင်းကို အစားထိုးမည့်အစား backup ပြီးမှ clean directory ဖြင့်စပါ။ Absolute symlink များကို host system ထဲ မလွတ်သွားစေရန် archive extract ပြီးနောက် symlink များကို sysroot အတွင်းသို့ ပြန်ညွှန်ပါ။ Development package များထည့်ပြီးမှ အောက်ပါလုပ်ဆောင်ချက်ကို run ပါ။

### မပါသေးသော development headers ကို host မှ download လုပ်ရန်

Host system repo မပြောင်းဘဲ SDK အတွင်း သီးခြား APT configuration သုံးမည်။ Target `libc6` နှင့် **တူညီသော version** ၏ `libc6-dev:arm64` ကိုယူမည်။ Board package install မလုပ်ပါ။

```bash
mkdir -p "$SDK/apt/lists/partial" "$SDK/apt/cache/archives/partial" "$SDK/apt/empty"
touch "$SDK/apt/status"
# Host ၏ APT hooks/config မပါစေရန်။
cat > "$SDK/apt/isolated.conf" <<CONF
Dir::Etc::parts "$SDK/apt/empty";
Dir::Etc::main "/dev/null";
CONF
cat > "$SDK/apt/sources.list" <<'LIST'
deb [arch=arm64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] https://ports.ubuntu.com/ubuntu-ports resolute main universe
deb [arch=arm64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] https://ports.ubuntu.com/ubuntu-ports resolute-updates main universe
deb [arch=arm64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] https://ports.ubuntu.com/ubuntu-ports resolute-security main universe
LIST
# အောက်ပါ codename/keyring သည် ဤ ROCK 5B ၏ Ubuntu 26.04 resolute inventory အတွက်ဖြစ်သည်။
# အခြား target ဖြစ်ပါက /etc/os-release ထဲရှိ codename နှင့်ကိုက်ညီသော repository/keyring ကိုသုံးပါ။
# ဤ shell ထဲတွင်သာ အသုံးပြုမည့် APT options။
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
# sudo မသုံးရန်။ Host/board system package မပြောင်းပါ။
APT_CONFIG="$SDK/apt/isolated.conf" apt-get "${APT_OPTS[@]}" update
LIBC_VERSION=$(tr -d '\n' < "$SDK/base/libc6.version")
# Download package plus dependency closure into the SDK-local cache; do not install on host or board.
APT_CONFIG="$SDK/apt/isolated.conf" apt-get "${APT_OPTS[@]}" \
  --download-only --no-install-recommends install \
  "libc6-dev:arm64=$LIBC_VERSION" linux-libc-dev:arm64
shopt -s nullglob
debs=("$SDK/apt/cache/archives/"*.deb)
(( ${#debs[@]} > 0 )) || { echo 'No target .deb packages downloaded.' >&2; exit 1; }
for deb in "${debs[@]}"; do
    arch=$(dpkg-deb -f "$deb" Architecture)
    case "$arch" in
        arm64|all) ;;
        *) echo "Unexpected package architecture $arch: $deb" >&2; exit 1 ;;
    esac
    dpkg-deb -f "$deb" Package Version Architecture
    dpkg-deb -x "$deb" "$SDK/sysroot"
done
sha256sum "${debs[@]}" > "$SDK/metadata/dev-packages.sha256"
: > "$SDK/metadata/dev-packages.tsv"
for deb in "${debs[@]}"; do
    dpkg-deb -f "$deb" Package Version Architecture \
      | paste -sd $'\t' - >> "$SDK/metadata/dev-packages.tsv"
done
```

`libc6-dev` version မရတော့လျှင် **ရပ်ပါ**။ Ubuntu archive/snapshot မှ matching version ကို ရှာပါ။ Board ကို upgrade လုပ်ခြင်း၊ အခြား glibc version ကို အစားထိုးခြင်းမလုပ်ပါနှင့်။ `linux-libc-dev` သည် userspace kernel API headers ဖြစ်ပြီး kernel module build headers မဟုတ်ပါ။

Absolute symlink များကို sysroot အတွင်းသို့ ပြောင်းပါ:

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

စစ်ရန်:

```bash
test -e "$SDK/sysroot/usr/include/stdio.h"
find "$SDK/sysroot" \( -name crt1.o -o -name libc.so \) -print
test -e "$SDK/sysroot/lib/ld-linux-aarch64.so.1"
file "$SDK/sysroot/lib/ld-linux-aarch64.so.1"
```

`stdio.h` သို့မဟုတ် startup/linker files မတွေ့လျှင် cross-build မစမီ package extraction ကိုပြန်စစ်ပါ။ Archive သည် board တွင်မရှိသော headers ကို ဖြည့်ပေးမည်မဟုတ်ပါ။


## ၅။ CMake toolchain ဖိုင်

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
# C++ headers/compiler runtime ကို ARM64 cross-toolchain ကပေးနိုင်သည်။
CMAKE
```

**သတိပြုရန်:** Cross compiler ၏ built-in `libstdc++`/`libgcc` သည် board ၏ runtime နှင့် အလိုအလျောက်တူမည်ဟု မယူဆပါနှင့်။ `aarch64-linux-gnu-g++ -print-file-name=libstdc++.so` နှင့် verbose link output ကိုစစ်ပြီး build ၏ `GLIBC_*`/`GLIBCXX_*` လိုအပ်ချက်များကို target runtime နှင့် နှိုင်းယှဉ်ပါ။ Host compiler သည် target environment အတွက် မသင့်တော်ပါက သင့်လျော်သည့် cross-toolchain ကို သီးခြားပြင်ဆင်ပါ။

## ၆။ App dependencies ကို source မှ build ရန်

Dependency တစ်ခုစီ၏ source version/checksum ကိုမှတ်ပြီး ARM64 အတွက် build ပါ။ CMake library နမူနာ:

```bash
# my_dependency ကို မိမိ library အမည်ဖြင့်ပြင်ပါ။
cmake -S "$SDK/src/my_dependency" -B "$SDK/build/my_dependency" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$SDK/toolchain-arm64.cmake" \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_INSTALL_PREFIX=/opt/my_project -DCMAKE_INSTALL_LIBDIR=lib \
  '-DCMAKE_INSTALL_RPATH=$ORIGIN' -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=OFF
cmake --build "$SDK/build/my_dependency" --verbose
DESTDIR="$SDK/stage" cmake --install "$SDK/build/my_dependency"
```

- Dependency အရင် build ပြီး app နောက်မှ build ပါ။ CMake မှရှာရန် `-DCMAKE_PREFIX_PATH=/opt/my_project` ထည့်ပါ။
- Library အလိုက် cross-build options ကွာသည်။ Host tool/code generator နှင့် ARM64 library ကိုခွဲပါ။
- Staged `.pc` သုံးသည့် dependency အတွက် staging-aware pkg-config config သီးခြားလိုသည်။ Host x86_64 `.pc` ကိုမသုံးပါနှင့်။
- Executable RPATH = `$ORIGIN/../lib`၊ private `.so` RPATH = `$ORIGIN` ထားပါ။ Transitive dependencies ပါစစ်ပါ။

## ၇။ Deploy package စည်းမျဉ်း

```text
/opt/my_project/
├── bin/       app executable
├── lib/       app အတွက်လိုအပ်သော ARM64 .so နှင့် SONAME links
├── share/     models၊ assets၊ plugin data
└── licenses/  dependencies ၏ licenses
```

- `.o`၊ build headers၊ `.a` နှင့် sysroot ကို runtime package ထဲမထည့်ပါနှင့်။ လိုအပ်သော plugins/data ကိုတော့ထည့်ပါ။
- Base glibc/loader၊ kernel modules၊ `/usr/lib`၊ `/etc/ld.so.conf` ကိုမပြောင်းပါနှင့်။ `ldconfig` run မလိုပါ။
- `libstdc++`/`libgcc` လို runtime မလုံလောက်လျှင် matching ARM64 runtime ကို private `lib/` တွင်ထည့်ပြီး ABI စစ်ပါ။ x86_64 `.so` မကူးပါနှင့်။
- App-only deployment ဖြင့် missing kernel driver/firmware ကို မဖြေရှင်းနိုင်ပါ။

ဆက်ရန်: [၀၆ — Sample C++ နှင့် SCP deploy](06_deploy_sample_cpp.md)။

ရင်းမြစ်: [CMake cross-compilation](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html) · [GCC sysroot](https://gcc.gnu.org/onlinedocs/gcc/Directory-Options.html) · [Loader / RUNPATH](https://man7.org/linux/man-pages/man8/ld.so.8.html)
