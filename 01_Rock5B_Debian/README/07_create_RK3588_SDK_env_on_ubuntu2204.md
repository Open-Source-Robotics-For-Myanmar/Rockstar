# ROCK 5B / RK3588 SDK — Ubuntu 22.04 host

ဤလမ်းညွှန်က **Ubuntu 22.04 x86_64 host မှ ROCK 5B ၏ ARM64 Linux application များတည်ဆောက်ရန်** ဖြစ်သည်။ Host တွင် cross GCC/CMake နှင့် RKNN C/C++ development files ကိုပြင်ဆင်ပြီး board ပေါ်တွင် sample ကို စမ်းမည်။ Board OS image၊ bootloader၊ kernel build သို့မဟုတ် driver installation လမ်းညွှန် မဟုတ်ပါ။

SDK ကို အလွှာသုံးခုအဖြစ် ခွဲထားသည်—

| အလွှာ | လုပ်ဆောင်ချက် |
| --- | --- |
| Cross-toolchain | Host ပေါ် run သော GCC/G++ က ARM64 machine code ထုတ်သည် |
| Application libraries | ARM64 headers/runtime: အခြေခံ libc/libstdc++ နှင့် optional RKNN/RGA/MPP |
| Board runtime | Board OS loader/libraries၊ kernel drivers နှင့် device access |

