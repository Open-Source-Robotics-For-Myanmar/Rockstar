# $\color{#00c853}{\text{RK3588 ARM64 cross-compilation environment တည်ဆောက်ခြင်း}}$

ဤလမ်းညွှန်နှင့် script သည် Linux amd64/x86_64 host ပေါ်တွင် ARM64/Linux GNU cross-compilation အတွက် အခြေခံ workspace နှင့် CMake toolchain ဖန်တီးသည်။ Ubuntu 22.04 ကို အဓိကအသုံးပြုထားသော်လည်း host ပေါ်တွင် cross compiler/tooling ကို ကိုယ်တိုင်ပြင်ဆင်ထားလျှင် အခြား Linux amd64 host မှလည်း အသုံးပြုနိုင်သည်။

**ဤအဆင့်သည် target sysroot မတည်ဆောက်ပါ။** Host cross compiler ၏ built-in headers/libraries ကိုအသုံးပြုပြီး target board ၏ OS/runtime versions ကို metadata အဖြစ်သာ မှတ်တမ်းတင်သည်။ RKNN, libdatachannel, RGA, MPP သို့မဟုတ် အခြား third-party library များကို ဒီအဆင့်တွင် download/build/install မလုပ်ပါ။ Smoke-test project ကို သီးခြား [08_build_smoke_test_project.md](08_build_smoke_test_project.md) တွင်လုပ်ပါ။

## $\color{red}{\text{၁။ Host ပေါ်တွင်လိုအပ်သော tools}}$

Script သည် host package များကို install/update မလုပ်ပါ။ အောက်ပါ command များကို host ပေါ်တွင် ကြိုတင်ရရှိနိုင်အောင် ပြင်ဆင်ပါ—

- Bash၊ GNU core utilities
- AArch64 GNU cross compiler: `aarch64-linux-gnu-gcc`, `aarch64-linux-gnu-g++`
- Cross binutils: `aarch64-linux-gnu-ar`, `ranlib`, `strip`, `readelf`
- CMake 3.15+ (`list(PREPEND ...)` သုံးထားလို့)၊ Ninja၊ `pkg-config`

Compiler သည် `-dumpmachine` ဖြင့် `aarch64` target ကိုပြရမည်။ Script က Linux `x86_64` host နှင့် compiler target ကိုစစ်သည်။ လိုအပ်သော tool မရှိပါက host OS ၏ package manager မှ ကိုယ်တိုင် install လုပ်ပြီးမှ script ကို ထပ် run ပါ။ `C_COMPILER`, `CXX_COMPILER` နှင့် binutils environment variables များဖြင့် command အမည်/path ကို ပြောင်းနိုင်သည်။

## $\color{red}{\text{၂။ Target board မှာ စစ်ဆေးရမည့်အချက်များ}}$

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

### $\color{cyan}{\text{၂.၁ မေးထားသော input တစ်ခုချင်းစီ — စစ်နည်း၊ ထည့်နည်း၊ လိုအပ်ရခြင်း}}$

Script က အခုဆိုရင် prompt တစ်ခုချင်းစီမှာပါ ဒီအချက်အလက်တွေ ပြပါတယ် (`--help` မှာလည်း အပြည့်ရှိပါတယ်)။ **ပထမ ၈ ခုက target board ပေါ်က ရယူရတာဖြစ်ပြီး host ပေါ်မှာ run တဲ့ command မဟုတ်ပါဘူး။** တန်ဖိုးကိုပဲ ထည့်ပါ၊ label သို့ command တစ်ခုလုံး မထည့်ပါနှင့်။

Terminal မှာ အရောင်တွေ ပါတယ် — အစိမ်း = board/host command၊ အဝါ = ထည့်ရမယ့်တန်ဖိုး၊ အပြာ = လိုအပ်ရခြင်း၊ အနီ = error။ အရောင်က TTY မှာပဲ ပေါ်ပါတယ်။ မလိုချင်ရင် `NO_COLOR=1` သို့ `TERM=dumb` သတ်မှတ်ပါ။ Log ထဲမှာ အရောင်ပါစေချင်ရင် `FORCE_COLOR=1` သုံးနိုင်ပါတယ်။ ANSI code တွေက generated file တွေထဲ မရောက်ပါဘူး။

