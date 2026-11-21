# $\color{#00c853}{\text{ROCK 5B / RK3588 — Smoke-test project build နှင့် deploy}}$

ဤလမ်းညွှန်သည် [07 SDK environment setup](07_create_RK3588_SDK_env_on_ubuntu2204.md) ပြီးစီးပြီးနောက် CPU-only C++ sample နှင့် optional RKNN runtime probe ကို build၊ package၊ board ပေါ်စမ်းသပ်ရန်ဖြစ်သည်။ Host Ubuntu 22.04 မှ ARM64 binary ထုတ်ပြီး target board ၏ app-specific directory ဖြစ်သော `/opt/rockstar/rk3588-sdk-tests/<DEPLOY_TAG>/` ထဲ deploy လုပ်မည်။ `/opt` ထဲရှိ အခြားအရာများကို မထိပါ။

## $\color{red}{\text{၁။ SDK environment ကို activate လုပ်ပါ}}$

Host ပေါ်ရှိ terminal အသစ်တွင် path/SSH target ကို မိမိစက်အတွက်ပြင်ပြီး SDK ကို activate လုပ်ပါ။

```bash
export RK3588_SDK="$HOME/Desktop/Git/Rockstar/01_Rock5B_Debian/RK3588_SDK_on_Ubuntu2204"
test -s "$RK3588_SDK/env.sh"
source "$RK3588_SDK/env.sh"
export ROCK5B_TARGET=mr_robot@192.168.1.15
```

`ROCK5B_TARGET` ကို board ၏ အမှန်တကယ် SSH username/IP ဖြင့်ပြောင်းပါ။ SSH အလုပ်မလုပ်ပါက build ပြီးသား binary ရှိသော်လည်း deploy မလုပ်နိုင်ပါ။ Board inventory ကို 07 လမ်းညွှန်၏ အဆင့် ၃ တွင် ရယူထားရမည်။

SDK directory ကို build configure လုပ်ပြီးနောက် rename/move လုပ်ထားပါက CMake cache ထဲတွင် ယခင် absolute path များ ကျန်နိုင်သည်။ အဲဒီအခါ stale build directory ကို ဆက်မသုံးဘဲ ဥပမာ `"$RK3588_SDK/build/cpu-renamed"` လို build directory အသစ်ဖြင့် CMake ကို ပြန် configure လုပ်ပါ။

## $\color{red}{\text{၂။ CPU-only sample နှင့် optional RKNN probe ဖန်တီးပါ}}$

```bash
mkdir -p "$RK3588_SDK/src/smoke"
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
    const int init_result = rknn_init(&ctx, argv[1], 0, 0, nullptr);
    if (init_result != RKNN_SUCC) {
        std::fprintf(stderr, "rknn_init failed: %d\n", init_result);
        return 1;
    }

    rknn_sdk_version versions{};
    const int query_result =
        rknn_query(ctx, RKNN_QUERY_SDK_VERSION, &versions, sizeof(versions));
    if (query_result == RKNN_SUCC) {
        std::printf("Runtime: %s\nDriver: %s\n",
                    versions.api_version, versions.drv_version);
        std::puts("PASS: model initialization and version query; inference not tested.");
    } else {
        std::fprintf(stderr, "rknn_query failed: %d\n", query_result);
    }

    const int cleanup_result = rknn_destroy(ctx);
    return query_result == RKNN_SUCC && cleanup_result == RKNN_SUCC ? 0 : 1;
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
```

## $\color{red}{\text{၃။ CPU-only target ကို build လုပ်ပြီးစစ်ပါ}}$

```bash
cmake -S "$RK3588_SDK/src/smoke" -B "$RK3588_SDK/build/cpu" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$RK3588_SDK/toolchains/rk3588.cmake" \
  -DCMAKE_BUILD_TYPE=Release -DWITH_RKNN=OFF
cmake --build "$RK3588_SDK/build/cpu" --parallel "$(nproc)"
cmake --install "$RK3588_SDK/build/cpu" --prefix "$RK3588_SDK/deploy/cpu"

file "$RK3588_SDK/deploy/cpu/bin/hello_rk3588"
aarch64-linux-gnu-readelf -h "$RK3588_SDK/deploy/cpu/bin/hello_rk3588" \
  | grep -E 'Class|Machine'
aarch64-linux-gnu-readelf -d "$RK3588_SDK/deploy/cpu/bin/hello_rk3588" \
  | grep -E 'NEEDED|RPATH|RUNPATH'
```

