# $\color{#00c853}{\text{Linux SDK တည်ဆောက်ရန် လိုအပ်ချက်များနှင့် Target OS မှ အတိအကျ သိရမည့် အချက်အလက်များ}}$

ဤစာတမ်းက ROCK 5B / RK3588 အတွက် **host ပေါ်တွင် cross-compilation SDK** တည်ဆောက်ရန် လိုအပ်တာတွေနဲ့၊ တည်ဆောက်မီ **target board ရဲ့ Operating System ထဲက ဘာတွေကို အတိအကျ သိထားရမလဲ** ဆိုတာကို စနစ်တကျ ဖော်ပြပါတယ်။

## $\color{red}{\text{၀။ "SDK" ဆိုတာ ဘာကို ဆိုလိုသလဲ — အတိအကျ သတ်မှတ်ချက်}}$

| အဓိပ္ပာယ် | ပါဝင်သည် | ဒီ project မှာ |
|---|---|---|
| **Host-side cross-compilation SDK** | cross compiler, binutils, sysroot (သို့ built-in target headers), CMake toolchain, pkg-config wrapper, dependency prefix, metadata, smoke test | ✅ ဒီစာတမ်းနဲ့ `05`–`08` လမ်းညွှန်တွေက ဒါကို ဆောက်တာ |
| **Full board SDK / BSP / firmware SDK** | bootloader, kernel image, device tree, rootfs, vendor driver/firmware, flashing tools, OTA | ❌ ဒီအဆင့်မှာ မပါဘူး — သီးခြား BSP အဆင့်ဖြစ်တယ် |

**အရေးကြီးသော နားလည်ချက်:** `metadata/target.txt` ထဲက board/OS/kernel/glibc/libstdc++ တန်ဖိုးတွေဟာ **traceability record (မှတ်တမ်း)** သာဖြစ်ပြီး compatibility အာမခံချက် မဟုတ်ပါဘူး။ တကယ့် ABI ကို ဆုံးဖြတ်တာက **host cross toolchain + သုံးထားတဲ့ sysroot** ဖြစ်တယ်။ တစ်ခုတည်းသော အတည်ပြုချက်က **build ထားတဲ့ binary ကို board ပေါ်မှာ တကယ် run ကြည့်တာ** ဖြစ်ပါတယ်။

---

## $\color{red}{\text{၁။ SDK တစ်ခု တည်ဆောက်ဖို့ လိုအပ်တာတွေ}}$

### $\color{cyan}{\text{၁.၁ Host ပေါ်က လိုအပ်ချက်များ}}$

| အရာ | ဘာအတွက် လိုသလဲ | စစ်နည်း / မှတ်ချက် |
|---|---|---|
| Linux **x86_64 / amd64** host | Cross compiler run ဖို့ | `uname -m` → `x86_64`; `dpkg --print-architecture` → `amd64` |
| Bash 4+ | Prompt, `${var,,}`, `printf %q`, heredoc | `bash --version` |
| GNU coreutils, `sed`, `file` | `mktemp`, `mv -Tn`, metadata ရေးခြင်း, ELF စစ်ခြင်း | `mktemp --version`, `file --version` |
| AArch64 GNU cross compiler | ARM64 binary ထုတ်ဖို့ | `aarch64-linux-gnu-gcc -dumpmachine` → `aarch64-linux-gnu` |
| Cross binutils | `ar`, `ranlib`, `strip`, `readelf` | `aarch64-linux-gnu-{ar,ranlib,strip,readelf} --version` |
| `libc6-dev-arm64-cross` | Host built-in target headers/libs (no-sysroot mode) | `dpkg-query -W libc6-dev-arm64-cross` |
| CMake **≥ 3.15** | `list(PREPEND ...)` သုံးထားလို့ | `cmake --version` |
| Ninja, pkg-config | Build နဲ့ `.pc` dependency resolution | `ninja --version`, `pkg-config --version` |
| `apt download` / `dpkg-deb` (ချင်ရင်) | Package-based sysroot ဆောက်ဖို့ | board ကို မပြောင်းဘဲ host မှာ unpack လုပ်လို့ရ |
| `qemu-user` (ချင်ရင်) | Board မပါဘဲ ARM64 binary smoke test | `qemu-aarch64 --version` |

