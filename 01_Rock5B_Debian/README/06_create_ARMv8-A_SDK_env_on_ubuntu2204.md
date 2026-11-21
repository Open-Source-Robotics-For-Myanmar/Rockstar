# Ubuntu 22.04 host ပေါ်တွင် generic Linux ARM64 SDK တည်ဆောက်ခြင်း

ဤလမ်းညွှန်ကို **Ubuntu 22.04 amd64/x86_64 host** ပေါ်တွင် အစဉ်လိုက်လုပ်နိုင်သည်။ Physical board၊ SSH၊ board sysroot archive၊ vendor SDK မလိုပါ။ Ubuntu မှပေးထားသော cross-toolchain packages ကိုသုံးပြီး C/C++ program တည်ဆောက်မည်။ Compiler ကို source မှ bootstrap လုပ်သည့်နည်း မဟုတ်ပါ။

| အပိုင်း | ရွေးထားသော baseline |
| --- | --- |
| Host | Ubuntu 22.04 / amd64 |
| Target CPU | Generic ARMv8-A, AArch64, little-endian, LP64 |
| Target environment | Linux userspace + GNU libc (glibc) |
| Compiler triple | `aarch64-linux-gnu` |
| C/C++ toolchain | Ubuntu Jammy cross GCC/G++ packages |
| Board မရှိဘဲစမ်းရန် | QEMU user-mode |

**Board-independent ဖြစ်သော်လည်း OS/ABI-independent မဟုတ်ပါ။** Android/Bionic၊ Alpine/musl၊ bare-metal firmware၊ kernel modules အတွက် ဤ SDK မဟုတ်ပါ။ Deployment လုပ်ချိန် target တွင် compatible loader၊ glibc၊ libstdc++ နှင့် application dependencies လိုသည်။ ARM64 CPU တူရုံဖြင့် မလုံလောက်ပါ။

## ၁။ Host စစ်ပြီး packages တင်ပါ

အောက်ပါ commands များကို Bash terminal တစ်ခုတည်းတွင် အစဉ်လိုက်လုပ်ပါ။ Error တက်လျှင် နောက်အဆင့်မဆက်ဘဲ အရင်ဖြေရှင်းပါ။ Build ကို normal user ဖြင့်လုပ်ပြီး `sudo` ကို package installation မှာပဲ သုံးပါ။

```bash
uname -m
dpkg --print-architecture
cat /etc/os-release
```

Expected: `x86_64`, `amd64`, `VERSION_ID="22.04"` ဖြစ်ရမည်။

```bash
sudo apt update
sudo apt install -y \
  build-essential cmake ninja-build pkg-config file \
  gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  binutils-aarch64-linux-gnu libc6-dev-arm64-cross \
  qemu-user
```

