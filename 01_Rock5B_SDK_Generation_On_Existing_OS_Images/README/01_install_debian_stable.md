# $\color{#00c853}{\text{ROCK 5B မှာ Debian / Ubuntu တင်ခြင်း}}$

**အကြံပြုချက် — လက်ရှိ Armbian Debian + vendor kernel ကို ဆက်သုံးပါ။** SDK က Ubuntu လိုအပ်မှ ပြောင်းပါ။ Image စာရင်း စစ်ဆေးခဲ့သည့်ရက်: **2026-11-20**။

## $\color{red}{\text{၁။ Image ရွေးရန်}}$

| ရွေးချယ်စရာ | အသုံးပြုရန် |
|---|---|
| Armbian Debian 13 Trixie + vendor | လက်ရှိ project အတွက် အခြေခံရွေးချယ်မှု |
| Armbian Ubuntu 26.04 Resolute + vendor | Ubuntu packages လိုအပ်လျှင် |
| Armbian + current kernel | Mainline kernel စမ်းရန်၊ accelerator support ပြန်စစ်ရန် |
| Ubuntu Rockchip 24.04 Server | Ubuntu 24.04 compatibility စမ်းရန်၊ project archive ဖြစ်နေသည် |

**Armbian** မှာ Debian/Ubuntu နှစ်မျိုးလုံးရှိသည်။ **vendor/current** က kernel အမျိုးအစား၊ **Minimal/Server** က ထည့်ပေးထားသော packages အမျိုးအစားဖြစ်သည်။ နှစ်မျိုးလုံး desktop မပါဘဲ server အဖြစ် သုံးနိုင်သည်။ `resolute` = Ubuntu **26.04**၊ `noble` = **24.04**။