> ဒီ project ရဲ့ လက်ရှိ host တန်ဖိုးများ (စက်ပေါ်မှာ ပြန်စစ်ပါ): GCC `11.4.0`, `libc6-arm64-cross` `2.35`, `libstdc++6-arm64-cross` `12.3.0`။

### $\color{cyan}{\text{၁.၂ Target ABI ရင်းမြစ် — sysroot ဘယ်ကရမလဲ}}$

SDK တစ်ခုက **target ရဲ့ headers + libraries** မပါရင် compile လုပ်လို့ရပေမယ့် board ပေါ်မှာ run မဖြစ်နိုင်ပါဘူး။ ရွေးစရာနည်းလမ်းများ—

| နည်း | ရင်းမြစ် | အားသာချက် | ကန့်သတ်ချက် |
|---|---|---|---|
| Board filesystem archive | `03` လမ်းညွှန်အတိုင်း `/lib`, `/usr/lib`, `/usr/include` ကို tar ဆွဲ | Board မှာ ရှိတဲ့ ABI အတိုင်း အတိအကျ | Board မှာ `-dev` package မတပ်ထားရင် headers မပါဘူး |
| Package-based sysroot | Target release နဲ့ ကိုက်တဲ့ ARM64 `.deb` တွေကို host မှာ download + unpack | Board ကို မပြောင်းဘဲ version ထိန်းနိုင် | Post-install script မ run တာ၊ symlink/linker script ပြန်စစ်ရတာ၊ version တိတိကျကျ ရွေးရတာ ခက်တယ် |
| Yocto `populate_sdk` | Image နဲ့ တွဲထုတ်ထားတဲ့ SDK | Image–SDK version ကိုက်ညီမှု အကောင်းဆုံး | Target OS ကို Yocto နဲ့ ပြန်ဆောက်ရမယ် |
| Buildroot output toolchain | Image build ရဲ့ `output/host` | အပေါ်အတိုင်း | အပေါ်အတိုင်း |
| **No-sysroot (ဒီ project ရဲ့ `07`)** | Host cross toolchain ရဲ့ built-in headers/libs | Board မလိုဘဲ အမြန်စတင်နိုင် | Board glibc ≥ host glibc (2.35) ဖြစ်ရမယ်၊ kernel header/vendor lib မပါဘူး |

### $\color{cyan}{\text{၁.၃ Target မှ ရယူရမယ့် အချက်အလက်}}$

အသေးစိတ်ကို **အပိုင်း ၂** မှာ ဖော်ပြထားပါတယ်။ အကျဉ်းချုပ်—

- OS identity, architecture, libc implementation နဲ့ version
- C/C++ runtime နဲ့ development package version များ
- Kernel release, kernel UAPI headers, module headers, device tree
- App သုံးမယ့် vendor library/runtime/driver version များ
- Board ပေါ်က development tool ရှိ/မရှိနဲ့ deployment constraints

### $\color{cyan}{\text{၁.၄ Vendor / hardware runtime များ}}$

App က NPU, camera, codec, GPU သုံးမယ်ဆိုရင် ဒီအရာတွေကို သီးခြား ထည့်ရပါမယ် —

- `librknnrt.so` / RKNN Lite wheel — model kit version နဲ့ ကိုက်ညီရမယ်
- RKNPU kernel driver version, `/sys/kernel/debug/rknpu/version`, device node နဲ့ permission
- RGA, MPP, EGL/GLES/Vulkan, OpenSSL, zlib စတဲ့ library တွေရဲ့ **headers + `.so` + version**
- Firmware file တွေ၊ `/lib/firmware` ထဲက လိုအပ်တာ
- Kernel module လိုရင် တိတိကျကျ ကိုက်တဲ့ kernel source/build headers

> ဒီအရာတွေကို `07` script က မထည့်ပါဘူး — script ကိုယ်တိုင်က "RKNN, libdatachannel မပါဘူး" လို့ ပြောထားတာနဲ့ ကိုက်ညီပါတယ်။