ဤနည်းတွင် host APT repositories မှ cross packages ကို တင်သည်။ `dpkg --add-architecture arm64` လုပ်ရန်၊ `ports.ubuntu.com` ထပ်ထည့်ရန် သို့မဟုတ် host release ပြောင်းရန် မလိုပါ။ Jammy `g++-aarch64-linux-gnu` သည် GCC 11 series ကို dependency အဖြစ်ယူသည်။ Exact patch version သည် update အပေါ်မူတည်နိုင်သည်။ [Ubuntu package](https://packages.ubuntu.com/jammy/g++-aarch64-linux-gnu)

```bash
aarch64-linux-gnu-gcc --version
aarch64-linux-gnu-g++ --version
aarch64-linux-gnu-g++ -dumpmachine
aarch64-linux-gnu-g++ -print-sysroot
aarch64-linux-gnu-g++ -print-file-name=crt1.o
aarch64-linux-gnu-g++ -print-file-name=libstdc++.so
cmake --version
qemu-aarch64 --version
```

`-dumpmachine` က `aarch64-linux-gnu` ဖြစ်ရမည်။ `crt1.o` နှင့် `libstdc++.so` သည် အမှန်တကယ်ရှိသော path ပြရမည်၊ filename သာပြလျှင် package မစုံသေးပါ။

**`-print-sysroot` က `/` ပြခြင်းသည် Ubuntu packaged cross-compiler အတွက် error ဟု မဆိုလိုပါ။** Compiler တွင် target-specific search paths ပါပြီး `/usr/aarch64-linux-gnu` နှင့် GCC cross directories မှ headers/libraries ကိုရှာသည်။ `/usr/aarch64-linux-gnu` သည် ပြည့်စုံသော OS rootfs မဟုတ်ပါ။ ဒီ setup မှာ `--sysroot=/usr/aarch64-linux-gnu` သို့မဟုတ် `CMAKE_SYSROOT` ကို အတင်းမထည့်ပါနှင့်။ Actual paths ကို အောက်ပါအတိုင်း စစ်နိုင်သည်။

```bash
printf '' | aarch64-linux-gnu-g++ -E -x c++ -v - >/dev/null
aarch64-linux-gnu-g++ -print-search-dirs
```

## ၂။ SDK workspace နှင့် activation file ဖန်တီးပါ

အောက်ပါဖိုင်များကို `$HOME/arm64-sdk-jammy` အောက်တွင် ဖန်တီးမည်။ ရှိပြီးသား workspace ထဲက အမည်တူ configuration/sample files များကို ထပ်ရေးမည်ဖြစ်၍ ကိုယ်ပိုင်ဖိုင်ရှိလျှင် path အသစ်ရွေးပါ။ Path တွင် space မပါသောနေရာကိုသုံးပါ။

```bash
export ARM64_SDK="$HOME/arm64-sdk-jammy"
mkdir -p "$ARM64_SDK"/{bin,toolchains,src/hello,build,metadata}

cat > "$ARM64_SDK/env.sh" <<'ENV'
# Source this file in a dedicated SDK shell.
export ARM64_SDK="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export CC=/usr/bin/aarch64-linux-gnu-gcc
export CXX=/usr/bin/aarch64-linux-gnu-g++
export AR=/usr/bin/aarch64-linux-gnu-ar
export RANLIB=/usr/bin/aarch64-linux-gnu-ranlib
export STRIP=/usr/bin/aarch64-linux-gnu-strip
export PKG_CONFIG="$ARM64_SDK/bin/arm64-pkg-config"
# Discard inherited native/other-SDK search paths and flags in this shell.
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH LD_LIBRARY_PATH
unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS CMAKE_PREFIX_PATH
unset PKG_CONFIG_PATH PKG_CONFIG_LIBDIR PKG_CONFIG_SYSROOT_DIR
ENV

cat > "$ARM64_SDK/bin/arm64-pkg-config" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
# Do not let native amd64 .pc files satisfy target dependencies.
export PKG_CONFIG_PATH=
export PKG_CONFIG_LIBDIR=/usr/aarch64-linux-gnu/lib/pkgconfig:/usr/aarch64-linux-gnu/share/pkgconfig
unset PKG_CONFIG_SYSROOT_DIR
exec /usr/bin/pkg-config "$@"
SH
chmod +x "$ARM64_SDK/bin/arm64-pkg-config"
```

Wrapper က host `.pc` files မယူစေရန် `PKG_CONFIG_LIBDIR` ကိုကန့်သတ်ထားသည်။ [pkg-config environment](https://manpages.ubuntu.com/manpages/jammy/man1/pkg-config.1.html)

SDK work အတွက် သီးသန့် shell ဖွင့်ပြီး activate လုပ်ပါ။ အောက်က build အဆင့်များကို ထို shell ထဲတွင် ဆက်လုပ်ပါ။ `exit` လုပ်လျှင် parent shell settings ပြန်ရသည်။ `.bashrc` ထဲမထည့်ထားပါ။

```bash
bash --noprofile --norc
source "$ARM64_SDK/env.sh"
```

Terminal အသစ်မှပြန်ဝင်သည့်အခါ `bash --noprofile --norc` လုပ်ပြီး `source "$HOME/arm64-sdk-jammy/env.sh"` ကိုသုံးပါ။ Workspace path ပြောင်းထားလျှင် အဲဒီ path ကိုသုံးပါ။

## ၃။ CMake toolchain ဖန်တီးပါ

```bash
cat > "$ARM64_SDK/toolchains/aarch64-linux-gnu.cmake" <<'CMAKE'
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER /usr/bin/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/aarch64-linux-gnu-g++)
set(CMAKE_AR /usr/bin/aarch64-linux-gnu-ar)
set(CMAKE_RANLIB /usr/bin/aarch64-linux-gnu-ranlib)
set(CMAKE_STRIP /usr/bin/aarch64-linux-gnu-strip)

# Generic baseline; no board-specific CPU tuning or -march=native.
set(CMAKE_C_FLAGS_INIT "-march=armv8-a -mtune=generic")
set(CMAKE_CXX_FLAGS_INIT "-march=armv8-a -mtune=generic")

# Keep packaged GCC's default sysroot and built-in search paths.
set(CMAKE_FIND_ROOT_PATH /usr/aarch64-linux-gnu)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_FIND_USE_PACKAGE_REGISTRY FALSE)
set(CMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY FALSE)
set(PKG_CONFIG_EXECUTABLE
    "${CMAKE_CURRENT_LIST_DIR}/../bin/arm64-pkg-config"
    CACHE FILEPATH "ARM64 pkg-config wrapper" FORCE)
CMAKE
```

Build tools ကို host မှယူပြီး dependency ရှာရာတွင် target directories ကိုသာ အသုံးပြုစေသည်။ Project က hard-coded `/usr/include` / amd64 library path ထည့်ထားလျှင်တော့ ဤ rules ဖြင့် အလိုအလျောက်ပြင်မရပါ။ [CMake 3.22 toolchains](https://cmake.org/cmake/help/v3.22/manual/cmake-toolchains.7.html)

`-march=armv8-a` သည် application code ၏ CPU instruction baseline ဖြစ်သည်။ `-march=native`၊ `-mcpu=cortex-a76` စသည့် host/board-specific tuning မလိုပါ။ [GCC AArch64 options](https://gcc.gnu.org/onlinedocs/gcc/AArch64-Options.html)

## ၄။ C နှင့် C++ sample ကို cross-build လုပ်ပါ

```bash
cat > "$ARM64_SDK/src/hello/hello.c" <<'C'
#include <stdio.h>
int main(void) {
    puts("Hello ARM64 C");
    return 0;
}
C

cat > "$ARM64_SDK/src/hello/hello.cpp" <<'CPP'
#include <iostream>
int main() {
    std::cout << "Hello ARM64 C++\n";
    return 0;
}
CPP

cat > "$ARM64_SDK/src/hello/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.22)
project(hello_arm64 LANGUAGES C CXX)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_executable(hello_c hello.c)
add_executable(hello_cpp hello.cpp)
CMAKE

cmake -S "$ARM64_SDK/src/hello" -B "$ARM64_SDK/build/hello" \
  -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$ARM64_SDK/toolchains/aarch64-linux-gnu.cmake" \
  -DCMAKE_BUILD_TYPE=Release
cmake --build "$ARM64_SDK/build/hello" --parallel "$(nproc)" --verbose
```

Compiler/toolchain ပြောင်းလျှင် build directory အသစ်ကိုသုံးပါ။ Native build cache နှင့် cross-build cache ကို မရောပါနှင့်။

## ၅။ Binary architecture စစ်ပြီး board မပါဘဲ run ပါ

```bash
file "$ARM64_SDK/build/hello/hello_c" "$ARM64_SDK/build/hello/hello_cpp"
aarch64-linux-gnu-readelf -h "$ARM64_SDK/build/hello/hello_cpp"
aarch64-linux-gnu-readelf -l "$ARM64_SDK/build/hello/hello_cpp"
aarch64-linux-gnu-readelf -d "$ARM64_SDK/build/hello/hello_cpp"
aarch64-linux-gnu-readelf --version-info "$ARM64_SDK/build/hello/hello_cpp"
```

Expected: ELF64၊ little-endian၊ `Machine: AArch64` နှင့် interpreter `/lib/ld-linux-aarch64.so.1` ဖြစ်ရမည်။ `NEEDED` entries တွင် libc/libstdc++ စသည့် runtime dependencies ကိုမြင်ရမည်။ `--version-info` ကလိုအပ်သော `GLIBC_*` / `GLIBCXX_*` symbol versions ကိုပြသည်။

```bash
test -e /usr/aarch64-linux-gnu/lib/ld-linux-aarch64.so.1
test -e /usr/aarch64-linux-gnu/lib/libstdc++.so.6
qemu-aarch64 -L /usr/aarch64-linux-gnu "$ARM64_SDK/build/hello/hello_c"
qemu-aarch64 -L /usr/aarch64-linux-gnu "$ARM64_SDK/build/hello/hello_cpp"
```

Expected output:

```text
Hello ARM64 C
Hello ARM64 C++
```

`-L` သည် target loader/runtime prefix ကိုပေးသည်။ QEMU user-mode က ARM64 userspace instructions နှင့် syscalls ကို host ပေါ်တွင် emulation လုပ်ပေးသည်။ Board drivers၊ target kernel၊ hardware timing သို့မဟုတ် performance ကို အတည်ပြုသောစမ်းသပ်မှု မဟုတ်ပါ။ [QEMU user-mode](https://www.qemu.org/docs/master/user/main.html)

ARM64 binary ကို x86_64 host ပေါ် တိုက်ရိုက် `./hello_cpp` သို့မဟုတ် host `ldd` ဖြင့်မစမ်းဘဲ အထက်ပါ QEMU/readelf ကိုသုံးပါ။

## ၆။ Environment မှတ်တမ်းသိမ်းပြီး နောက် project တွင်ပြန်သုံးပါ

```bash
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\n' \
  gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  'gcc-*-aarch64-linux-gnu' 'g++-*-aarch64-linux-gnu' \
  binutils-aarch64-linux-gnu '*arm64-cross' \
  cmake ninja-build pkg-config qemu-user \
  > "$ARM64_SDK/metadata/packages.tsv"
aarch64-linux-gnu-g++ -v 2> "$ARM64_SDK/metadata/compiler.txt"
sha256sum "$ARM64_SDK/env.sh" "$ARM64_SDK/bin/arm64-pkg-config" \
  "$ARM64_SDK/toolchains/aarch64-linux-gnu.cmake" \
  > "$ARM64_SDK/metadata/config.sha256"
```

Metadata သည် version မှတ်တမ်းသာဖြစ်ပြီး package archive မဟုတ်ပါ။ ဤ SDK workspace သည် `/usr/bin` နှင့် `/usr/aarch64-linux-gnu` ရှိ installed packages ကို မှီခိုသဖြင့် folder တစ်ခုကူးရုံဖြင့် portable SDK မဖြစ်ပါ။

မိမိ CMake project တွင် source/build paths ကိုပြောင်းပြီး အဆင့် ၄ ရှိ toolchain option ကိုသုံးပါ။ SDK shell ထဲက `CC`/`CXX` သည် cross compilers ဖြစ်သော်လည်း CMake မှာ cross-compilation mode သတ်မှတ်ရန် toolchain file ကိုပါ ပေးရသည်။

OpenSSL၊ OpenCV စသည့် third-party libraries ထပ်လိုလျှင် **ARM64 build + development headers** လိုသည်။ Host ၏ `libssl-dev` / `libopencv-dev` ကို install လုပ်ရုံနှင့် target dependency မဖြစ်ပါ။ အခြေခံ SDK ပြီးမှ target-compatible libraries ကို သီးသန့် prefix/sysroot ထဲတည်ဆောက်ပြီး CMake နှင့် pkg-config target paths ကို တွဲညှိရမည်။ ဤလမ်းညွှန်သည် standard C/C++ runtime အထိသာ ပြင်ဆင်ပေးသည်။

## အမှားတွေ့လျှင်

| Error | စစ်ဆေးရန် |
| --- | --- |
| `command not found` | အဆင့် ၁ package install အောင်/မအောင်နှင့် `/usr/bin` PATH ကိုစစ်ပါ |
| `Exec format error` | ARM64 output ကို host ပေါ်တိုက်ရိုက် run နေခြင်းလား စစ်ပြီး QEMU သုံးပါ |
| `Could not open /lib/ld-linux-aarch64.so.1` | QEMU `-L` prefix နှင့် cross libc loader ကိုစစ်ပါ |
| `file in wrong format` / `skipping incompatible` | amd64 library ဝင်နေခြင်း၊ native build cache ရောနေခြင်းကိုစစ်ပါ |
| pkg-config package မတွေ့ | Target library မထည့်ရသေးခြင်းဖြစ်နိုင်သည်။ Host `.pc` path ကိုထည့်ပြီး မကျော်ပါနှင့် |
| `GLIBC_*` / `GLIBCXX_* not found` | Target runtime က binary လိုအပ်ချက်မပြည့်ပါ။ သက်ဆိုင်ရာ target baseline အတွက် ပြန် build လုပ်ရန် သို့မဟုတ် compatible runtime လိုသည် |

အဆင့် ၅ တွင် C နှင့် C++ output နှစ်ခုလုံး QEMU ပေါ်မှန်ကန်စွာထွက်လျှင် basic cross-compile/link/emulation environment အဆင်သင့်ဖြစ်သည်။ Physical ARM64 Linux စက်ပေါ် deployment compatibility ကိုတော့ နောက်တစ်ဆင့်အဖြစ် ထပ်စစ်ရမည်။