NPU/GPU အလုပ်လုပ်ရန် OS အမည်ထက် **driver + runtime + SDK version** ကိုက်ညီမှုက အရေးကြီးသည်။ [Armbian ရှင်းလင်းချက်](https://docs.armbian.com/getting-started/choosing-an-image/)

## $\color{red}{\text{၂။ Armbian Debian vendor — အကြံပြု}}$

[တရားဝင် image စာရင်း](https://armbian.com/boards/rock-5b) · [BFSU mirror](https://mirrors.bfsu.edu.cn/armbian-releases/rock-5b/archive/)

အောက်ပါ commands ကို **image ရေးမည့် PC** ပေါ်တွင် run ပါ။

```bash
mkdir -p ~/rock5b-images
cd ~/rock5b-images
IMAGE=Armbian_26.8.3_Rock-5b_trixie_vendor_6.1.115_minimal.img.xz
BASE=https://mirrors.bfsu.edu.cn/armbian-releases/rock-5b/archive
curl -fLO "$BASE/$IMAGE"
curl -fLO "$BASE/$IMAGE.sha"
sha256sum -c "$IMAGE.sha"
```

Checksum `OK` ဖြစ်မှ flash ပါ။ Signature စစ်ရန် [Armbian လမ်းညွှန်](https://docs.armbian.com/getting-started/choosing-an-image/#download-and-verification) ကိုကြည့်ပါ။

## $\color{red}{\text{၃။ Ubuntu image links}}$

### $\color{cyan}{\text{Armbian Ubuntu + vendor}}$

- [Ubuntu Minimal image](https://dl.armbian.com/rock-5b/Resolute_vendor_minimal)
- [SHA256](https://dl.armbian.com/rock-5b/Resolute_vendor_minimal.sha)
- [Signature](https://dl.armbian.com/rock-5b/Resolute_vendor_minimal.asc)

စာရင်းစစ်ချိန်: **Armbian 26.8.3 / Ubuntu 26.04 / vendor 6.1.115**။ Links က နောက် build သို့ ပြောင်းနိုင်သည်။ Download ရလာသော filename အတိုင်း checksum စစ်ပါ။

```bash
mkdir -p ~/rock5b-images/ubuntu-armbian
cd ~/rock5b-images/ubuntu-armbian
curl -fL -OJ https://dl.armbian.com/rock-5b/Resolute_vendor_minimal
curl -fL -OJ https://dl.armbian.com/rock-5b/Resolute_vendor_minimal.sha
ls -lh
# Build ပြောင်းလျှင် filename ကို ပြင်ပါ။
sha256sum -c Armbian_26.8.3_Rock-5b_resolute_vendor_6.1.115_minimal.img.xz.sha
```

Server က filename မပေးလျှင် catalog မှ browser ဖြင့် download လုပ်ပါ။ ဒါက Ubuntu အခြေခံ **Armbian Minimal** ဖြစ်သည်။

### $\color{cyan}{\text{Ubuntu 24.04 Server — community image}}$

[ROCK 5B download စာရင်း](https://joshua-riek.github.io/ubuntu-rockchip-download/boards/rock-5b.html)

- [Ubuntu 24.04 Server image](https://github.com/Joshua-Riek/ubuntu-rockchip/releases/download/v2.4.0/ubuntu-24.04-preinstalled-server-arm64-rock-5b.img.xz)
- [SHA256](https://github.com/Joshua-Riek/ubuntu-rockchip/releases/download/v2.4.0/ubuntu-24.04-preinstalled-server-arm64-rock-5b.img.xz.sha256)

**v2.4.0 / Linux 6.1 / 2024-10-23 build**။ [Project](https://github.com/Joshua-Riek/ubuntu-rockchip) ကို **2026-04-29** တွင် archive လုပ်ထားသည်။ Canonical တရားဝင် ROCK 5B image မဟုတ်ပါ။ Production မရွေးမီ kernel/bootloader maintenance ကိုစစ်ပါ။

```bash
mkdir -p ~/rock5b-images/ubuntu-server
cd ~/rock5b-images/ubuntu-server
BASE=https://github.com/Joshua-Riek/ubuntu-rockchip/releases/download/v2.4.0
IMAGE=ubuntu-24.04-preinstalled-server-arm64-rock-5b.img.xz
curl -fLO "$BASE/$IMAGE"
curl -fLO "$BASE/$IMAGE.sha256"
sha256sum -c "$IMAGE.sha256"
```

## $\color{red}{\text{၄။ Flash နှင့် ပထမဆုံး boot}}$

**Flash လုပ်လျှင် ရွေးထားသည့် disk ပေါ်က data ပျက်မည်။** ROCK **5B** image ကိုသာ ရွေးပါ။ Generic Ubuntu ARM64 ISO ကို တိုက်ရိုက်အစားမထိုးပါနှင့်။

အလွယ်ဆုံး: **Armbian Imager / USBImager / balenaEtcher** ဖြင့် verified image ကိုရေးပါ။ CLI သုံးလိုလျှင်:

```bash
lsblk -o NAME,SIZE,MODEL,MOUNTPOINTS
# IMAGE ကို checksum အောင်ထားသော file လမ်းကြောင်းအဖြစ် ပြင်ပါ။
IMAGE=/absolute/path/to/verified.img.xz
# /dev/sdX ကို SD card disk အဖြစ် ပြင်ပါ။ Mounted partitions ကို အရင် unmount ပါ။
set -o pipefail
xzcat "$IMAGE" | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

| Image | ပထမဆုံး login |
|---|---|
| Armbian | ပုံမှန် `root` / `1234`၊ first-boot setup ဖြင့် password/user ပြောင်းရန် |
| Ubuntu Rockchip Server | `ubuntu` / `ubuntu`၊ login ဝင်ပြီး password ပြောင်းရန် |

Armbian network/config ပြင်ရန် `sudo armbian-config` သုံးပါ။ Ubuntu image ထဲ Debian `trixie` repo မထည့်ပါနှင့်။ Ubuntu Rockchip ထဲ Armbian kernel packages မရောပါနှင့်။

## $\color{red}{\text{၅။ Boot ပြီးစစ်ရန်}}$

```bash
cat /etc/os-release
uname -a
tr '\0' '\n' < /proc/device-tree/model
python3 --version
sudo journalctl -k -b | grep -Ei 'rknpu|npu|gpu|drm|error|fault'
```

- [ ] OS release နှင့် ROCK 5B အမည် မှန်သည်။
- [ ] [Hardware checklist](02_verify_builtin_pheripherials.md) အောင်သည်။
- [ ] SDK လိုအပ်သည့် Python/runtime version ကိုက်ညီသည်။

**အခြား kernel လိုလျှင်:** [Armbian catalog](https://armbian.com/boards/rock-5b) မှ `current` image ကို သီးခြား SD card ဖြင့် စမ်းပါ။ Vendor ပြန်ပြောင်းရန် `armbian-config` သို့မဟုတ် vendor image အသစ်ဖြင့် သုံးပါ။ Bootloader flash လုပ်ခြင်းကို ပုံမှန် OS install အဆင့်အဖြစ် မလိုအပ်ဘဲ မလုပ်ပါနှင့်။

ဖော်ပြထားသော images များကို ဤနေရာမှ download အပြည့်/board boot စမ်းထားခြင်းမရှိပါ။

References:
- `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/README/01_install_debian_stable.md`
- `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/README/00_HOW_TO_BUILD_LINUX_SDK.md`
- `./md_lists.md`