| Prompt (env var) | Board ပေါ်မှာ စစ်နည်း | ထည့်ပုံ / ဥပမာ | ဘာလို့ လိုသလဲ |
|---|---|---|---|
| Target board/model (`TARGET_BOARD`) | `tr -d '\0' < /proc/device-tree/model; echo`<br>`grep -E '^(BOARD_NAME\|BOARD)=' /etc/armbian-release` | `Radxa ROCK 5B`, `Orange Pi 5 Plus` (စာကြောင်းတစ်ကြောင်းတည်း) | SDK metadata ထဲမှာ ဘယ် hardware အတွက် ပြင်ဆင်ထားတယ်ဆိုတာ မှတ်ဖို့သာ။ Compiler flag ကို မထိပါ။ |
| Device-tree compatible (`TARGET_COMPATIBLE`) | `tr '\0' '\n' < /proc/device-tree/compatible \| grep -m1 rk3588` | **`rockchip,rk3588`** လို `rk3588` ပါတဲ့ တစ်ကြောင်းတည်း။ `grep -m1` က တန်ဖိုးတစ်ခုပဲ ထုတ်ပေးတယ် — နှစ်ခုဆက်ကူးမိရင် `radxa,rock-5brockchip,rk3588` လို ဖြစ်သွားတတ်တယ်။ | မှားတဲ့ SoC (RK3566/RK3399) ကို ဒီ RK3588 SDK နဲ့ မတွဲမိအောင် စစ်ဆေးချက်။ Board variant ကိုလည်း မှတ်တယ်။ |
| Target architecture (`TARGET_ARCH`) | `dpkg --print-architecture` → `arm64`<br>`uname -m` → `aarch64` | `arm64` သို့ `aarch64` (နှစ်ခုလုံးကို `aarch64` ပြောင်းသည်) | Target က 64-bit ARM မှန်ကြောင်း အတည်ပြုချက်။ CMake toolchain ကတော့ `aarch64` ကိုပဲ သုံးသည်။ |
| Target OS name (`TARGET_OS`) | `. /etc/os-release; printf '%s\n' "$PRETTY_NAME"` | `Debian GNU/Linux 12 (bookworm)`, `Armbian 26.8.3 / Ubuntu` | Target userspace ကို မှတ်ထားပြီး နောက်ပိုင်း host cross toolchain နဲ့ နှိုင်းယှဉ်နိုင်ရန်။ |
| Target OS codename (`TARGET_CODENAME`) | `. /etc/os-release; printf '%s\n' "$VERSION_CODENAME"` | `bookworm`, `jammy`, `noble`; မရှိရင် `unknown` | userspace release ကို တိတိကျကျ သတ်မှတ်ပေးတယ် (package ရွေးရလွယ်တယ်)။ |
| Target kernel release (`TARGET_KERNEL`) | `uname -r` (`uname -v` မဟုတ် — နောက်က build timestamp ဖြစ်နေတယ်) | `6.1.115-vendor-rk35xx` | Kernel UAPI နဲ့ ကိုက်ညီမှု မှတ်ချက် (V4L2, DRM, RGA/MPP ioctl)။ ဒီ SDK က kernel header မထည့်ပါ။ |
| Target GNU libc (`TARGET_GLIBC`) | `getconf GNU_LIBC_VERSION \| awk '{print $2}'` → `2.43`<br>`ldd --version \| head -n1` က banner တစ်ခုလုံး ပြတယ် — နံပါတ်ပဲ ထည့်ပါ | `2.36` (သို့ `glibc 2.36`) | **အဓိက ABI စစ်ချက်**။ ဒီ host ရဲ့ cross glibc က 2.35 ဖြစ်တော့ board က 2.35 ထက် နည်းရင် host မှာ build ထားတဲ့ binary မအောင်မြင်နိုင်ပါ — အသက်ငယ်တဲ့ toolchain သို့ sysroot လိုတယ်။ |
| Target libstdc++ (`TARGET_LIBSTDCXX`) | `dpkg-query -W -f='${Version}\n' libstdc++6:arm64`<br>`strings /usr/lib/aarch64-linux-gnu/libstdc++.so.6 \| grep -m1 GLIBCXX_` | `12.3.0-1ubuntu1~22.04.3` သို့ `GLIBCXX_3.4.30`; မရှိရင် `unknown` | C++ ABI စစ်ချက်။ ဒီ host cross g++ က GCC 11 / libstdc++ 12.3.0 ဖြစ်တယ်။ Board မှာ လိုအပ်တဲ့ `GLIBCXX_` symbol မရှိရင် C++ binary load မဖြစ်ပါ။ |
| SDK workspace path (`SDK_ROOT`) | **Host ပေါ်ကတာ။ Board နဲ့ မဆိုင်ပါ။** | `$HOME/RK3588_SDK_on_Ubuntu2204` (default) သို့ အသစ်တစ်ခု — **absolute ဖြစ်ပြီး မရှိသေးရမယ်** | ဖန်တီးမယ့်ဖိုင်အားလုံး ဒီထဲရောက်တယ်။ ရှိပြီးသား directory ကို ဘယ်တော့မှ မပြင်ဘူး။ |