### $\color{cyan}{\text{၁.၅ Workspace ဖွဲ့စည်းပုံ}}$

`05`/`07` script က ဖန်တီးပေးတဲ့ layout —

| Path | ရည်ရွယ်ချက် |
|---|---|
| `env.sh` | `source` လုပ်ပြီး SDK shell ဖွင့်ဖို့ (`CC`, `CXX`, `AR`, `RANLIB`, `STRIP`, `PKG_CONFIG`) |
| `bin/rk3588-pkg-config` | Host `.pc` မတောက်စေဖို့ wrapper |
| `toolchains/rk3588.cmake` | CMake cross-toolchain |
| `src/`, `build/` | Project source / build output |
| `prefix/include`, `prefix/lib` | နောက်ထပ်ထည့်မယ့် target dependency prefix |
| `metadata/host.txt`, `target.txt`, `target-baseline.md` | Host နဲ့ user-ပေးထားတဲ့ target မှတ်တမ်း |
| `models/` | RKNN model ထားရန် |

### $\color{cyan}{\text{၁.၆ အတည်ပြုခြင်း (verification)}}$

1. `bash -n <script>` — syntax
2. `--help` နဲ့ prompt တစ်ခုချင်းစီမှာ ညွှန်းချက်ပါအောင် စစ်ပါ
3. Non-interactive run ကို **မရှိသေးတဲ့** path အသစ်နဲ့ လုပ်ပါ
4. `source env.sh` ပြီး `cmake -DCMAKE_TOOLCHAIN_FILE=... -G Ninja` နဲ့ smoke build
5. `file <binary>` → `ELF ... ARM aarch64` ဖြစ်ရမယ်
6. `aarch64-linux-gnu-readelf -d <binary>` နဲ့ `NEEDED`/`RUNPATH` စစ်ပါ
7. `08_build_smoke_test_project.md` အတိုင်း board ပေါ်ကို copy ပြီး **တကယ် run** လုပ်ပါ

---

## $\color{red}{\text{၂။ Target Operating System ထဲက အတိအကျ သိရမယ့်အရာများ}}$

ဒီအပိုင်းက မေးခွန်းရဲ့ အဓိက အဖြေပါ။ **အုပ်စု (၁)–(၃) က SDK တည်ဆောက်ဖို့ မဖြစ်မနေ လိုအပ်တယ်။ (၄)–(၆) က app/hardware အပေါ်မူတည်ပြီး လိုအပ်တယ်။**

### $\color{cyan}{\text{၂.၁ OS identity နဲ့ architecture — မဖြစ်မနေ}}$

| သိရမယ့်အရာ | Board ပေါ်က command | ဥပမာ / မှတ်ရန် |
|---|---|---|
| Distribution ID | `. /etc/os-release; printf '%s\n' "$ID"` | `debian`, `ubuntu`, `armbian` |
| Version ID | `printf '%s\n' "$VERSION_ID"` | `26.04`, `22.04` — package ရွေးဖို့ အသုံးအကြီးဆုံး |
| Codename | `printf '%s\n' "$VERSION_CODENAME"` | `resolute`, `jammy`, `bookworm` |
| Pretty name | `printf '%s\n' "$PRETTY_NAME"` | `Armbian 26.8.3 resolute` |
| Board name | `tr -d '\0' < /proc/device-tree/model; echo` | `Radxa ROCK 5B` |
| Device-tree compatible | `tr '\0' '\n' < /proc/device-tree/compatible \| grep -m1 rk3588` | `rockchip,rk3588` — **`rk3588` ပါတဲ့ တစ်ကြောင်းတည်း** ထည့်ပါ |
| Debian package arch | `dpkg --print-architecture` | `arm64` |
| Kernel arch | `uname -m` | `aarch64` |
| Host arch alias | `dpkg-architecture -qDEB_HOST_ARCH` | `arm64` (မရှိရင် မပါဝင်နိုင်) |
| Word size / endian | `getconf LONG_BIT`; `lscpu \| grep -E 'Byte Order\|Architecture'` | `64`, `Little Endian`, `aarch64` → LP64 little-endian |

