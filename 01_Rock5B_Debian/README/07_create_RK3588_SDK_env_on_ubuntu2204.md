# RK3588 ARM64 cross-compilation environment တည်ဆောက်ခြင်း

ဤလမ်းညွှန်နှင့် script သည် Linux amd64/x86_64 host ပေါ်တွင် ARM64/Linux GNU cross-compilation အတွက် အခြေခံ workspace နှင့် CMake toolchain ဖန်တီးသည်။ Ubuntu 22.04 ကို အဓိကအသုံးပြုထားသော်လည်း host ပေါ်တွင် cross compiler/tooling ကို ကိုယ်တိုင်ပြင်ဆင်ထားလျှင် အခြား Linux amd64 host မှလည်း အသုံးပြုနိုင်သည်။

**ဤအဆင့်သည် target sysroot မတည်ဆောက်ပါ။** Host cross compiler ၏ built-in headers/libraries ကိုအသုံးပြုပြီး target board ၏ OS/runtime versions ကို metadata အဖြစ်သာ မှတ်တမ်းတင်သည်။ RKNN, libdatachannel, RGA, MPP သို့မဟုတ် အခြား third-party library များကို ဒီအဆင့်တွင် download/build/install မလုပ်ပါ။ Smoke-test project ကို သီးခြား [08_build_smoke_test_project.md](08_build_smoke_test_project.md) တွင်လုပ်ပါ။

## ၁။ Host ပေါ်တွင်လိုအပ်သော tools

Script သည် host package များကို install/update မလုပ်ပါ။ အောက်ပါ command များကို host ပေါ်တွင် ကြိုတင်ရရှိနိုင်အောင် ပြင်ဆင်ပါ—

- Bash၊ GNU core utilities
- AArch64 GNU cross compiler: `aarch64-linux-gnu-gcc`, `aarch64-linux-gnu-g++`
- Cross binutils: `aarch64-linux-gnu-ar`, `ranlib`, `strip`, `readelf`
- CMake၊ Ninja၊ `pkg-config`

Compiler သည် `-dumpmachine` ဖြင့် `aarch64` target ကိုပြရမည်။ Script က Linux `x86_64` host နှင့် compiler target ကိုစစ်သည်။ လိုအပ်သော tool မရှိပါက host OS ၏ package manager မှ ကိုယ်တိုင် install လုပ်ပြီးမှ script ကို ထပ် run ပါ။ `C_COMPILER`, `CXX_COMPILER` နှင့် binutils environment variables များဖြင့် command အမည်/path ကို ပြောင်းနိုင်သည်။

## ၂။ Target board မှာ စစ်ဆေးရမည့်အချက်များ

Script သည် board သို့ SSH မချိတ်ပါ။ Board ၏ local terminal မှ အောက်ပါ read-only command များကို run ပြီး output ကိုမှတ်ထားပါ။ Script က ဒီ command များကို စတင်ချိန်မှာလည်း ပြပေးမည်။

```bash
printf "architecture: "; dpkg --print-architecture
cat /etc/os-release
printf "kernel: "; uname -r
getconf GNU_LIBC_VERSION
tr '\0' '\n' < /proc/device-tree/compatible
dpkg-query -W -f='${binary:Package}\t${Version}\t${Architecture}\n' \
  libc6:arm64 libstdc++6:arm64 libgcc-s1:arm64 2>/dev/null || true
```

Script က board/model, compatible value, architecture, OS/codename, kernel, glibc, libstdc++ runtime တို့ကို တစ်ခုချင်း မေးပါမည်။ မသိသောတန်ဖိုးကို `unknown` ဟုထည့်နိုင်သည်။ Target architecture သည် `arm64` သို့မဟုတ် `aarch64` ဖြစ်ရမည်။ ဤတန်ဖိုးများသည် user ထည့်ပေးသော baseline metadata သာဖြစ်ပြီး SDK ကို target နှင့် အပြည့်အဝကိုက်ညီကြောင်း အာမမခံပါ။

## ၃။ Script ကို run လုပ်ပြီး SDK directory ရွေးပါ

Repository ထဲက script ကို absolute path ဖြင့် run နိုင်သည်။ သို့မဟုတ် `.sh` ဖိုင်တစ်ခုတည်းကို အခြား Linux amd64 host သို့ကူးပြီး run နိုင်သည်။ `common.sh` သို့မဟုတ် repository ရှိ အခြားဖိုင်များအပေါ် မှီခိုမှုမရှိပါ။

```bash
bash /path/to/05_create_RK3588_SDK_env_without_sysroot.sh
```