RK3588 အတွက် compiler သီးသန့်အသစ် မလိုပါ။ Generic `aarch64-linux-gnu` compiler ကိုသုံးနိုင်ပြီး hardware acceleration အတွက် vendor API/runtime နှင့် driver ကိုက်ညီရန် ထပ်လိုသည်။ **CPU compile flags ပြောင်းရုံဖြင့် NPU/GPU ကို အသုံးမပြုနိုင်ပါ။** [Rockchip RKNN architecture](https://github.com/airockchip/rknn-toolkit2/tree/v2.3.2)

## ၁။ သိထားသော board baseline နှင့် ရွေးထားသောနည်း

Repository ထဲရှိ **2026-11-20 inventory** မှ အချက်များဖြစ်သည်။ လက်ရှိ board ကိုပြန်ချိတ်စစ်ထားသောရလဒ် မဟုတ်ပါ။

| အချက် | သိမ်းထားသော inventory |
| --- | --- |
| Board | Radxa ROCK 5B / RK3588 / arm64 |
| OS | Armbian 26.8.3 / Ubuntu `resolute` |
| Kernel | `6.1.115-vendor-rk35xx` |
| glibc | `2.43` |
| libstdc++ runtime | `16-20260322-1ubuntu1` |
| RKNPU driver | `0.9.8` |
| RKNN user-space runtime | Inventory မှ ရှိကြောင်း မအတည်ပြုနိုင်သေး |

`libdwarves_reorganize.so` သည် inventory regex တွင်ပါလာသော်လည်း Rockchip `librga.so` မဟုတ်ပါ။ Kernel driver ရှိခြင်းက `librknnrt.so` နှင့် headers ရှိခြင်းကို မဆိုလိုပါ။

ဒီလမ်းညွှန်သည် **Jammy cross-toolchain baseline + app သီးသန့် vendor libraries** နည်းကိုသုံးသည်။ Board ရှိ glibc 2.43 ကို host သို့အစားထိုးမတင်ပါ။ Older glibc baseline ဖြင့် build လုပ်ထားသော application သည် newer target တွင် run နိုင်လေ့ရှိသော်လည်း dependency/symbol versions နှင့် board smoke test ဖြင့် အတည်ပြုရမည်။

Board ၏ distro libraries အသစ်များကို တိုက်ရိုက် link လုပ်ရန်လိုလာလျှင် target-matched development sysroot/toolchain ကို ထပ်ပြင်ရမည်။ GCC 11 C++ headers၊ GCC 16 development files နှင့် board libc ကို ရောထည့်ခြင်း မလုပ်ပါနှင့်။ Archive တစ်ခုရှိရုံဖြင့် development sysroot ပြည့်စုံသည်ဟု မယူဆပါနှင့်။

## ၂။ Host dependencies နှင့် workspace

အောက်ပါ commands အားလုံးကို **host Bash terminal** တွင်လုပ်ပါ။ `Board terminal` ဟု ရေးထားသောအပိုင်းသာ board ပေါ်လုပ်ရန်ဖြစ်သည်။ Error ဖြစ်လျှင် ထိုအဆင့်မှာရပ်ပြီး ဖြေရှင်းပါ။

သီးသန့် shell ဖွင့်ပါ။ `set -euo pipefail` ကြောင့် error တက်လျှင် ဒီ SDK shell မှထွက်မည်၊ parent terminal ကတော့ ကျန်မည်။ အဆင့်တစ်ခု error ဖြစ်ပြီးနောက် ကျန် commands ကို မဆက်ပါနှင့်။

```bash
bash --noprofile --norc
```

```bash
set -euo pipefail
uname -m
cat /etc/os-release
```

Expected: `x86_64`, Ubuntu `22.04`။ Generic SDK [06_create_ARMv8-A_SDK_env_on_ubuntu2204.md](06_create_ARMv8-A_SDK_env_on_ubuntu2204.md) လုပ်ထားပြီးလျှင် packages တချို့ရှိပြီးသားဖြစ်မည်။ ဤဖိုင်ကို သီးခြားစလုပ်လည်းရသည်။

```bash
sudo apt update
sudo apt install -y \
  build-essential cmake ninja-build pkg-config file git ca-certificates \
  gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  binutils-aarch64-linux-gnu libc6-dev-arm64-cross \
  openssh-client python3 python3-venv python3-pip libgl1 libglib2.0-0

aarch64-linux-gnu-g++ -dumpmachine
aarch64-linux-gnu-g++ --version
```

Expected triple: `aarch64-linux-gnu`။ `:arm64` packages သို့မဟုတ် target `resolute` repositories ကို host APT ထဲထည့်ရန်မလိုပါ။ [Jammy cross G++](https://packages.ubuntu.com/jammy/g++-aarch64-linux-gnu)

Workspace အသစ်သုံးပါ။ အောက်ပါ guard က ရှိပြီးသား SDK ကို ထပ်မရေးစေရန်ဖြစ်သည်။ Setup တစ်ဝက်တွင်ရပ်ခဲ့လျှင် ဖိုင်တွေစစ်ပြီး ကျန်အဆင့်မှဆက်ပါ၊ directory ကိုဖျက်ပြီး အစမှပြန်လုပ်ရန်မလိုပါ။

```bash
export RK3588_SDK="$HOME/Desktop/Git/Rockstar/01_Rock5B_Debian/SDK_Ubuntu2204"
if [ -e "$RK3588_SDK" ]; then
    echo "Workspace already exists; inspect it or choose a new path." >&2
    exit 1
fi
mkdir -p "$RK3588_SDK"/{bin,toolchains,src/smoke,build,prefix/include,prefix/lib,metadata,models}
export ROCK5B_TARGET=mr_robot@192.168.1.15
```

`ROCK5B_TARGET` ကို ကိုယ့် SSH username/IP အမှန်ဖြင့်ပြောင်းပါ။ Host SDK နှင့် board deployment ဖိုင်များသည် သီးခြားနေရာများဖြစ်သည်။

## ၃။ Board ကို read-only ပြန်စစ်ပါ

```bash
ssh "$ROCK5B_TARGET" 'sh -s' > "$RK3588_SDK/metadata/board.txt" <<'BOARD'
set -eu
uname -m
uname -r
cat /etc/os-release
getconf GNU_LIBC_VERSION
tr '\0' '\n' < /proc/device-tree/compatible
ldconfig -p 2>/dev/null | grep -E 'librknnrt|librga\.|librockchip_mpp|libstdc\+\+' || true
ls -l /dev/dri /dev/rknpu* /dev/rga /dev/mpp_service 2>/dev/null || true
for p in /sys/kernel/debug/rknpu/version /sys/kernel/debug/rkrga/driver_version /proc/rkrga/driver_version; do
    if [ -r "$p" ]; then printf '\n%s\n' "$p"; cat "$p"; fi
done
BOARD
cat "$RK3588_SDK/metadata/board.txt"
```

Expected: `aarch64`, `rockchip,rk3588`။ Debugfs file ကို permission ကြောင့်မဖတ်ရခြင်း/မရှိခြင်းတစ်ခုတည်းဖြင့် driver မရှိဟု မဆုံးဖြတ်ပါနှင့်။ NPU device သည် kernel ပေါ်မူတည်ပြီး DRM render node မှတစ်ဆင့်လည်း အသုံးပြုနိုင်သည်။

အသေးစိတ် inventory လိုလျှင် repo ရှိ `scripts/03_check_base_dependencies.sh` ကို host မှ run နိုင်သည်။ Report ကိုဖတ်ရာတွင် runtime နဲ့ development package လိုအပ်ချက်ကို သီးခြားခွဲပါ။ ဒီ SDK နည်းအတွက် board တွင် `apt install` မလိုပါ။

## ၄။ SDK activation နှင့် CMake toolchain

```bash
cat > "$RK3588_SDK/env.sh" <<'ENV'
export RK3588_SDK="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export CC=/usr/bin/aarch64-linux-gnu-gcc
export CXX=/usr/bin/aarch64-linux-gnu-g++
export AR=/usr/bin/aarch64-linux-gnu-ar
export RANLIB=/usr/bin/aarch64-linux-gnu-ranlib
export STRIP=/usr/bin/aarch64-linux-gnu-strip
export PKG_CONFIG="$RK3588_SDK/bin/rk3588-pkg-config"
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH LD_LIBRARY_PATH
unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS CMAKE_PREFIX_PATH
unset PKG_CONFIG_PATH PKG_CONFIG_LIBDIR PKG_CONFIG_SYSROOT_DIR
ENV

cat > "$RK3588_SDK/bin/rk3588-pkg-config" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
sdk_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export PKG_CONFIG_PATH=
export PKG_CONFIG_LIBDIR="$sdk_dir/prefix/lib/pkgconfig:$sdk_dir/prefix/share/pkgconfig:/usr/aarch64-linux-gnu/lib/pkgconfig:/usr/aarch64-linux-gnu/share/pkgconfig"
unset PKG_CONFIG_SYSROOT_DIR
exec /usr/bin/pkg-config "$@"
SH
chmod +x "$RK3588_SDK/bin/rk3588-pkg-config"

cat > "$RK3588_SDK/toolchains/rk3588.cmake" <<'CMAKE'
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER /usr/bin/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/aarch64-linux-gnu-g++)
set(CMAKE_AR /usr/bin/aarch64-linux-gnu-ar)
set(CMAKE_RANLIB /usr/bin/aarch64-linux-gnu-ranlib)
set(CMAKE_STRIP /usr/bin/aarch64-linux-gnu-strip)
set(CMAKE_C_FLAGS_INIT "-march=armv8-a -mtune=generic")
set(CMAKE_CXX_FLAGS_INIT "-march=armv8-a -mtune=generic")
get_filename_component(RK3588_SDK_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(CMAKE_FIND_ROOT_PATH "${RK3588_SDK_ROOT}/prefix" /usr/aarch64-linux-gnu)
list(PREPEND CMAKE_PREFIX_PATH "${RK3588_SDK_ROOT}/prefix")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_FIND_USE_PACKAGE_REGISTRY FALSE)
set(CMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY FALSE)
set(PKG_CONFIG_EXECUTABLE "${RK3588_SDK_ROOT}/bin/rk3588-pkg-config"
    CACHE FILEPATH "Target pkg-config" FORCE)
CMAKE

source "$RK3588_SDK/env.sh"
```

ကျန် build commands ကို ဒီ SDK shell ထဲတွင်လုပ်ပါ။ `exit` ဖြင့်ထွက်နိုင်သည်။ Shell ပိတ်သွားလျှင် `RK3588_SDK` နှင့် `ROCK5B_TARGET` လို environment variable များကို terminal အသစ်တွင် အလိုအလျောက်မရနိုင်ပါ။ Terminal အသစ်ဖွင့်ပြီး အောက်ပါအတိုင်း SDK ကို ပြန် activate လုပ်ပါ။ ဤလမ်းကြောင်းသည် အပေါ်တွင်တည်ဆောက်ထားသော `SDK_Ubuntu2204` directory ကိုညွှန်သည်။

```bash
export RK3588_SDK="$HOME/Desktop/Git/Rockstar/01_Rock5B_Debian/SDK_Ubuntu2204"
test -s "$RK3588_SDK/env.sh"
source "$RK3588_SDK/env.sh"
export ROCK5B_TARGET=mr_robot@192.168.1.15
cd "$RK3588_SDK"
```

`ROCK5B_TARGET` ကို မိမိ board SSH username/IP ဖြင့် အစားထိုးပါ။ `test -s` မအောင်လျှင် `env.sh` ကို မဖန်တီးရသေးခြင်း သို့မဟုတ် SDK path မမှန်ခြင်းဖြစ်နိုင်သဖြင့် ထိုအကြောင်းရင်းကိုစစ်ပြီးမှ ဆက်လုပ်ပါ။ `source` သည် လက်ရှိ terminal ထဲတွင် environment ကို activate လုပ်သည်။

`CMAKE_SYSROOT` မသတ်မှတ်ထားခြင်းသည် ရည်ရွယ်ချက်ရှိသည်—Ubuntu cross GCC ၏ built-in libc/C++ search paths ကိုသုံးပြီး `prefix` တွင် vendor libraries သာထပ်ထည့်ထားသည်။ RK3588 CPU core အားလုံးတွင် run နိုင်ရန် generic ARMv8-A baseline ကိုထားသည်။ [CMake toolchains](https://cmake.org/cmake/help/v3.22/manual/cmake-toolchains.7.html)

## ၅။ RKNN C/C++ SDK ရယူပါ

**CPU-only app အတွက် ဤအဆင့်မလိုပါ။** NPU စမ်းမည်ဆိုလျှင် အောက်ပါ RKNN setup ကိုလုပ်ပါ။ ဤ guide တွင် Radxa documentation တွင်အသုံးပြုထားသော **v2.3.2** ကို reproducible starting version အဖြစ်ရွေးထားသည်၊ latest ဟု မဆိုလိုပါ။ Board driver နှင့် အမှန်တကယ်ကိုက်ကြောင်း hardware test မပြီးမချင်း မအာမခံပါ။ [Radxa RKNN examples](https://docs.radxa.com/en/rock5/rock5b/app-development/ai/rknn-model-zoo)

```bash
git clone --depth 1 --branch v2.3.2 \
  https://github.com/airockchip/rknn-toolkit2.git \
  "$RK3588_SDK/src/rknn-toolkit2"
git -C "$RK3588_SDK/src/rknn-toolkit2" rev-parse HEAD \
  > "$RK3588_SDK/metadata/rknn-commit.txt"

RKNN_API_DIR="$RK3588_SDK/src/rknn-toolkit2/rknpu2/runtime/Linux/librknn_api"
test -s "$RKNN_API_DIR/include/rknn_api.h"
test -s "$RKNN_API_DIR/aarch64/librknnrt.so"
cp -a "$RKNN_API_DIR/include/." "$RK3588_SDK/prefix/include/"
cp -L "$RKNN_API_DIR/aarch64/librknnrt.so" "$RK3588_SDK/prefix/lib/"
file "$RK3588_SDK/prefix/lib/librknnrt.so"
aarch64-linux-gnu-readelf -d "$RK3588_SDK/prefix/lib/librknnrt.so"
aarch64-linux-gnu-readelf --version-info "$RK3588_SDK/prefix/lib/librknnrt.so" \
  > "$RK3588_SDK/metadata/rknn-symbol-versions.txt"
sha256sum "$RK3588_SDK/prefix/lib/librknnrt.so" \
  > "$RK3588_SDK/metadata/rknn-runtime.sha256"
```

`file` က AArch64 ELF ပြရမည်။ Git LFS pointer/text ပြလျှင် binary အမှန်မရသေးပါ။ `NEEDED` libraries နှင့် required symbol versions ကို target ကပေးနိုင်ရမည်။ Android `arm64-v8a` runtime ကို Linux runtime အစားမသုံးပါနှင့်။ Header နှင့် runtime ကို release တူမှယူပါ။

ဒီ library ကို host `/usr/lib` သို့မကူးပါ။ Board system library ကိုလည်း မအစားထိုးပါ။ Application folder ထဲတွင်ပဲထားမည်။

## ၆။ CPU sample နှင့် optional RKNN probe ဖန်တီးပါ

```bash
cat > "$RK3588_SDK/src/smoke/hello.cpp" <<'CPP'
#include <iostream>
int main() {
    std::cout << "Hello ROCK 5B / RK3588\n";
    return 0;
}
CPP

cat > "$RK3588_SDK/src/smoke/rknn_probe.cpp" <<'CPP'
#include <cstdio>
#include "rknn_api.h"
int main(int argc, char** argv) {
    if (argc != 2) {
        std::puts("RKNN runtime loaded. Pass an RK3588 .rknn model to test initialization.");
        return argc == 1 ? 0 : 2;
    }
    rknn_context ctx = 0;
    // size=0 tells RKNN to interpret model as a file path.
    int rc = rknn_init(&ctx, argv[1], 0, 0, nullptr);
    if (rc != RKNN_SUCC) {
        std::fprintf(stderr, "rknn_init failed: %d\n", rc);
        return 1;
    }
    rknn_sdk_version versions{};
    rc = rknn_query(ctx, RKNN_QUERY_SDK_VERSION, &versions, sizeof(versions));
    if (rc == RKNN_SUCC) {
        std::printf("Runtime: %s\nDriver: %s\n", versions.api_version, versions.drv_version);
        std::puts("PASS: model initialization and version query; inference not tested.");
    } else {
        std::fprintf(stderr, "rknn_query failed: %d\n", rc);
    }
    const int cleanup = rknn_destroy(ctx);
    return rc == RKNN_SUCC && cleanup == RKNN_SUCC ? 0 : 1;
}
CPP

cat > "$RK3588_SDK/src/smoke/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.22)
project(rk3588_smoke LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
option(WITH_RKNN "Build the RKNN runtime probe" OFF)
set(CMAKE_INSTALL_RPATH "$ORIGIN/../lib")
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH FALSE)
add_executable(hello_rk3588 hello.cpp)
install(TARGETS hello_rk3588 RUNTIME DESTINATION bin)
if(WITH_RKNN)
    find_path(RKNN_INCLUDE_DIR rknn_api.h REQUIRED)
    find_library(RKNN_LIBRARY NAMES rknnrt REQUIRED)
    add_executable(rknn_probe rknn_probe.cpp)
    target_include_directories(rknn_probe PRIVATE "${RKNN_INCLUDE_DIR}")
    target_link_libraries(rknn_probe PRIVATE "${RKNN_LIBRARY}")
    install(TARGETS rknn_probe RUNTIME DESTINATION bin)
    install(FILES "${RKNN_LIBRARY}" DESTINATION lib)
endif()
CMAKE

cmake -S "$RK3588_SDK/src/smoke" -B "$RK3588_SDK/build/cpu" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$RK3588_SDK/toolchains/rk3588.cmake" \
  -DCMAKE_BUILD_TYPE=Release -DWITH_RKNN=OFF
cmake --build "$RK3588_SDK/build/cpu" --parallel "$(nproc)"
cmake --install "$RK3588_SDK/build/cpu" --prefix "$RK3588_SDK/deploy/cpu"
```

အဆင့် ၅ လုပ်ပြီးမှ RKNN probe ကို build ပါ—

```bash
cmake -S "$RK3588_SDK/src/smoke" -B "$RK3588_SDK/build/npu" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$RK3588_SDK/toolchains/rk3588.cmake" \
  -DCMAKE_BUILD_TYPE=Release -DWITH_RKNN=ON
cmake --build "$RK3588_SDK/build/npu" --parallel "$(nproc)"
cmake --install "$RK3588_SDK/build/npu" --prefix "$RK3588_SDK/deploy/npu"

file "$RK3588_SDK/deploy/npu/bin/"*
aarch64-linux-gnu-readelf -d "$RK3588_SDK/deploy/npu/bin/rknn_probe"
aarch64-linux-gnu-readelf --version-info "$RK3588_SDK/deploy/npu/bin/rknn_probe"
```

Expected: AArch64 binaries၊ `librknnrt.so` dependency နှင့် `$ORIGIN/../lib` RUNPATH။ `prefix/lib` ထဲက runtime ၏ SONAME က filename နှင့်မတူလျှင် SONAME အမည်ကို deployment folder တွင်ပါ ရှိစေရမည်။

## ၇။ Board ပေါ် CPU/runtime smoke test လုပ်ပါ

ပထမဆုံး CPU-only build ကိုစမ်းရန် `DEPLOY_KIND=cpu` ကိုသုံးပါ။ အဆင့် ၅/၆ မှ RKNN build နှင့် install အောင်မြင်ပြီးမှ `DEPLOY_KIND=npu` ဟုပြောင်းပါ။ Deploy folder မရှိလျှင် မဖန်တီးထားသေးသော build/install ဖြစ်သောကြောင့် အဲဒီအဆင့်ကို အရင်အောင်မြင်အောင်လုပ်ပါ။ Archive ကို board user home ရှိ staging folder သို့သာ SCP လုပ်မည်။ App ကို `/opt/rockstar/rk3588-sdk-tests/<DEPLOY_TAG>/` သီးသန့် directory ထဲ install လုပ်မည်။ `/opt` ထဲက အခြား directory များကို မထိပါ၊ ရှိပြီးသား deploy folder ကိုလည်း ထပ်မရေးပါ။

```bash
DEPLOY_KIND=cpu
DEPLOY_TAG="rk3588-smoke-$(date +%Y%m%d-%H%M%S)"
DEPLOY_ARCHIVE="$RK3588_SDK/$DEPLOY_TAG.tar.gz"
if [ ! -d "$RK3588_SDK/deploy/$DEPLOY_KIND" ]; then
    printf 'Missing deploy directory: %s\nBuild and install this target first.\n' \
      "$RK3588_SDK/deploy/$DEPLOY_KIND" >&2
else
    tar -czf "$DEPLOY_ARCHIVE" -C "$RK3588_SDK/deploy/$DEPLOY_KIND" . &&
    (cd "$RK3588_SDK" && sha256sum "$DEPLOY_TAG.tar.gz" > "$DEPLOY_TAG.tar.gz.sha256") &&
    ssh "$ROCK5B_TARGET" "mkdir -p rk3588-sdk-tests/$DEPLOY_TAG" &&
    scp "$DEPLOY_ARCHIVE" "$DEPLOY_ARCHIVE.sha256" \
      "$ROCK5B_TARGET:rk3588-sdk-tests/$DEPLOY_TAG/" &&
    printf 'Board folder: ~/rk3588-sdk-tests/%s\n' "$DEPLOY_TAG" &&
    ssh "$ROCK5B_TARGET"
fi
```

**Board terminal:** `DEPLOY_TAG` ကို host ကထုတ်ပြထားသော folder name ဖြင့်ဖြည့်ပါ။

```bash
set -eu
DEPLOY_TAG=rk3588-smoke-YYYYMMDD-HHMMSS
STAGE_DIR="$HOME/rk3588-sdk-tests/$DEPLOY_TAG"
DEPLOY_DIR="/opt/rockstar/rk3588-sdk-tests/$DEPLOY_TAG"
cd "$STAGE_DIR"
sha256sum -c "$DEPLOY_TAG.tar.gz.sha256"
if [ -e "$DEPLOY_DIR" ]; then
    printf 'Deployment directory already exists; choose a new DEPLOY_TAG: %s\n' \
      "$DEPLOY_DIR" >&2
    exit 1
fi
sudo install -d -m 0755 "$DEPLOY_DIR"
sudo tar --no-same-owner -xzf "$DEPLOY_TAG.tar.gz" -C "$DEPLOY_DIR"
cd "$DEPLOY_DIR"
ldd ./bin/hello_rk3588
./bin/hello_rk3588
```

Expected: `Hello ROCK 5B / RK3588`။ `not found` / `GLIBC_*` / `GLIBCXX_*` errors မရှိရပါ။ RKNN package ဖြစ်လျှင် ဆက်စမ်းပါ—

```bash
ldd bin/rknn_probe
ldd lib/librknnrt.so
./bin/rknn_probe
```

`librknnrt.so` ကို ဒီ test folder ၏ `lib/` မှယူနေကြောင်း `ldd` ဖြင့်စစ်ပါ။ Model argument မပါသေးသော probe သည် runtime load ဖြစ်ကြောင်းသာ စစ်သည်၊ **NPU hardware အလုပ်လုပ်ကြောင်း မစစ်ရသေးပါ။** `exit` ဖြင့် host terminal သို့ပြန်ထွက်ပါ။

## ၈။ Host model-conversion environment — NPU သုံးမှလုပ်ရန်

RKNN-Toolkit2 သည် **host Python model converter**၊ `librknnrt.so` သည် **board C/C++ runtime** ဖြစ်သည်။ C/C++ inference သုံးလျှင် board တွင် Python RKNN-Toolkit-Lite2 install မလိုပါ။ [RKNN components](https://github.com/airockchip/rknn-toolkit2/tree/v2.3.2)

Host Python 3.10 ကို venv သီးသန့်သုံးပါ—

```bash
python3 --version
python3 -m venv "$RK3588_SDK/venv-rknn"
"$RK3588_SDK/venv-rknn/bin/python" -m pip install --upgrade pip
mapfile -t RKNN_WHEELS < <(find "$RK3588_SDK/src/rknn-toolkit2/rknn-toolkit2/packages" \
  -type f -name 'rknn_toolkit2-2.3.2-cp310-cp310-*x86_64.whl')
if [ "${#RKNN_WHEELS[@]}" -eq 1 ]; then
    "$RK3588_SDK/venv-rknn/bin/python" -m pip install \
      -r "$RK3588_SDK/src/rknn-toolkit2/rknn-toolkit2/packages/x86_64/requirements_cp310-2.3.2.txt" \
      "${RKNN_WHEELS[0]}"
else
    echo "Expected one CPython 3.10 x86_64 wheel; inspect the pinned SDK packages." >&2
    exit 1
fi
"$RK3588_SDK/venv-rknn/bin/python" -m pip check
"$RK3588_SDK/venv-rknn/bin/python" -c 'from rknn.api import RKNN; print("RKNN host import OK")'
"$RK3588_SDK/venv-rknn/bin/python" -m pip freeze > "$RK3588_SDK/metadata/rknn-python.txt"
```

Wheel တစ်ခုမရခြင်း၊ Python version မကိုက်ခြင်း သို့မဟုတ် import error ဖြစ်လျှင် ဆက်မလုပ်ပါနှင့်။ Dependencies သည် venv ထဲတွင်သာရှိမည်။ System `sudo pip` မသုံးပါနှင့်။

ONNX model ရှိပြီးမှ pinned release ၏ examples/model-conversion instructions အတိုင်း conversion လုပ်ပါ။ **`target_platform='rk3588'`** သတ်မှတ်ရမည်။ Input names/shapes၊ RGB/BGR၊ normalization နှင့် quantization dataset သည် model-specific ဖြစ်၍ generic value မကူးပါနှင့်။ [RKNN Model Zoo v2.3.2](https://github.com/airockchip/rknn_model_zoo/tree/v2.3.2)

ရရှိသော `.rknn` ကို probe ဖြင့်စမ်းရန် **host terminal** မှ—

```bash
RKNN_MODEL="$RK3588_SDK/models/model.rknn"
test -s "$RKNN_MODEL"
scp "$RKNN_MODEL" \
  "$ROCK5B_TARGET:rk3588-sdk-tests/$DEPLOY_TAG/model.rknn"
ssh "$ROCK5B_TARGET" \
  "sudo install -m 0644 \"\$HOME/rk3588-sdk-tests/$DEPLOY_TAG/model.rknn\" \
  \"/opt/rockstar/rk3588-sdk-tests/$DEPLOY_TAG/model.rknn\" &&
  cd \"/opt/rockstar/rk3588-sdk-tests/$DEPLOY_TAG\" &&
  ./bin/rknn_probe model.rknn"
```

`model.rknn` သည် မိမိ conversion output အမည်ဖြင့်ပြောင်းရန်ဖြစ်သည်။ Success တွင် runtime/driver version နှင့် initialization PASS ကိုပြမည်။ **Actual inference နှင့် accuracy မစစ်ရသေးပါ။** ထိုအတွက် model ၏ preprocessing၊ `rknn_run` နှင့် output validation ပါသော demo/app ကို board ပေါ်တွင် ထပ်စမ်းရမည်။ QEMU က Rockchip NPU ကို မအတည်ပြုနိုင်ပါ။

## ၉။ RGA / MPP / GPU လိုလျှင်

ဤဖိုင်၏ runnable setup သည် **CPU + RKNN C/C++ SDK** အထိဖြစ်သည်။ အောက်ပါ libraries သည် သီးခြား optional components ဖြစ်ပြီး အလိုအလျောက် မပါဝင်ပါ။

| Feature | ထပ်လိုသော component | ကိုက်ညီရမည့်အချက် |
| --- | --- | --- |
| Hardware resize / color conversion | [airockchip/librga](https://github.com/airockchip/librga) ၏ Linux AArch64 headers + library | RGA kernel driver version နှင့် API support |
| Hardware video decode/encode | [rockchip-linux/mpp](https://github.com/rockchip-linux/mpp) ၏ MPP headers + library | Board codec driver၊ supported formats နှင့် device access |
| GPU / OpenCL / EGL | Board OS သုံးသော Mesa သို့မဟုတ် Mali userspace stack | Active GPU kernel driver နှင့် userspace ABI |

လိုအပ်သည့် component အတွက် release/commit ကိုအရင်ရွေးပြီး matching ARM64 headers ကို `prefix/include`၊ libraries ကို `prefix/lib` ထဲထည့်ကာ project တွင် link လုပ်ပါ။ Library dependencies အားလုံးကို စစ်ပြီး application `lib/` ထဲ package လုပ်နိုင်သည့် libraries များကိုသာ ထည့်ပါ။ GPU/Mali library ကို arbitrary version ဖြင့်ကူးတင်ခြင်း မလုပ်ပါနှင့်။

RGA library သည် RKNN library အစားမဟုတ်၊ MPP ရှိခြင်းသည် FFmpeg/OpenCV က hardware acceleration အလိုအလျောက်သုံးခြင်း မဟုတ်ပါ။ သက်ဆိုင်ရာ backend/API integration လိုသည်။ Vendor library distribution မလုပ်မီ သက်ဆိုင်ရာ license ကိုဖတ်ပါ။

## ၁၀။ ပြီးဆုံးစစ်ချက်နှင့် ပြဿနာဖြေရှင်းရန်

| စစ်ချက် | အဓိပ္ပာယ် |
| --- | --- |
| CPU sample board ပေါ် run အောင် | Cross-compiler၊ basic libc/libstdc++ compatibility အလုပ်လုပ်သည် |
| RKNN probe argument မပါဘဲ run အောင် | ARM64 runtime နှင့် dynamic dependencies load ရသည် |
| Model init/version query အောင် | ထို model/runtime/driver ပေါင်းစပ်မှုအတွက် initialization အောင်သည် |
| Real model inference + output validation အောင် | ထို model ၏ NPU execution နှင့် result ကို အတည်ပြုနိုင်သည် |

- `GLIBC_*` / `GLIBCXX_* not found` — binary/library symbol requirements နှင့် runtime baseline မကိုက်ပါ။ Board libc ကိုအစားထိုးမတင်ဘဲ compatible build/library baseline ကိုရွေးပါ။
- `librknnrt.so not found` — deployed `lib/`၊ SONAME နှင့် executable RUNPATH ကိုစစ်ပါ။
- `rknn_init failed` — model target/version၊ runtime/driver compatibility နှင့် device permissions ကိုစစ်ပါ။ Model conversion version နှင့် runtime ကို release တူထားပြီးစမ်းပါ။
- Device permission error — board ၏ device ownership/groups နှင့် image-specific udev rules ကိုစစ်ပါ။ `chmod 777` ဖြင့်ကျော်ခြင်း သို့မဟုတ် app တစ်ခုလုံးကို အမြဲ root ဖြင့် run ခိုင်းခြင်း မလုပ်ပါနှင့်။
- `file in wrong format` — amd64 သို့မဟုတ် Android library မှားယူထားခြင်းကိုစစ်ပါ။

Host toolchain version နှင့် deployment files ကိုမှတ်တမ်းတင်ပါ—

```bash
aarch64-linux-gnu-g++ -v 2> "$RK3588_SDK/metadata/compiler.txt"
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\n' \
  gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  'gcc-*-aarch64-linux-gnu' 'g++-*-aarch64-linux-gnu' '*arm64-cross' \
  binutils-aarch64-linux-gnu cmake ninja-build \
  > "$RK3588_SDK/metadata/host-packages.tsv"
```

ဤ SDK အတွက် board kernel/driver ပြောင်းခြင်း မပါဝင်ပါ။ Kernel module build လိုလာလျှင် exact board kernel source/config/build artifacts ဖြင့် သီးခြား environment တည်ဆောက်ရမည်။
