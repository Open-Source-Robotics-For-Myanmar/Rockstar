# Sysroot ပြင်ဆင်ခြင်း — Board မှ Archive ယူခြင်း

ဤလမ်းညွှန်သည် **sysroot ထဲမှာ ဘာပါရမည်၊ မပါလျှင် ဘာလုပ်ရမည်** ကိုသာ ဖော်ပြသည်။ App ကို cross-compile/build လုပ်ခြင်း မပါဝင်ပါ။

Code blocks များကို host ပေါ်ရှိ Bash terminal တစ်ခုတည်းတွင် အစဉ်လိုက် run ပါ။ `BASE`, `TARGET`, `SDK` တန်ဖိုးများကို မိမိစက်အတွက် အရင်ပြင်ပါ။

## ၁။ Requirements ဖိုင်ကို အရင်ဖတ်ပါ

Host ပေါ်တွင် `03_check_base_dependencies.sh` ကို run ပြီးရသော result folder အတွင်းရှိ `SDK_REQUIREMENTS.md` ကိုဖွင့်ပါ။ ထိုဖိုင်မှ အောက်ပါတို့ကို မှတ်ထားပါ:

- Target architecture, distro/codename, kernel, glibc နှင့် loader။
- `libc6-dev:arm64` အတွက် သုံးရမည့် **တိကျသော version**။
- `libstdc++6`/`libgcc-s1` runtime versions နှင့် C++ development package candidate။
- မရှိသေးသော RKNN/RGA/MPP/GPU user-space runtime သို့မဟုတ် header များ။

Requirements ဖိုင်ထဲမှာ `NOT REPORTED`, `NOT FOUND` သို့မဟုတ် version မကိုက်ဟု ပြထားလျှင် ထိုအချက်ကို ရှင်းလင်းပြီးမှ ဆက်လုပ်ပါ။ Board ကို development package တင်ပြီး ပြင်ဆင်ရန်မလိုပါ။

## ၂။ Board မှ runtime files ကို host ဆီကူးပါ

Host မှ script ကို run ပါ။ Board IP/hostname, SSH user, port ကို အပြန်အလှန်မေးပါမည်။ Password လိုလျှင် SSH က prompt ပြမည်။ Archive ကို host ပေါ်ရှိ `scripts/sysroot_archive/` ထဲသိမ်းပြီး board ပေါ်တွင် ဖိုင်မရေး၊ package မတင်ပါ။

```bash
set -euo pipefail
cd /path/to/Rockstar/01_Rock5B_Debian/scripts
./04_fetch_sysroot_archive_from_board.sh
```

ထို့နောက် archive ကို SDK folder ထဲကူးပါ။ `BASE` နှင့် `SDK` ကို ကိုယ့်စက်အတွက်ပြင်ပါ။

```bash
export BASE="$HOME/path/to/check_results/<result-folder>"
export SDK="$HOME/rock5b-sdk-archive"
ARCHIVE=$(find ./sysroot_archive -maxdepth 1 -type f -name 'rock5b-sysroot-*.tar' -print | sort | tail -n1)

test -s "$BASE/SDK_REQUIREMENTS.md"
test "$(sed -n 's/^| Target architecture | \(.*\) |$/\1/p' "$BASE/SDK_REQUIREMENTS.md" | head -n1)" = arm64
test -s "$ARCHIVE"
mkdir -p "$SDK/base" "$SDK/metadata"
cp "$BASE/SDK_REQUIREMENTS.md" "$SDK/base/"
cp "$ARCHIVE" "$SDK/base/target-libs.tar"
sha256sum "$SDK/base/target-libs.tar" > "$SDK/metadata/target-libs.tar.sha256"
tar -tf "$SDK/base/target-libs.tar" > "$SDK/metadata/archive-files.txt"
```

SSH, `tar`, သို့မဟုတ် permission error ဖြစ်လျှင် archive မပြည့်စုံနိုင်သဖြင့် ရပ်ပြီး error ကိုဖြေရှင်းပါ။ ဒီ archive က `/lib`, `/lib64`, `/usr/lib`, `/usr/include`, pkg-config metadata နဲ့ `/usr/local` ထဲက သတ်မှတ်ထားသော folder များကိုသာ ကူးသည်။ `/opt` ထဲက manually installed vendor files မပါပါ။

## ၃။ Sysroot ထဲ extract လုပ်ပါ

`SDK` path ကို မိမိစက်အတွက် အရင်သတ်မှတ်ပါ။ မရှိသေးသော သို့မဟုတ် အလွတ် directory ထဲသာ extract လုပ်ပါ။ ရှိပြီးသား sysroot ကို မထပ်ရေးပါနှင့်။