မျှော်မှန်းချက်မှာ AArch64 binary ဖြစ်ပြီး ARM64 target loader/runtime နှင့်ကိုက်ညီရမည်။ Host ပေါ်မှာ ARM64 binary ကို `ldd` ဖြင့်စစ်ခြင်း သို့မဟုတ် တိုက်ရိုက် run ခြင်း မလုပ်ပါနှင့်။

## $\color{red}{\text{၄။ Optional RKNN probe ကို build လုပ်ပါ}}$

NPU စမ်းသပ်မှသာ 07 လမ်းညွှန်၏ RKNN SDK အဆင့်ကို အရင်လုပ်ပါ။ `prefix/include/rknn_api.h` နှင့် `prefix/lib/librknnrt.so` မရှိပါက probe build မအောင်မြင်ပါ။

```bash
test -s "$RK3588_SDK/prefix/include/rknn_api.h"
test -s "$RK3588_SDK/prefix/lib/librknnrt.so"
cmake -S "$RK3588_SDK/src/smoke" -B "$RK3588_SDK/build/npu" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$RK3588_SDK/toolchains/rk3588.cmake" \
  -DCMAKE_BUILD_TYPE=Release -DWITH_RKNN=ON
cmake --build "$RK3588_SDK/build/npu" --parallel "$(nproc)"
cmake --install "$RK3588_SDK/build/npu" --prefix "$RK3588_SDK/deploy/npu"

file "$RK3588_SDK/deploy/npu/bin/"*
aarch64-linux-gnu-readelf -d "$RK3588_SDK/deploy/npu/bin/rknn_probe"
aarch64-linux-gnu-readelf --version-info "$RK3588_SDK/deploy/npu/bin/rknn_probe"
```

Expected: AArch64 binary, `librknnrt.so` dependency နှင့် `$ORIGIN/../lib` RUNPATH။ RKNN runtime ၏ SONAME က `librknnrt.so` အမည်နှင့်မတူပါက လိုအပ်သော SONAME symlink ကို deploy `lib/` ထဲပါ ထည့်ပါ။

## $\color{red}{\text{၅။ Board သို့ package ကူးပြီး /opt ထဲ deploy လုပ်ပါ}}$

CPU-only စမ်းရန် `DEPLOY_KIND=cpu` ထားပါ။ RKNN build/install အောင်မြင်မှသာ `DEPLOY_KIND=npu` ပြောင်းပါ။ Build output ကို board user home ရှိ staging directory သို့ SCP လုပ်ပြီး `/opt/rockstar/rk3588-sdk-tests/<DEPLOY_TAG>/` ထဲသီးသန့် extract လုပ်မည်။ Deploy path ရှိပြီးသားဖြစ်ပါက အသစ်သော tag သုံးပါ၊ အဟောင်းကို ထပ်မရေးပါနှင့်။

**Host terminal:**

```bash
DEPLOY_KIND=cpu
DEPLOY_TAG="rk3588-smoke-$(date +%Y%m%d-%H%M%S)"
DEPLOY_ARCHIVE="$RK3588_SDK/$DEPLOY_TAG.tar.gz"
test -d "$RK3588_SDK/deploy/$DEPLOY_KIND"
tar -czf "$DEPLOY_ARCHIVE" -C "$RK3588_SDK/deploy/$DEPLOY_KIND" .
(cd "$RK3588_SDK" && sha256sum "$DEPLOY_TAG.tar.gz" > "$DEPLOY_TAG.tar.gz.sha256")
ssh "$ROCK5B_TARGET" "mkdir -p \"\$HOME/rk3588-sdk-tests/$DEPLOY_TAG\"" &&
scp "$DEPLOY_ARCHIVE" "$DEPLOY_ARCHIVE.sha256" \
  "$ROCK5B_TARGET:rk3588-sdk-tests/$DEPLOY_TAG/" &&
printf 'DEPLOY_TAG=%s\n' "$DEPLOY_TAG"
```

SSH/SCP command တစ်ခုခု မအောင်မြင်လျှင် အဲဒီနေရာတွင်ရပ်ပါ။ Success ဖြစ်မှ board terminal ဖွင့်ပြီး host ကပြထားသော `DEPLOY_TAG` တန်ဖိုးကို အသုံးပြုပါ။

