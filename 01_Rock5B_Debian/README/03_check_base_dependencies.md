# ၀၃ — Base OS အချက်အလက် စစ်ခြင်း

**ရည်ရွယ်ချက်:** Board ကို package install/update မလုပ်ဘဲ လက်ရှိ versions ကို host တွင် မှတ်တမ်းယူရန်။ အောက်ပါ commands အားလုံး **host PC** မှ run ပါ။ SSH login log များတော့ OS က ပုံမှန်ရေးနိုင်သည်။

## လက်ရှိ သိထားသောအချက်

| စက် | OS / architecture |
|---|---|
| ROCK 5B — ပေးထားသော output | Armbian 26.8.3 / Ubuntu 26.04 / `resolute` |
| လက်ရှိ host — စစ်ဆေးထားသည် | Ubuntu 22.04.5 / `jammy` / x86_64 |

Board kernel၊ architecture၊ glibc နှင့် vendor runtime versions ကို အောက်ပါအတိုင်း ထပ်ယူရမည်။ OS အမည်တစ်ခုတည်းဖြင့် မခန့်မှန်းပါနှင့်။

## ၁။ Host မှ board inventory ယူရန်

`TARGET` ကို မိမိ SSH user/IP ဖြင့်ပြင်ပါ။ နောက်ဖိုင်များတွင်လည်း တူညီစွာသုံးပါ။

```bash
export TARGET=mr_robot@rock-5b
export SDK="$HOME/rock5b-sdk"
mkdir -p "$SDK/base"
ssh "$TARGET" 'sh -s' > "$SDK/base/system.txt" <<'SH'
cat /etc/os-release
uname -a
dpkg --print-architecture
getconf GNU_LIBC_VERSION
cat /proc/device-tree/model
printf '\n'
command -v sh tar ldd
ls -l /lib/ld-linux-aarch64.so.1
ldconfig -p 2>/dev/null
ls -l /dev/dri /dev/mali* /dev/rknpu* /dev/rga /dev/mpp_service 2>/dev/null || true
SH
ssh "$TARGET" 'dpkg-query -W -f='"'"'${binary:Package}\t${Version}\t${Architecture}\n'"'" \
  > "$SDK/base/packages.tsv"
ssh "$TARGET" 'dpkg-query -W -f='"'"'${Version}'"'"' libc6:arm64' \
  > "$SDK/base/libc6.version"
cat "$SDK/base/system.txt"
grep -Ei 'libc6|libstdc|libgcc|rknn|rga|mali|mpp|linux-image' "$SDK/base/packages.tsv"
```

**စစ်ရန်:** `arm64` / `aarch64`၊ glibc version၊ kernel version နှင့် loader ရှိရမည်။ Package စာရင်းတွင်မပါသော manually installed `.so` များလည်း ရှိနိုင်သည်။

## ၂။ Base libraries ကို host ဆီဖတ်ကူးရန်

Board တွင် ယာယီဖိုင်မဖန်တီးပါ။ SSH မှ tar stream ဖြင့်ကူးပြီး **host ပေါ်မှာသာ** သိမ်းသည်။ Board package update/install လုပ်နေစဉ် မကူးပါနှင့်။

```bash
set -o pipefail
ssh "$TARGET" 'sh -s' > "$SDK/base/target-libs.tar" <<'SH'
cd /
set --
for p in lib lib64 usr/lib usr/include usr/share/pkgconfig usr/local/lib usr/local/include; do
    if [ -e "$p" ] || [ -L "$p" ]; then
        set -- "$@" "$p"
    fi
done
tar -cf - "$@"
SH
# SSH/tar error ဖြစ်လျှင် ရပ်ပြီး ပြန်ကူးပါ။
tar -tf "$SDK/base/target-libs.tar" > "$SDK/base/archive-files.txt"
sha256sum "$SDK/base/target-libs.tar" > "$SDK/base/target-libs.tar.sha256"
```

Archive က runtime baseline ဖြစ်သည်။ Minimal OS မှာ build headers မပါနိုင်လို့ ဒီ archive တစ်ခုတည်းနဲ့ SDK မပြည့်သေးပါ။

## ၃။ ပြီးဆုံးစစ်ချက်

- [ ] `system.txt`၊ `packages.tsv`၊ `libc6.version`၊ `target-libs.tar` သိမ်းပြီးပြီ။
- [ ] Board တွင် `apt install/upgrade`၊ driver ပြောင်းခြင်း မလုပ်ထားပါ။
- [ ] App လိုအပ်သော GPU/NPU driver က base OS တွင်ရှိပြီး အလုပ်လုပ်သည်။ မရှိလျှင် app `.so` ထည့်ရုံဖြင့် မဖြည့်နိုင်ပါ။

ဆက်ရန်: [၀၄ — Archive သုံးပြီး SDK ပြင်ရန်](04_create_cross_compiler_using_sysroot_archive.md) သို့မဟုတ် [၀၅ — Archive မပါဘဲ SDK ပြင်ရန်](05_create_cross_compiler_without_sysroot_archive.md) ကိုရွေးပြီး [၀၆ — SCP deploy](06_deploy_sample_cpp.md) ကိုဆက်လုပ်ပါ။