**ဘာလို့လိုသလဲ:** package repository ရွေးချယ်ခြင်း၊ sysroot ထဲထည့်မယ့် `.deb` တွေရဲ့ architecture သတ်မှတ်ခြင်းနဲ့ `CMAKE_SYSTEM_PROCESSOR` ကိုကြောင်း ဆုံးဖြတ်ဖို့။ `/etc/os-release` မရှိရင် `/etc/debian_version`, `/etc/armbian-release` ကို ကြည့်ပါ။

### $\color{cyan}{\text{၂.၂ C/C++ ABI နဲ့ runtime — မဖြစ်မနေ (အရေးအကြီးဆုံး)}}$

| သိရမယ့်အရာ | Board ပေါ်က command | ဘာလို့လိုသလဲ |
|---|---|---|
| libc implementation | `ldd --version \| head -n1`; `ls /lib/ld-linux-aarch64.so.1 /lib/ld-musl-aarch64.so.1 2>/dev/null` | glibc လား musl လား ဆုံးဖြတ်ရန် — နှစ်ခု ရောလို့ မရပါ |
| glibc version | `getconf GNU_LIBC_VERSION \| awk '{print $2}'` | Host cross glibc (2.35) ထက် နည်းရင် binary အလုပ်မလုပ်နိုင်ပါ |
| `libc6` package version | `dpkg-query -W -f='${Version}\n' libc6:arm64` | Sysroot ထဲထည့်မယ့် `libc6-dev` နဲ့ တိတိကျကျ တူရမယ် |
| `libc6-dev` ရှိ/မရှိ | `dpkg-query -W -f='${Version}\n' libc6-dev:arm64` | မရှိရင် board archive ထဲမှာ C headers မပါဘူး |
| `libstdc++6` version | `dpkg-query -W -f='${Version}\n' libstdc++6:arm64` | C++ runtime ကိုက်ညီမှု စစ်ဖို့ |
| `libgcc-s1` version | `dpkg-query -W -f='${Version}\n' libgcc-s1:arm64` | C++ exception/unwind runtime |
| Max `GLIBCXX_` symbol | `strings /usr/lib/aarch64-linux-gnu/libstdc++.so.6 \| grep -o 'GLIBCXX_[0-9.]*' \| sort -V \| tail -n1` | Host က ထုတ်တဲ့ `GLIBCXX_*` လိုအပ်ချက်ကို board က ပြည့်မီရမယ် |
| Dynamic loader | `ls -l /lib/ld-linux-aarch64.so.1` | Linker/interpreter path မှန်ကြောင်း |
| Compiler used for target libs | `strings libstdc++.so.6 \| grep -m1 'GCC:'` (ရှိရင်) | GCC version ကွဲရင် libstdc++ ရောသုံးရန် မသင့်ဘူး |

> **ABIs ကို မရောပါနှင့်:** glibc ↔ musl ရောလို့ မရပါ။ Board က musl ဖြစ်နေရင် `aarch64-linux-musl-*` toolchain နဲ့ musl sysroot လိုပါတယ် — `aarch64-linux-gnu-*` နဲ့ မရပါဘူး။

### $\color{cyan}{\text{၂.၃ Kernel, UAPI နဲ့ hardware interface — driver သုံးရင် လိုအပ်}}$

| သိရမယ့်အရာ | Board ပေါ်က command | ဘာလို့လိုသလဲ |
|---|---|---|
| Kernel release | `uname -r` | UAPI header / module header ရွေးဖို့ (`-vendor-rk35xx` ဆိုတာ vendor kernel) |
| Kernel build info | `uname -v`; `cat /proc/version` | Image က ဘယ် source က ဆိုတာ ခြေရာခံဖို့ |
| Kernel config | `zcat /proc/config.gz 2>/dev/null \| head` (ရှိရင်) | လိုအပ်တဲ့ driver/config ဖွင့်ထားလား စစ်ဖို့ |
| UAPI headers package | `dpkg-query -W -f='${Version}\n' linux-libc-dev:arm64` | Userspace kernel header (V4L2/DRM/etc.) version |
| Module build headers | `ls -ld /lib/modules/$(uname -r)/build 2>/dev/null` | **Kernel module တည်ဆောက်မှသာ** လိုအပ် — userspace app အတွက် မလိုပါ |
| Device node များ | `ls -l /dev/dri /dev/video* /dev/media* /dev/rknpu* 2>/dev/null` | NPU/camera/render feature ရနိုင်လား |
| Driver version | `cat /sys/kernel/debug/rknpu/version 2>/dev/null` (root လိုနိုင်) | RKNN runtime နဲ့ driver version တူရမယ် |
| Firmware | `ls -l /lib/firmware 2>/dev/null \| head` | Hardware feature အတွက် firmware လိုနိုင် |