Script သည် board ပေါ် run ရမည့် command များကိုပြပြီး အချက်အလက်တစ်ခုချင်းတောင်းပါမည်။ SDK ထားမည့် **absolute path** ကိုလည်းရွေးနိုင်သည်။ Default သည် `$HOME/RK3588_SDK_on_Ubuntu2204` ဖြစ်သည်။ ဖန်တီးမည့် folder ရှိပြီးသားဆို မည်သည့်ဖိုင်ကိုမျှ ထပ်မရေးဘဲ path အသစ်ရွေးခိုင်းပါမည်။ နောက်ဆုံးမှာ config အကျဉ်းချုပ်ပြပြီး `yes` ဖြင့် အတည်ပြုမှ workspace ဖန်တီးမည်။

`--help` သည် script options/environment variables များကိုပြသည်။ Automation အတွက် `--non-interactive` နှင့် လိုအပ်သည့် environment variables အားလုံးသုံးနိုင်သည်။ ဥပမာ—

```bash
SDK_ROOT="$HOME/RK3588_SDK_on_Ubuntu2204" \
TARGET_BOARD="Radxa ROCK 5B" \
TARGET_COMPATIBLE="rockchip,rk3588" \
TARGET_ARCH="aarch64" \
TARGET_OS="Armbian 26.8.3 / Ubuntu" \
TARGET_CODENAME="resolute" \
TARGET_KERNEL="6.1.115-vendor-rk35xx" \
TARGET_GLIBC="2.43" \
TARGET_LIBSTDCXX="16-20260322-1ubuntu1" \
CONFIRM_CREATE=yes \
bash /path/to/05_create_RK3588_SDK_env_without_sysroot.sh --non-interactive
```

Target တန်ဖိုးများကို မိမိ board မှရသော output အတိုင်းထည့်ပါ။ `C_COMPILER`, `CXX_COMPILER`, `AR`, `RANLIB`, `STRIP`, `READELF`, `PKG_CONFIG`, `CMAKE`, `NINJA` ကိုလိုအပ်ပါက environment variables အဖြစ်ပေးနိုင်သည်။

## ၄။ ဖန်တီးမည့် workspace နှင့် activate လုပ်ခြင်း

Script амжилттай дууссаны дараа сонгосон SDK path дотор:

| Path | Зориулалт |
|---|---|
| `env.sh` | SDK shell environment ကို activate လုပ်ရန် |
| `bin/rk3588-pkg-config` | Workspace prefix ၏ `.pc` metadata အတွက် wrapper |
| `toolchains/rk3588.cmake` | ARM64 Linux CMake cross-toolchain |
| `src/`, `build/` | Project source နှင့် build output အတွက် directory များ |
| `prefix/include`, `prefix/lib` | နောက်ပိုင်း သီးခြားစီစဉ်မည့် target dependency prefix |
| `metadata/host.txt` | Host နှင့် compiler အချက်အလက်များ |
| `metadata/target.txt` | User ထည့်သွင်းထားသော target အချက်အလက်များ |
| `metadata/target-baseline.md` | Target အချက်အလက်များ၏ ဖတ်ရလွယ်သော summary |

Terminal အသစ်တွင် activation လုပ်ပါ—

```bash
source "/ရွေးထားသော/SDK/path/env.sh"
```

## ၅။ နယ်ပယ်နှင့် နောက်တစ်ဆင့်

`metadata/target-baseline.md` ထဲက board information ကို စစ်ပြီး compiler/header/runtime version များနှင့် target compatibility ကို ထပ်မံအတည်ပြုပါ။ No-sysroot နည်းတွင် target `glibc`/`libstdc++` ကိုယူသုံးခြင်းမဟုတ်သဖြင့် host မှ build အောင်မြင်တာတစ်ခုတည်းဖြင့် board ပေါ်အလုပ်လုပ်မည်ဟု မသတ်မှတ်ပါနှင့်။

RKNN, libdatachannel ကဲ့သို့ third-party dependency integration ကို နောက်အဆင့်တွင် library တစ်ခုချင်းစီ၏ version၊ ARM64 build နှင့် runtime/deployment လိုအပ်ချက်အလိုက် ဆုံးဖြတ်ပါမည်။ လက်ရှိ 07 script က အဲဒီ library များကို download/install မလုပ်သလို SDK folder ထဲလည်း မထည့်ပါ။ အခြေခံ toolchain ကို smoke test လုပ်ရန် [08_build_smoke_test_project.md](08_build_smoke_test_project.md) ကိုသုံးပါ။