**Board terminal:**

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
sudo chown -R "$(id -u):$(id -g)" "$DEPLOY_DIR"
cd "$DEPLOY_DIR"
ldd ./bin/hello_rk3588
./bin/hello_rk3588
```

မျှော်မှန်းချက် `Hello ROCK 5B / RK3588`; `not found`, `GLIBC_*`, `GLIBCXX_*` error မရှိရပါ။ App ကို root ဖြင့် run မလုပ်ပါနှင့်။ `chown` သည် အသစ်ဖန်တီးထားသော ဤ deploy tag directory ကိုသာ သက်ရောက်သည်။

NPU package ဖြစ်ပါက ထပ်စစ်ပါ—

```bash
cd "$DEPLOY_DIR"
ldd ./bin/rknn_probe
ldd ./lib/librknnrt.so
./bin/rknn_probe
```

Argument မပါသော probe သည် runtime/dependency load ဖြစ်ခြင်းကိုသာ စစ်ပြီး NPU inference အလုပ်လုပ်ကြောင်း မအတည်ပြုပါ။

## $\color{red}{\text{၆။ Optional model-conversion နှင့် NPU initialization စမ်းသပ်မှု}}$

RKNN model convert လုပ်မည်ဆိုရင် 07 လမ်းညွှန်တွင်ပြင်ထားသော host venv (`$RK3588_SDK/venv-rknn`) ကိုသုံးပါ။ Model conversion သည် model-specific ဖြစ်သောကြောင့် input shape/name, channel order, normalization, quantization dataset ကို မိမိ model အလိုက် သတ်မှတ်ပါ။ Converter တွင် `target_platform='rk3588'` သတ်မှတ်ပါ။

Model file ကို host မှ board staging folder သို့ကူးပြီး app directory ထဲသို့ သီးခြား install လုပ်ပါ—

```bash
RKNN_MODEL="$RK3588_SDK/models/model.rknn"
test -s "$RKNN_MODEL"
scp "$RKNN_MODEL" \
  "$ROCK5B_TARGET:rk3588-sdk-tests/$DEPLOY_TAG/model.rknn"
ssh "$ROCK5B_TARGET" \
  "sudo install -m 0644 \"\$HOME/rk3588-sdk-tests/$DEPLOY_TAG/model.rknn\" \
  \"/opt/rockstar/rk3588-sdk-tests/$DEPLOY_TAG/model.rknn\""
```

Board ပေါ်တွင်—

```bash
cd "/opt/rockstar/rk3588-sdk-tests/$DEPLOY_TAG"
./bin/rknn_probe ./model.rknn
```

Model initialization/version query အောင်မြင်ခြင်းသည် inference/accuracy စမ်းသပ်ပြီးဖြစ်သည်ဟု မဆိုလိုပါ။ Actual inference နှင့် output validation အတွက် model preprocessing, `rknn_run` နှင့် result checking ကို app ထဲထည့်ပြီး board ပေါ်တွင် စမ်းရပါမည်။ Board ၏ NPU driver, device access နှင့် runtime version ကိုလည်း လိုက်ဖက်ကြောင်း အတည်ပြုပါ။

## $\color{red}{\text{၇။ Smoke test ပြဿနာဖြေရှင်းရန်}}$

- `GLIBC_*` / `GLIBCXX_* not found` — binary/library လိုအပ်သော symbol version နှင့် board OS runtime မကိုက်ပါ။ Board `glibc` ကို အစားထိုးမတင်ဘဲ compatible sysroot/toolchain ဖြင့် rebuild လုပ်ပါ။
- `librknnrt.so not found` — deploy `lib/`, SONAME, binary RUNPATH ကိုစစ်ပါ။
- `rknn_init failed` — model target/version, runtime/driver compatibility နှင့် NPU device permission ကိုစစ်ပါ။
- Device permission error — board device ownership/groups နှင့် image-specific rules ကိုစစ်ပါ။ `chmod 777` မသုံးပါနှင့်၊ app ကို root ဖြင့် အမြဲ run မလုပ်ပါနှင့်။
- `file in wrong format` — amd64 သို့မဟုတ် Android library ကိုမှားယူထားခြင်းရှိမရှိစစ်ပါ။
- `ssh` connection closed — build failure နှင့်မတူပါ။ Board IP/network/SSH service ကိုစစ်ပြီး connection အောင်မြင်ပြီးမှ SCP/deploy ကိုပြန်လုပ်ပါ။

SDK setup လမ်းညွှန်တွင် board kernel/driver ပြောင်းလဲမှု မပါဝင်ပါ။ Hardware driver သို့မဟုတ် firmware မရှိလျှင် smoke project ကို package လုပ်ခြင်းတစ်ခုတည်းဖြင့် ဖြေရှင်း၍မရပါ။

References:
- `./01_Rock5B_Debian/README/08_build_smoke_test_project.md`
- `./01_Rock5B_Debian/README/00_HOW_TO_BUILD_LINUX_SDK.md`
- `./md_lists.md`
