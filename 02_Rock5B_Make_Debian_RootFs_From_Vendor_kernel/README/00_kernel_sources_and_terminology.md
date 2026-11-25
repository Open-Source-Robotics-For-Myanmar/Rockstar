# $\color{#00c853}{\text{Rock 5B vendor kernel နှင့် ကိုယ်ပိုင် rootfs}}$

ဒီစာတမ်းက `./02_Rock5B_Make_Debian_Sysroot_From_Vendor_kernel/README/00_kernel_sources_and_terminology.md` ဖြစ်ပါတယ်။ Rock 5B အတွက် vendor ပေးတဲ့ stable kernel ကို ယူပြီး rootfs သို့မဟုတ် sysroot ကို ကိုယ်တိုင်ရွေးတဲ့ Debian သို့မဟုတ် တခြား distro နဲ့ တည်ဆောက်ချင်တဲ့အခါ နားလည်ရမယ့် အခေါ်အဝေါ်၊ kernel ရင်းမြစ်၊ boot chain နှင့် အသုံးဝင်တဲ့ link တွေကို စုထားတာဖြစ်ပါတယ်။

## $\color{red}{\text{၁။ ရည်ရွယ်ချက်}}$

- Kernel ကို vendor BSP ကနေယူမယ်။ userspace ကိုတော့ host ပေါ်မှာ ကိုယ်တိုင် Debian သို့မဟုတ် အခြား distro rootfs အဖြစ် ဆောက်မယ်။
- ဒီနှစ်ခုကို တွဲဖို့ အဓိက လိုအပ်တာက ABI ကိုက်ညီမှု၊ kernel UAPI headers၊ modules နဲ့ firmware၊ နှင့် board ရဲ့ boot chain ကို နားလည်တာဖြစ်တယ်။
- Kernel ကို ပြောင်းလိုက်ရင် bootloader ကို မဖြစ်မနေ ပြောင်းစရာမလိုပါဘူး။ ဒါပေမယ့် U-Boot သို့မဟုတ် rkbin ကိုပါ ပြောင်းမယ်ဆိုရင် blob ဗားရှင်းတွေ တိတိကျကျ တွဲရမယ်။

## $\color{red}{\text{၂။ Kernel အမျိုးအစားခွဲခြားခြင်းနှင့် အခေါ်အဝေါ်}}$