### $\color{cyan}{\text{၂.၄ Board ပေါ်က development tool အခြေအနေ}}$

| စစ်ရမယ့်အရာ | Command | မှတ်ချက် |
|---|---|---|
| Cross/build tool ရှိ/မရှိ | `for c in gcc g++ make cmake ninja pkg-config; do command -v "$c" \|\| true; done` | မရှိရင် host မှာပဲ တည်ဆောက်ရမယ် — board ပေါ်မှာ မတင်ပါနှင့် |
| `-dev` package စာရင်း | `dpkg-query -W -f='${binary:Package}\n' '*-dev' 2>/dev/null \| head -50` | ဘာ header ပါပြီး ဘာမပါလဲ သိဖို့ |
| pkg-config metadata | `ls /usr/lib/aarch64-linux-gnu/pkgconfig /usr/share/pkgconfig 2>/dev/null` | `.pc` ဖိုင်တွေက sysroot ထဲလည်း လိုအပ် |
| Installed vendor libs | `ldconfig -p \| grep -Ei 'rknn\|rga\|mpp\|EGL\|GLES\|vulkan\|ssl\|z\.so'` | App လိုအပ်တဲ့ `.so` တွေ ရှိ/မရှိ |

### $\color{cyan}{\text{၂.၅ App သုံးမယ့် library / runtime version များ}}$

Library တစ်ခုချင်းစီအတွက် အနည်းဆုံး ဒီ ၄ ခု မှတ်ပါ —

1. **Package/runtime version** — `dpkg-query -W -f='${Version}\n' <package>:arm64`
2. **SONAME / `.so` filename** — `ls -l /usr/lib/aarch64-linux-gnu/lib<name>.so*`
3. **Header ရှိ/မရှိ** — `/usr/include/<name>.h` သို့ `/usr/local/include`
4. **Version compatibility** — RKNN ဆိုရင် model toolkit version ↔ `librknnrt.so` ↔ RKNPU driver version သုံးခုလုံး တူရမယ်

> `dlopen()` နဲ့ နောက်မှဖွင့်တဲ့ plugin တွေကို `ldd` က မမြင်ပါဘူး။ Feature တစ်ခုချင်းစီကို board ပေါ်မှာ run စမ်းပါ။

### $\color{cyan}{\text{၂.၆ Deployment / OS constraints}}$

| သိရမယ့်အရာ | ဘာလို့လိုသလဲ |
|---|---|
| Root filesystem က read-only လား | App ကို ဘယ်နေရာ install လုပ်မလဲ ဆုံးဖြတ်ဖို့ (`/opt/rockstar/<app>`) |
| Network / apt ရနိုင်လား | Offline ဆိုရင် runtime dependency အားလုံးကို package ထဲ ထည့်ပို့ရမယ် |
| Run မယ့် user နဲ့ permissions | Device node ဖတ်ခွင့်ရဖို့; root နဲ့ မ run ပါနှင့် |
| systemd service / startup | Daemon ဆိုရင် service unit လိုနိုင် |
| Storage နေရာချင်း | Model ကြီးရင် `/opt` မှာ နေရာလုံလောက်ရမယ် |
| Timezone / locale / cert | App က အချိန်၊ SSL certificate သုံးရင် လိုအပ် |

### $\color{cyan}{\text{၂.၇ 05 script က တောင်းတာ vs SDK အတွက် ထပ်လိုအပ်တာ}}$

