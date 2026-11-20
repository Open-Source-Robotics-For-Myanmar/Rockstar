# Sysroot ပြင်ဆင်ခြင်း — Archive မယူဘဲ Package များမှတည်ဆောက်ခြင်း

ဤလမ်းညွှန်သည် sysroot အတွက် **လိုအပ်သော target package များကိုသာ** ရွေးယူရန်ဖြစ်သည်။ App ကို cross-compile/build လုပ်ခြင်း မပါဝင်ပါ။ Board ပေါ်တွင် `apt install/upgrade` မလုပ်ပါ။

## ၁။ Generated requirements ဖိုင်ကို အခြေခံပါ

Host ပေါ်တွင် `03_check_base_dependencies.sh` ကို run ပြီးရသော result folder ထဲရှိ `SDK_REQUIREMENTS.md` ကိုဖွင့်ပါ။ ဤ board အတွက် စစ်ထားသော baseline:

- Architecture: `arm64`
- Ubuntu base codename: `resolute`
- `libc6:arm64`: `2.43-2ubuntu2.3`
- Kernel: `6.1.115-vendor-rk35xx`
- `libstdc++6`/`libgcc-s1` runtime နှင့် GCC 16 development package candidate: requirements ဖိုင်ထဲမှ version ကိုသုံးပါ။

အောက်တွင် version သို့မဟုတ် candidate မရှိဟု ဖော်ပြလျှင် ခန့်မှန်းပြီးဆက်မလုပ်ပါနှင့်။ `packages.txt`, `apt_policy.txt` ကိုစစ်ပြီး လိုအပ်သော package version ကိုအတည်ပြုပါ။

## ၂။ Host-side SDK directory နှင့် target version သတ်မှတ်ပါ

အောက်ပါအဆင့်များအားလုံးကို **amd64 Ubuntu host ၏ Bash terminal တစ်ခုတည်းတွင်** အစဉ်လိုက် run ပါ။ `BASE` ကို result folder ဖြင့်ပြင်ပါ။ `SDK` path ရှိပြီးသားဖြစ်ပါက အခြား path ကိုရွေးပါ။

```bash
set -euo pipefail
export BASE="$HOME/path/to/check_results/<result-folder>"
export SDK="$HOME/rock5b-sdk-packages"
test -s "$BASE/SDK_REQUIREMENTS.md"
test -s "$BASE/libc6_version.txt"
test "$(dpkg --print-architecture)" = amd64
if [ -e "$SDK" ]; then
    echo "Choose a new SDK path or back up the existing one: $SDK" >&2
    exit 1
fi
LIBC_VERSION=$(head -n 1 "$BASE/libc6_version.txt")
mkdir -p "$SDK"/{apt,debs,sysroot,metadata}
cp "$BASE/SDK_REQUIREMENTS.md" "$SDK/metadata/"
printf '%s\n' "$LIBC_VERSION" > "$SDK/metadata/target-libc6.version"
```

`SDK_REQUIREMENTS.md` သည် package အမည်/version ရွေးချယ်ရန် baseline ဖြစ်သည်။ **Version မှတ်တမ်းသည် package ဖိုင်ကိုယ်တိုင် မဟုတ်ပါ** — `.deb` ဖိုင်များကို အောက်ပါအတိုင်း download လုပ်ရပါမည်။

## ၃။ Target ARM64 packages ရယူရန် APT ကို သီးခြားပြင်ဆင်ခြင်း

ဤလမ်းညွှန်သည် host APT setting များနှင့် သီးခြားဖြစ်သော Ubuntu 26.04 `resolute` repository ကို အသုံးပြုသည်။ အောက်ပါ setting သည် `$SDK/apt` အောက်တွင်သာ index/status/cache ထားပြီး host system ထဲ package မတင်ပါ။

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

Target codename သည် `resolute` မဟုတ်ပါက source list ကို target inventory နှင့်ကိုက်ညီအောင်ပြင်ပါ။ Armbian ဖြစ်သော်လည်း ဤနေရာတွင် Ubuntu base packages ကိုယူသည်။ Armbian/vendor repository မှ package လိုပါက အဲဒီ repository နဲ့ key ကိုအရင်အတည်ပြုပြီးမှ ထည့်ပါ။

## ၄။ Requirements ဖိုင်တွင်သတ်မှတ်ထားသော အခြေခံ packages ကိုရယူပါ

`libc6-dev` ကို target `libc6` version အတိအကျနှင့်ကိုက်အောင်ယူပါ။ C++ သုံးမည်ဆိုလျှင် `libstdc++-16-dev`/`libgcc-16-dev` ကို requirements ဖိုင်မှာ candidate နဲ့ runtime version ကိုက်ညီကြောင်း စစ်ပြီးမှ ထည့်ပါ။ `linux-libc-dev` ကို app က Linux UAPI headers တိုက်ရိုက်လိုမှသာ ရွေးပါ။ ၎င်းသည် userspace headers ဖြစ်ပြီး kernel module headers မဟုတ်ပါ။

```bash
APT_CONFIG="$SDK/apt/isolated.conf" apt-cache "${APT_OPTS[@]}" \
  policy libc6-dev:arm64 libstdc++-16-dev:arm64 libgcc-16-dev:arm64 linux-libc-dev:arm64

TARGET_PACKAGES=(
  "libc6-dev:arm64=$LIBC_VERSION"
  libstdc++-16-dev:arm64
  libgcc-16-dev:arm64
)
```