| အခေါ်အဝေါ် | အဓိပ္ပာယ် | လက်ရှိ repo / branch | Source |
|---|---|---|---|
| Vendor BSP kernel, Rockchip BSP kernel, vendor kernel | Rockchip ရဲ့ downstream kernel tree ဖြစ်ပြီး kernel.org မဟုတ်ပါဘူး။ `rockchip-linux/kernel` ကိုယ်တိုင် BSP kernel source လို့ ခေါ်တယ်။ default `develop-6.1`၊ active `develop-5.10` နှင့် `develop-6.12` ရှိတယ်။ | `rockchip-linux/kernel` | [1] |
| Vendor stable, vendor-stable, Radxa stable BSP | Board vendor က ရေခဲထားတဲ့ frozen BSP branch ဖြစ်ပြီး kernel.org -stable နဲ့ မတူပါဘူး။ `radxa/kernel` မှာ active `linux-6.1-stan-rkr4.1`, `linux-6.1-stan-rkr5.1`, `linux-6.12-stan-rkr1`, `linux-6.12-stan-rkr1.1` တွေ ရှိတယ်။ လက်ရှိ Radxa build စာရွက်က `radxa-pkg/linux-rk2410` ကို ညွှန်းပြီး release `6.1.84-10` ပါတယ်။ | `radxa/kernel`, `radxa-pkg/linux-rk2410` | [2][3][4] |
| Armbian `vendor`, `vendor-next` | Armbian ရဲ့ Rockchip BSP track အမည်တွေ။ Config မှာ `vendor` က 6.1 နဲ့ `vendor-next` က 6.12 ကို သတ်မှတ်တယ်။ `armbian/linux-rockchip` ရဲ့ default က `rk-6.1-rkr7.2` ဖြစ်တယ်။ | `armbian/linux-rockchip` | [5][6] |
| Mainline, upstream | Linus tree ကို ဆိုလိုတာဖြစ်ပြီး RK3588 feature အခြေအနေကို Collabora က စောင့်ကြည့်ထားတယ်။ Armbian board config မှာ `KERNEL_TARGET="current,edge,vendor"` နဲ့ `BOOT_FDT_FILE="rockchip/rk3588-rock-5b.dtb"` ပါတယ်။ | kernel.org, Collabora integration tree | [10][11] |
| linux-stable, stable, -stable | Greg KH ရဲ့ stable series ဖြစ်ပြီး ပြင်ဆင်ချက်က mainline မှာ အရင် ရောက်ပြီးဖြစ်ရမယ်။ kernel.org `releases.json` အရ 2026-11-25 မှာ mainline `7.4-rc4`, stable `7.3.6`, longterm `6.1.193`, `6.12.119`, `6.18.65` ဖြစ်တယ်။ | `stable/linux.git` | [7][8] |
| linux-next | နောက်ထပ် merge window အတွက် စမ်းသပ်တဲ့ integration testing tree ဖြစ်ပြီး release မဟုတ်ပါဘူး။ | `linux-next.git` | [9] |
| Armbian `current`, `edge` | `current` က LTS mainline baseline၊ `edge` က အသစ်ဆုံး mainline series။ Repo status မှာ `vendor-rk35xx` 6.1.115, `current-rockchip64` 6.18.44, `edge-rockchip64` 7.3.3 လို့ ပြထားတယ်။ | Armbian package repository | [17] |

အဓိက သတိပြုရမှာက **vendor-stable** ဆိုတာ board vendor ရဲ့ frozen BSP branch ဖြစ်ပြီး **linux-stable / -stable** ဆိုတာ kernel.org stable series ဖြစ်တယ် — နှစ်ခုက မတူညီတဲ့ tree တွေဖြစ်ပါတယ် [7]။

`rkrN` ဆိုတဲ့ suffix ရဲ့ အဓိပ္ပာယ်ကို ရှင်းပြထားတဲ့ primary doc မတွေ့ပါ။ နာမည်ပေးပုံအရသာ ယူဆရတာဖြစ်ပြီး အတည်မပြုရသေးပါဘူး [unverified]။ `radxa/kernel` ရဲ့ default `linux-7.0.11` က mainline-based ဖြစ်နိုင်ပေမယ့် Rock 5B vendor build အတွက် မဟုတ်နိုင်လို့ မသုံးခင် စစ်ပါ [unverified]။

## $\color{red}{\text{၃။ မဖြစ်မနေ လိုအပ်တဲ့ boot chain}}$

1. **DDR init TPL နှင့် SPL** — Rockchip ရဲ့ DDR init blob က closed-source ဖြစ်ပြီး rkbin ထဲက prebuilt binary တွေသုံးရတယ်။ `idbloader.img` ကို LBA 64 မှာ ထားတယ် [13][14][16]။
2. **BL31 (TF-A)** — `make PLAT=rk3588 bl31` နဲ့ ဆောက်တာ သို့မဟုတ် rkbin ထဲက BL31 ကို ယူပြီး `u-boot.itb` ထဲ ထည့်တယ် [13][15]။
3. **U-Boot proper** — vendor ဘက်မှာ `rock-5b-rk3588_defconfig` နဲ့ `u-boot.itb` ကို LBA 16384 မှာ ထားတယ်။ Mainline က binman `u-boot-rockchip.bin` ကို LBA 64 မှာ သုံးတယ် [12][13]။
4. **DTB** — kernel tree နဲ့ ကိုက်တဲ့ `rk3588-rock-5b.dtb` လိုတယ်။ Vendor နဲ့ mainline DTB ကို လဲလို့ မရပါဘူး [11][12]။
5. **Kernel artifacts** — `Image`, DTB, modules နှင့် firmware တွေ လိုတယ်။ Radxa ရဲ့ kernel .deb တွေက kernel, device tree, modules နဲ့ firmware ကို ထုပ်ပေးတယ် [12]။
6. **Initramfs နှင့် rootfs ညွှန်းချက်** — `extlinux.conf` မှာ `kernel`, `initrd`, `devicetreedir` ပါတယ် [12]။ Radxa က `root=UUID=...` သုံးပြီး Armbian က blkid နဲ့ UUID တွက်ပြီး `append root=$rootfs` လို့ ရေးတယ် [21]။ Label, PARTUUID သို့မဟုတ် UUID �ဘယ်ဟာပဲသုံးသုံး တကယ့် filesystem နဲ့ ကိုက်နေဖို့သာ လိုအပ်တယ်။