| `05` script က တောင်းတဲ့ value | ဘာအတွက် သုံးသလဲ |
|---|---|
| `TARGET_BOARD` | metadata မှတ်ချက် |
| `TARGET_COMPATIBLE` | `rk3588` ပါလား စစ်ချက် |
| `TARGET_ARCH` | `arm64`/`aarch64` → `aarch64` |
| `TARGET_OS`, `TARGET_CODENAME`, `TARGET_KERNEL`, `TARGET_GLIBC`, `TARGET_LIBSTDCXX` | metadata မှတ်ချက် — compile မှာ မသုံးဘူး |

**ဒီ ၈ ခုတည်းက sysroot အစား မဝင်ပါဘူး။** Complete SDK အတွက် အပေါ်က အပိုင်း ၂.၂–၂.၅ က တန်ဖိုးတွေ (အထူးသဖြင့် `libc6`/`libc6-dev` တိတိကျကျ version, `GLIBCXX_` အမြင့်ဆုံး symbol, sysroot ရင်းမြစ်, kernel headers, vendor runtime versions) ထပ်လိုအပ်ပါတယ်။

---

## $\color{red}{\text{၃။ Board ပေါ်မှာ တစ်ခါတည်း run လို့ရတဲ့ data-collection command}}$

အောက်ကာကို target board ရဲ့ terminal မှာ run ပြီး output ကို `metadata/target-raw.txt` ထဲ သိမ်းပါ။ အားလုံး read-only ဖြစ်ပါတယ် (debugfs ဖတ်တာက root လိုနိုင်)။

```bash
{
  echo '===== OS IDENTITY ====='
  . /etc/os-release
  printf 'ID=%s\nVERSION_ID=%s\nVERSION_CODENAME=%s\nPRETTY_NAME=%s\n' \
    "$ID" "$VERSION_ID" "$VERSION_CODENAME" "$PRETTY_NAME"
  cat /etc/debian_version 2>/dev/null || true
  grep -E '^(BOARD_NAME|BOARD|VERSION)=' /etc/armbian-release 2>/dev/null || true

  echo '===== BOARD / ARCH ====='
  printf 'model: '; tr -d '\0' < /proc/device-tree/model; echo
  printf 'compatible: '; tr '\0' '\n' < /proc/device-tree/compatible
  printf 'dpkg_arch: '; dpkg --print-architecture
  printf 'uname_m: '; uname -m
  printf 'long_bit: '; getconf LONG_BIT
  lscpu | grep -E 'Architecture|Byte Order|CPU op-mode' || true

  echo '===== ABI / RUNTIME ====='
  printf 'libc: '; getconf GNU_LIBC_VERSION
  ldd --version | head -n1
  dpkg-query -W -f='${binary:Package}\t${Version}\t${Architecture}\n' \
    libc6:arm64 libc6-dev:arm64 libstdc++6:arm64 libgcc-s1:arm64 2>/dev/null || true
  ls -l /lib/ld-linux-aarch64.so.1 /lib/ld-musl-aarch64.so.1 2>/dev/null || true
  strings /usr/lib/aarch64-linux-gnu/libstdc++.so.6 2>/dev/null \
    | grep -o 'GLIBCXX_[0-9.]*' | sort -V | tail -n1

  echo '===== KERNEL ====='
  printf 'release: '; uname -r
  printf 'build: '; uname -v
  cat /proc/version
  zcat /proc/config.gz 2>/dev/null | head -n 5 || true
  dpkg-query -W -f='${Version}\n' linux-libc-dev:arm64 2>/dev/null || true
  ls -ld "/lib/modules/$(uname -r)/build" 2>/dev/null || true

  echo '===== DEV TOOLS / PACKAGES ====='
  for c in gcc g++ make cmake ninja pkg-config python3; do
    command -v "$c" || printf '%s: MISSING\n' "$c"
  done
  dpkg-query -W -f='${binary:Package}\n' '*-dev' 2>/dev/null | head -50 || true

  echo '===== VENDOR / DEVICE ====='
  ldconfig -p 2>/dev/null | grep -Ei 'rknn|rga|mpp|EGL|GLES|vulkan|ssl|z\.so' || true
  ls -l /dev/dri /dev/video* /dev/media* /dev/rknpu* 2>/dev/null || true
  cat /sys/kernel/debug/rknpu/version 2>/dev/null || true
} | tee target-raw.txt
```