Package list ကို **requirements ဖိုင်နဲ့ app dependency အလိုက်ပြင်ပါ**။ C-only sysroot ဆိုလျှင် C++ packages ကိုဖယ်နိုင်သည်။ Requirements ဖိုင်တွင် C++ package candidate မရှိဟု ဖော်ပြလျှင် ထိုအမည်များကို array မှဖယ်ပြီး ကိုက်ညီသော package ကို ရှာဖွေအတည်ပြုပြီးမှ ထည့်ပါ။ Target `libstdc++6` နှင့် compiler version မကိုက်ပါက GCC 16 development packages ကို candidate/version စစ်ပြီးမှသာ သုံးပါ။

Linux UAPI header လိုအပ်မှသာ ဒီ package ကို array ထဲထပ်ထည့်ပါ။ Requirements ဖိုင်တွင် ရှိသော candidate version ကို target kernel/API နှင့်စစ်ဆေးပါ:

```bash
TARGET_PACKAGES+=(linux-libc-dev:arm64)
```

App က link လုပ်ရန်လိုသော library တစ်ခုစီ၏ ARM64 `-dev` package ကို `TARGET_PACKAGES` ထဲထည့်ပါ။ ဥပမာ OpenSSL သုံးမှသာ `libssl-dev:arm64` ထည့်ပါ။ APT မှ package မတွေ့ခြင်း သို့မဟုတ် version မကိုက်ခြင်းရှိပါက အခြား version ကို အတင်းမရွေးပါနှင့်၊ မှန်ကန်သော package ကို ရှာဖွေအတည်ပြုပြီးမှ ဆက်လုပ်ပါ။

```bash
APT_CONFIG="$SDK/apt/isolated.conf" apt-get "${APT_OPTS[@]}" \
  --download-only --no-install-recommends install "${TARGET_PACKAGES[@]}"
```

`--download-only` ကြောင့် package များကို host/board ပေါ် install မလုပ်ဘဲ `$SDK/apt/cache/archives` ထဲသာ download လုပ်သည်။

## ၅။ Download လုပ်ထားသော ARM64 packages များကို sysroot ထဲ extract လုပ်ရန်

```bash
shopt -s nullglob
DEBS=("$SDK/apt/cache/archives/"*.deb)
(( ${#DEBS[@]} > 0 )) || { echo 'No .deb packages downloaded.' >&2; exit 1; }
: > "$SDK/metadata/packages.tsv"
for deb in "${DEBS[@]}"; do
    arch=$(dpkg-deb -f "$deb" Architecture)
    case "$arch" in arm64|all) ;; *)
        echo "Unexpected architecture $arch: $deb" >&2; exit 1 ;;
    esac
    dpkg-deb -f "$deb" Package Version Architecture \
      | paste -sd $'\t' - >> "$SDK/metadata/packages.tsv"
    dpkg-deb -x "$deb" "$SDK/sysroot"
done
sha256sum "${DEBS[@]}" > "$SDK/metadata/packages.sha256"
```

Package များမှ absolute symlink များကို sysroot အတွင်းသို့ ပြန်ညွှန်ပါ:

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

## ၆။ လိုအပ်သောအရာ စုံ/မစုံ ဆုံးဖြတ်ပါ

```bash
test -e "$SDK/sysroot/usr/include/stdio.h"
find "$SDK/sysroot" \( -name crt1.o -o -name libc.so -o -name 'libstdc++.so*' \
  -o -name 'libgcc_s.so*' -o -name '*.pc' \) -print
```

| စစ်ဆေးချက် | မရှိလျှင် နောက်တစ်ဆင့် |
|---|---|
| `stdio.h`, `crt1.o`, `libc.so` | `libc6-dev:arm64` version သည် target `libc6` နှင့်တူကြောင်း စစ်ပါ။ မပါသေးလျှင် `.deb` အမှန်ကို download/extract ပြန်လုပ်ပါ။ |
| C++ headers နဲ့ `libstdc++.so` linker file | Requirements ဖိုင်ပါ target runtime/compiler version ကိုကြည့်ပြီး ကိုက်ညီသော `libstdc++-16-dev:arm64` သို့မဟုတ် target-appropriate package ကိုထည့်ပါ။ |
| `libgcc` linker/runtime files | Requirements ဖိုင်ထဲရှိ `libgcc-s1` version နဲ့ ကိုက်ညီသော target `libgcc` development package ကိုထည့်ပါ။ |
| App library headers/linker files | သက်ဆိုင်ရာ ARM64 `-dev` package ကို `TARGET_PACKAGES` ထဲထည့်ကာ ထပ် download/extract လုပ်ပါ။ |
| RKNN/RGA/MPP/GPU user-space library/header | Ubuntu package မတွေ့ပါက ကိုက်ညီသော ARM64 vendor SDK/runtime ကို သီးခြားရယူပါ။ Kernel driver တစ်ခုတည်းဖြင့် user-space dependency မပြည့်စုံပါ။ |
| Kernel module build headers | `linux-libc-dev` ဖြင့်မရပါ။ Kernel module တည်ဆောက်မှသာ `6.1.115-vendor-rk35xx` နှင့်ကိုက်သော vendor kernel source/build headers ရယူပါ။ |

Archive မသုံးသောကြောင့် board ပေါ်ရှိ installed/manual libraries များကို အလိုအလျောက်မရပါ။ Requirements ဖိုင်ရှိ baseline နဲ့ app dependency ကိုနှိုင်းပြီး runtime package တစ်ခုချင်းစီ ထည့်ပါ။ Runtime `.so`, header, package version နဲ့ SHA256 များကို `metadata` ထဲမှတ်တမ်းတင်ပါ။ Sysroot ထဲတွင် amd64 binary/library မပါကြောင်းစစ်ပြီးမှ အသုံးပြုပါ။