နောက်ဆုံးမှာ config အကျဉ်းပြပြီး `yes` ရိုက်မှ ဖန်တီးပါတယ်။ Board/model, compatible, architecture ကသာ တင်းကြပ်စစ်ဆေးပြီး ကျန်တာတွေ မသိရင် `unknown` ထည့်လို့ရပါတယ်။ `--non-interactive` မှာတော့ အပေါ်က `TARGET_*` အားလုံး + `SDK_ROOT` + `CONFIRM_CREATE=yes` ကို env var အဖြစ် ပေးရပါမယ် — script က ဘာကိုမှ ခန့်မှန်းမှာ မဟုတ်ပါဘူး။

## $\color{red}{\text{၃။ Script ကို run လုပ်ပြီး SDK directory ရွေးပါ}}$

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

## $\color{red}{\text{၄။ ဖန်တီးမည့် workspace နှင့် activate လုပ်ခြင်း}}$

Script အောင်မြင်ပြီးနောက် ရွေးထားသော SDK path ထဲမှာ—

| Path | ရည်ရွယ်ချက် |
|---|---|
| `env.sh` | SDK shell environment ကို activate လုပ်ရန် |
| `bin/rk3588-pkg-config` | Workspace prefix ၏ `.pc` metadata အတွက် wrapper |
| `toolchains/rk3588.cmake` | ARM64 Linux CMake cross-toolchain |
| `src/`, `build/` | Project source နှင့် build output အတွက် directory များ |
| `prefix/include`, `prefix/lib` | နောက်ပိုင်း သီးခြားစီစဉ်မည့် target dependency prefix |
| `metadata/host.txt` | Host နှင့် compiler အချက်အလက်များ |
| `metadata/target.txt` | User ထည့်သွင်းထားသော target အချက်အလက်များ |
| `metadata/target-baseline.md` | Target အချက်အလက်များ၏ ဖတ်ရလွယ်သော summary |
| `models/` | နောက်ပိုင်း RKNN model တွေ ထားဖို့ လွယ်ကူစေမယ့် ဗလာ directory |

Terminal အသစ်တွင် activation လုပ်ပါ—

```bash
source "/ရွေးထားသော/SDK/path/env.sh"
```

## $\color{red}{\text{၅။ နယ်ပယ်နှင့် နောက်တစ်ဆင့်}}$

`metadata/target-baseline.md` ထဲက board information ကို စစ်ပြီး compiler/header/runtime version များနှင့် target compatibility ကို ထပ်မံအတည်ပြုပါ။ No-sysroot နည်းတွင် target `glibc`/`libstdc++` ကိုယူသုံးခြင်းမဟုတ်သဖြင့် host မှ build အောင်မြင်တာတစ်ခုတည်းဖြင့် board ပေါ်အလုပ်လုပ်မည်ဟု မသတ်မှတ်ပါနှင့်။

RKNN, libdatachannel ကဲ့သို့ third-party dependency integration ကို နောက်အဆင့်တွင် library တစ်ခုချင်းစီ၏ version၊ ARM64 build နှင့် runtime/deployment လိုအပ်ချက်အလိုက် ဆုံးဖြတ်ပါမည်။ လက်ရှိ 07 script က အဲဒီ library များကို download/install မလုပ်သလို SDK folder ထဲလည်း မထည့်ပါ။ အခြေခံ toolchain ကို smoke test လုပ်ရန် [08_build_smoke_test_project.md](08_build_smoke_test_project.md) ကိုသုံးပါ။

### $\color{cyan}{\text{၅.၁ ဒီမေးခွန်းတွေက standard SDK အတွက် လုံလောက်ရဲ့လား?}}$