```bash
export SDK="$HOME/rock5b-sdk-archive"
test -s "$SDK/base/target-libs.tar"
if [ -n "$(find "$SDK/sysroot" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null || true)" ]; then
    echo "Sysroot is not empty; choose a fresh path or back it up first." >&2
    exit 1
fi
mkdir -p "$SDK/sysroot"
tar --no-same-owner -xf "$SDK/base/target-libs.tar" -C "$SDK/sysroot"
```

Python မသုံးဘဲ absolute symlink များကို sysroot အတွင်းက target ဆီ relative အဖြစ်ပြောင်းပါ။ ဤအဆင့်တွင် GNU `realpath` ပါသော coreutils လိုသည်။

```bash
while IFS= read -r -d '' link; do
    target=$(readlink -- "$link")
    case "$target" in
        /*)
            relative_target=$(realpath -m -s --relative-to="${link%/*}" -- "$SDK/sysroot$target")
            ln -sfn -- "$relative_target" "$link"
            ;;
    esac
done < <(find "$SDK/sysroot" -type l -print0)
```

## ၄။ ပါ/မပါ စစ်ပြီး လိုအပ်တာဖြည့်ပါ

အောက်ပါစစ်ဆေးမှုသည် ရှိသောဖိုင်များကိုသာ ပြသည်။ လမ်းကြောင်းသည် host ဘက်ရှိ sysroot ကို စစ်ခြင်းဖြစ်သည်။

```bash
test -e "$SDK/sysroot/lib/ld-linux-aarch64.so.1"
find "$SDK/sysroot" \( -name 'libc.so*' -o -name 'libstdc++.so*' -o -name 'libgcc_s.so*' \
  -o -name 'stdio.h' -o -name 'crt1.o' -o -name '*.pc' \) -print
```

| လိုအပ်ချက် | မပါလျှင် ဘာလုပ်ရန် |
|---|---|
| Board runtime `.so`, loader နှင့် symlink များ | Archive မပြည့်စုံပါက SSH/tar error ကိုဖြေရှင်းပြီး ပြန်ယူပါ။ App သီးသန့် `/opt` dependency ရှိလျှင် စစ်ဆေးပြီး လိုအပ်သည့် vendor ဖိုင်ကို သီးခြားရယူပါ။ |
| `stdio.h`, `crt1.o`, `libc.so` | Requirements ဖိုင်ပါ `libc6-dev:arm64=<target libc6 version>` ကို host ပေါ်မှာ download လုပ်ပြီး sysroot ထဲ extract လုပ်ပါ။ [Archive မပါသောနည်း၏ package download အဆင့်များ](05_create_cross_compiler_without_sysroot_archive.md) ကိုသုံးပါ။ Board ပေါ်မှာ install မလုပ်ပါနှင့်။ |
| C++ headers/runtime | Requirements ဖိုင်ထဲရှိ target `libstdc++6` version နှင့်ကိုက်ညီသော GCC C++ development files ကို host-side sysroot ထဲဖြည့်ပါ။ [Package-based sysroot လမ်းညွှန်](05_create_cross_compiler_without_sysroot_archive.md) ကိုကြည့်ပါ။ Host cross compiler ၏ မတူသော C++ runtime ကို အလိုအလျောက်မှန်သည်ဟု မယူဆပါနှင့်။ |
| App သုံးမည့် library header/linker files | သက်ဆိုင်ရာ ARM64 `-dev` package သို့မဟုတ် vendor SDK ကို ယူပြီး sysroot ထဲ extract လုပ်ပါ။ App dependency မသိသေးလျှင် အတိအကျစာရင်းကို မဆုံးဖြတ်နိုင်သေးပါ။ |
| RKNN/RGA/MPP/GPU libraries | Requirements ဖိုင်ရှိ driver/runtime မှတ်ချက်ကိုကြည့်ပါ။ Board ပေါ်ရှိ kernel driver တစ်ခုတည်းက user-space runtime/header ကို မဖြည့်ပေးပါ။ ကိုက်ညီသော ARM64 vendor runtime/headers ကို သီးခြားရယူပါ။ |
| Kernel module build headers | Sysroot archive မပါဝင်ပါ။ Kernel module မတည်ဆောက်လျှင် မလိုပါ။ တည်ဆောက်မည်ဆိုလျှင် `uname -r` နှင့်တူသော vendor kernel source/build headers ကို သီးခြားရယူပါ။ |

`linux-libc-dev` သည် userspace kernel API headers ဖြစ်ပြီး kernel module build headers မဟုတ်ပါ။ SDK/sysroot ထဲသို့ ဖြည့်ထားသော package တစ်ခုချင်းစီ၏ version နှင့် SHA256 ကို metadata ထဲမှတ်တမ်းတင်ပါ။ Sysroot ကို runtime deployment အဖြစ် board ဆီတစ်ခုလုံး မပို့ပါနှင့်။