---

## $\color{red}{\text{၄။ မှတ်တမ်းတင်ပြီး နှိုင်းယှဉ်ပုံ}}$

1. Board output ကို SDK ထဲ `metadata/target-raw.txt` အဖြစ် သိမ်းပါ (တန်ဖိုးတွေကို ကိုယ်တိုင် မပြောင်းပါနှင့်)။
2. `05` script ကို run တဲ့အခါ အပေါ်က တန်ဖိုးတွေကနေ `TARGET_*` ဖြည့်ပါ — **တန်ဖိုးတစ်ခုတည်းပဲ** ထည့်ပါ (compatible အတွက် `rockchip,rk3588`, glibc အတွက် `2.43`)။
3. Host နဲ့ နှိုင်းယှဉ်ပါ —

```bash
dpkg-query -W -f='${Package} ${Version}\n' libc6-arm64-cross libstdc++6-arm64-cross gcc-aarch64-linux-gnu
aarch64-linux-gnu-gcc --version | head -n1
```

4. **Red flag တွေ** —

- Board glibc < host cross glibc (2.35) → toolchain အသစ်/အဟောင်း ပြောင်းဖို့ သို့ match sysroot လိုတယ်
- Board က musl ဖြစ်နေပြီး toolchain က glibc → မရပါ၊ musl toolchain လိုတယ်
- Board ရဲ့ `GLIBCXX_` အမြင့်ဆုံး symbol < binary လိုအပ်ချက် → `GLIBCXX_... not found` ဖြစ်မယ်
- `libc6-dev` မရှိတဲ့ board archive ကို sysroot လုပ်ရင် `stdio.h` စတဲ့ header မပါဘူး
- Vendor runtime version နဲ့ driver/model version မကိုက်ရင် feature အလုပ်မလုပ်ဘူး

5. `08_build_smoke_test_project.md` အတိုင်း build ပြီး board ပေါ်မှာ `ldd` နဲ့ run test လုပ်ပါ — ဒါက တစ်ခုတည်းသော အတည်ပြုချက်။

---

## $\color{red}{\text{၅။ ဆက်စပ်လမ်းညွှန်များ}}$

- [၀၁ — Debian တပ်ဆင်ခြင်း](01_install_debian_stable.md)
- [၀၂ — Built-in peripheral စစ်ဆေးခြင်း](02_verify_builtin_pheripherials.md)
- [၀၃ — Base OS အချက်အလက် စစ်ခြင်း](03_check_base_dependencies.md)
- [၀၄ — Cross-compile SDK မေးခွန်းနှင့်အဖြေ](04_QuestionAnswer.md)
- [၀၄ — Sysroot archive သုံးပြီး SDK ပြင်ဆင်ခြင်း](04_create_cross_compiler_using_sysroot_archive.md)
- [၀၅ — Sysroot archive မပါဘဲ SDK ပြင်ဆင်ခြင်း](05_create_cross_compiler_without_sysroot_archive.md)
- [၀၆ — Generic ARMv8-A SDK](06_create_ARMv8-A_SDK_env_on_ubuntu2204.md)
- [၀၇ — RK3588 SDK environment တည်ဆောက်ခြင်း](07_create_RK3588_SDK_env_on_ubuntu2204.md)
- [၀၇ — SDK ENV setup Q&A](07_SDK_ENV_Setup_Question_Answer.md)
- [၀၈ — Smoke test project build](08_build_smoke_test_project.md)
- [Script: `05_create_RK3588_SDK_env_without_sysroot.sh`](../scripts/05_create_RK3588_SDK_env_without_sysroot.sh)

References:
- `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/README/00_HOW_TO_BUILD_LINUX_SDK.md`
- `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/README/07_create_RK3588_SDK_env_on_ubuntu2204.md`
- `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/README/08_build_smoke_test_project.md`
- `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/scripts/05_create_RK3588_SDK_env_without_sysroot.sh`