**မလုံလောက်ပါဘူး — ဒါက "cross-compile workspace" တစ်ခုသာဖြစ်ပြီး target နဲ့ ကိုက်ညီတဲ့ "standard SDK (complete SDK)" မဟုတ်ပါ။** မေးထားတဲ့ ၈ ခုလုံး metadata အဖြစ်သာ သိမ်းတယ်။ Compile မှာ အမှန်တကယ် သုံးတာက host cross toolchain (Ubuntu 22.04: GCC 11 / glibc 2.35 / libstdc++ 12.3.0) ရဲ့ built-in header/library တွေဖြစ်တယ်။

| အရာ | ဒီ script မှာ ရှိ/မရှိ | ဘာဖြစ်တယ် |
|---|---|---|
| Cross compiler + CMake/Ninja toolchain | ရှိ | သန့်ရှင်းတဲ့ C/C++ project ကို ARM64 binary ထုတ်နိုင်တယ် |
| board/OS/kernel/glibc/libstdc++ metadata | ရှိ | နှိုင်းယှဉ်စစ်ဆေးဖို့ မှတ်တမ်းသာ |
| Target sysroot (`/usr/include`, `/lib`, `/usr/lib`, `ld-linux-aarch64.so.1`) | **မရှိ** | Host 22.04 header တွေနဲ့ compile ဖြစ်နေတယ်။ Board glibc က host ထက် နည်းရင် binary အလုပ်မလုပ်နိုင်ဘူး |
| Kernel UAPI headers (target kernel နဲ့ ကိုက်တဲ့) | **မရှိ** | V4L2/DRM/RGA/MPP စတဲ့ driver API သုံးရင် header မကိုက်နိုင်ဘူး |
| RKNN / RGA / MPP / libdatachannel / EGL-Vulkan BSP library | **မရှိ** | Script က တိတိကျကျ ဖယ်ထားတာ။ နောက်အဆင့်အလိုက် ထည့်ရမယ် |
| Debug symbols + `gdb-multiarch` sysroot | **မရှိ** | Board ပေါ်မှာ debug လုပ်ဖို့ ထပ်စစ်ရမယ် |
| Bootloader / kernel image / rootfs / device tree build | **မရှိ** | Firmware အပြည့်တည်ဆောက်ချင်ရင် Rockchip BSP သို့ Buildroot/Yocto လိုတယ် |
| ABI ကိုယ်တိုင် စစ်ဆေးခြင်း | **မရှိ** | `-dumpmachine` ပဲစစ်တယ်။ glibc/libstdc++ version ကို ကုဒ်ထဲ မသုံးဘူး |

**ဘယ်အခြေအနေမှာ လုံလောက်သလဲ** — external dependency မသုံးတဲ့ ရိုးရိုး C/C++ CLI/daemon တွေ၊ board glibc ≥ 2.35 နဲ့ libstdc++ ≥ 12.3.0 (သို့ လိုအပ်တဲ့ `GLIBCXX_` symbol ပါရှိ) ဖြစ်ရင် ဒီ workspace နဲ့ စတင်လို့ရပါတယ်။ ဒီထက်ပိုတာလိုရင် sysroot တစ်ခု (သို့ toolchain ကို target image နဲ့ တူအောင် ပြန်ဆောက်တာ) ထပ်လိုအပ်ပါတယ်။

စစ်ဆေးရန် လက်တွေ့နည်းလမ်း—
- Board ပေါ်က တန်ဖိုးကို မှတ်ပြီး `metadata/target-baseline.md` နဲ့ ယှဉ်ပါ။
- Host cross glibc ကို `dpkg-query -W -f='${Version}\n' libc6-arm64-cross` (ဒီစက်မှာ `2.35-...`), libstdc++ ကို `dpkg-query -W -f='${Version}\n' libstdc++6-arm64-cross` (ဒီစက်မှာ `12.3.0-...`) နဲ့ စစ်ပါ။
- [08_build_smoke_test_project.md](08_build_smoke_test_project.md) အတိုင်း build ပြီး ထွက်လာတဲ့ binary ကို board ပေါ်ကို copy ပြီး တကယ် run ကြည့်ပါ။ ဒါက တစ်ခုတည်းသော အတည်ပြုချက်။

References:
- `./01_Rock5B_Debian/README/00_HOW_TO_BUILD_LINUX_SDK.md`
- `./01_Rock5B_Debian/README/07_create_RK3588_SDK_env_on_ubuntu2204.md`
- `./01_Rock5B_Debian/README/08_build_smoke_test_project.md`
- `./01_Rock5B_Debian/scripts/05_create_RK3588_SDK_env_without_sysroot.sh`