## $\color{red}{\text{၄။ ဒီ project အတွက် အကြံပြုချက်}}$

- ရှိပြီးသား board image က vendor 6.1.115 ဖြစ်တာကြောင့် 6.1 track ကိုပဲ ဆက်ထားတာက အန္တရာယ်အနည်းဆုံးဖြစ်တယ် [17]။
ဥပမာ `radxa/kernel` ရဲ့ `linux-6.1-stan-rkr5.1` [2] သို့မဟုတ် Armbian `rk-6.1-rkr7.2` [5][6]။
- U-Boot နဲ့ rkbin ကို မထိဘဲ kernel ကိုသာ ပြောင်းရင် boot chain အရင်းအမြစ်ကို ထိန်းထားနိုင်တယ် [12]။
- Mainline ကို ရွေးမယ်ဆိုရင် RK3588 ရဲ့ feature အားလုံး mainline မှာ မရသေးဘူးဆိုတာ Collabora status ကို ကြည့်ပါ [10]။
- နောက်တစ်ဆင့်အနေနဲ့ rootfs/sysroot ဘယ်လိုဆောက်မလဲဆိုတာ `./02_Rock5B_Make_Debian_Sysroot_From_Vendor_kernel/README/01_rootfs_sysroot_build_methods.md` မှာ ရေးထားပါတယ်။

Sources:
[1] https://github.com/rockchip-linux/kernel
[2] https://github.com/radxa/kernel/branches
[3] https://docs.radxa.com/en/rock5/rock5b/low-level-dev/build-system/kernel
[4] https://github.com/radxa-pkg/linux-rk2410
[5] https://github.com/armbian/linux-rockchip/branches
[6] https://raw.githubusercontent.com/armbian/build/main/config/sources/families/include/rockchip_vendor_common.inc
[7] https://www.kernel.org/doc/html/latest/process/stable-kernel-rules.html
[8] https://www.kernel.org/releases.json
[9] https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/about
[10] https://gitlab.collabora.com/hardware-enablement/rockchip-3588/notes-for-rockchip-3588/-/blob/main/mainline-status.md
[11] https://raw.githubusercontent.com/armbian/build/main/config/boards/rock-5b.conf
[12] https://wiki.radxa.com/Rock5/guide/build-kernel-on-5b
[13] https://docs.u-boot-project.org/en/latest/board/rockchip/rockchip.html
[14] https://gitlab.collabora.com/hardware-enablement/rockchip-3588/notes-for-rockchip-3588/-/blob/main/upstream_uboot.md
[15] https://tf-a.docs.trustedfirmware.org/en/lts-v2.12.16/plat/rockchip.html
[16] https://github.com/radxa/rkbin
[17] https://docs.armbian.com/status/package-repository
[21] https://raw.githubusercontent.com/armbian/build/main/lib/functions/image/partitioning.sh

References:
- `./02_Rock5B_Make_Debian_Sysroot_From_Vendor_kernel/README/00_kernel_sources_and_terminology.md`
- `./AGENTS_for_markdown.md`
- `./md_lists.md`