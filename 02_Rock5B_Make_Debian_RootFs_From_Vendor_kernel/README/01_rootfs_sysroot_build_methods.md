# $\color{#00c853}{\text{rootfs နှင့် sysroot တည်ဆောက်ရေး tools}}$

ဒီစာတမ်းက `./02_Rock5B_Make_Debian_Sysroot_From_Vendor_kernel/README/01_rootfs_sysroot_build_methods.md` ဖြစ်ပါတယ်။ vendor kernel နဲ့ တွဲမယ့် Debian သို့မဟုတ် အခြား distro rootfs ကို amd64 host ပေါ်မှာ ဘယ်လို tools တွေနဲ့ ဆောက်ကြသလဲ၊ ဘာတွေ မဖြစ်မနေ လိုသလဲဆိုတာ စုထားတာဖြစ်ပါတယ်။

## $\color{red}{\text{၁။ rootfs နှင့် sysroot ကွာခြားချက်}}$

- Rootfs က boot လုပ်လို့ရတဲ့ target filesystem အပြည့်အစုံဖြစ်ပြီး sysroot က cross-compiler က target headers နဲ့ libraries ကို ရှာဖို့သုံးတဲ့ directory ဖြစ်တယ်။
- Sysroot တစ်ခုတည်းက bootable image မဟုတ်ပါဘူး။ Bootloader, kernel, DTB, initramfs တွေ သီးခြား လိုအပ်တယ်။
- ဒီ repo ရဲ့ ရည်ရွယ်ချက်က board ကို မပြောင်းဘဲ host ပေါ်မှာ sysroot ဆောက်ပြီး vendor kernel နဲ့ တွဲစမ်းတာဖြစ်တယ်။

## $\color{red}{\text{၂။ sysroot ထဲ မရှိမဖြစ်ပါဝင်ရမယ့်အရာများ}}$

| အပိုင်း | ဘာလို့လိုသလဲ | စစ်ဆေးနည်း / Source |
|---|---|---|
| arm64 glibc runtime နှင့် dynamic loader | `libc.so.6` နဲ့ `/lib/ld-linux-aarch64.so.1` မပါရင် ထွက်လာတဲ့ binary က board မှာ run မမယ်။ | `dpkg -L libc6:arm64`, `readelf -l` [45] |
| `libc6-dev` | C headers, startup objects, linker symlink တွေ ပါတယ်။ Debian `libc6-dev-arm64-cross` က cross compile အတွက် headers နဲ့ symlink တွေ ပေးပြီး `linux-libc-dev-arm64-cross` ကို depend လုပ်တယ်။ | [31] |
| C++ headers နှင့် libstdc++ | `libstdc++-11-dev-arm64-cross` က headers နဲ့ static libs ပေးပြီး `libstdc++6-arm64-cross`, `libc6-dev-arm64-cross` ကို depend လုပ်တယ်။ | [32] |
| Kernel UAPI headers | ရွေးထားတဲ့ vendor kernel က `make headers_install ARCH=arm64 INSTALL_HDR_PATH=...` နဲ့ userspace headers ထုတ်ပေးတယ်။ glibc FAQ အရ headers က running kernel နဲ့ တူရမယ်လို့ မသတ်မှတ်ပေမယ့် အသစ်က ပိုကောင်းတယ်။ Out-of-tree module ဆောက်မယ်ဆိုရင် configured kernel build tree နဲ့ `Module.symvers` ပါ လိုတယ်။ | [28][44] |
| pkg-config metadata | `PKG_CONFIG_LIBDIR`, `PKG_CONFIG_PATH`, `PKG_CONFIG_SYSROOT_DIR` တွေကြောင့် host library နေရာမှာ target `.pc` ဖိုင်တွေကို ရှာစေနိုင်တယ်။ | [33][34] |
| merged-/usr နှင့် symlink ညီညွတ်မှု | debootstrap မှာ `--merged-usr` ရှိပြီး အများသုံး suite မှာ default ဖြစ်တယ်။ mmdebstrap မှာလည်း တိတိကျကျ ကိုင်တွယ်တယ်။ | [24][25] |
| Vendor libs (RKNN, RGA, MPP) | Distro repo မှာ မရှိနိုင်လို့ vendor `.deb` တွေကို `dpkg-deb -x` သို့မဟုတ် `dpkg --root=` နဲ့ ထည့်ပြီး version ကို မှတ်ထားပါ။ | [35][36] |
| Host cross toolchain | `crossbuild-essential-arm64` က `gcc-aarch64-linux-gnu`, `g++-aarch64-linux-gnu` နဲ့ dpkg-cross ကို ဆွဲယူတယ်။ Multiarch နည်းလမ်းက `dpkg --add-architecture arm64` + `apt-get install crossbuild-essential-arm64` ဖြစ်တယ်။ | [26][30][45] |
| CMake toolchain file နှင့် pkg-config wrapper | `CMAKE_SYSTEM_NAME`, `CMAKE_SYSROOT`, `CMAKE_C_COMPILER`, `CMAKE_CXX_COMPILER`, `CMAKE_FIND_ROOT_PATH_MODE_*` တွေ သတ်မှတ်ပေးရတယ်။ | [29] |

## $\color{red}{\text{၃။ တခြားသူတွေ သုံးတဲ့ tools နှင့် ဥပမာ}}$

| Method | ဥပမာ command | ဒီ project အတွက် သင့်တော်မှု |
|---|---|---|
| debootstrap | `debootstrap --arch=arm64 --foreign bookworm ROOT http://deb.debian.org/debian` ပြီးရင် `chroot ROOT /debootstrap/debootstrap --second-stage`။ `--variant=buildd`, `--include=`, `--merged-usr` တွေ ရှိတယ်။ | နာမည်ကြီးပြီး ယုံကြည်ရတယ်။ amd64 မှာ `--foreign` နဲ့ qemu-user/binfmt လိုတယ် [24][25][27]။ |
| mmdebstrap | `sudo mmdebstrap --architectures=arm64 --variant=buildd --include=libc6-dev,libstdc++-11-dev,pkg-config,ca-certificates bookworm ROOT.tar http://deb.debian.org/debian` | apt solver သုံးတယ်, `sudo/root/unshare/fakeroot/fakechroot/chrootless` modes ရှိတယ်, dir/tar/squashfs/ext4 output နဲ့ hooks ပါတယ်။ **ဒီ project အတွက် အသင့်တော်ဆုံး** [25]။ |
| multistrap | `multistrap -f config` | Foreign bootstrap လုပ်နိုင်ပေမယ့် legacy ဖြစ်တယ်။ mmdebstrap ကို ရွေးတာ ပိုကောင်းတယ် [47]။ |
| sbuild | `sudo apt install sbuild mmdebstrap uidmap` ပြီးရင် sbuild chroot ဆောက်တယ်။ | Debian package တွေကို reproducible ဆောက်ဖို့က အဆင်ပြေပေမယ့် sysroot ထုတ်ဖို့ တိုက်ရိုက်ရည်ရွယ်တာ မဟုတ်ပါဘူး [37]။ |
| dpkg / apt ကိုယ်တိုင် | `apt-get download libc6-dev:arm64`, `dpkg-deb -x pkg.deb SYSROOT`, `dpkg --root=SYSROOT -i pkg.deb` | Minimal ဖြစ်ပေမယ့် dependency ကိုယ်တိုင်ရှင်းရတယ်။ `dpkg-deb -x` က extract သာဖြစ်ပြီး install မဟုတ်ဘူးဆိုတာ သတိပြုပါ [34][35][36]။ |
| qemu-user / proot / schroot | `apt install qemu-user qemu-user-binfmt`, `proot -r ROOT cmd` | arm64 post-install script တွေကို amd64 ပေါ်မှာ run ချင်ရင် သုံးတယ်။ trixie မှာ `qemu-user-static` အစား `qemu-user` ဖြစ်တယ် [27][46]။ |
| Docker buildx | `docker buildx build --platform linux/arm64 .`, `FROM --platform=$BUILDPLATFORM` + `ARG TARGETARCH` | Containerized rootfs အတွက် အဆင်ပြေပေမယ့် emulation က နှေးတယ်။ Sysroot အဖြစ် stage ကို export လို့ရတယ် [38]။ |
| Buildroot | Toolchain + rootfs customization နဲ့ image ဆောက်တယ်။ | Debian userspace မဟုတ်လို့ ဒီ project နဲ့ မကိုက်ပါဘူး [39]။ |
| Yocto / meta-rockchip | `bitbake image -c populate_sdk` နဲ့ SDK installer ထွက်တယ်။ Kernel/headers ကို override လုပ်လို့ရတယ်။ | အားကောင်းပေမယ့် လေးတယ်။ Yocto userspace ဖြစ်တယ် [40]။ |
| Armbian build framework | `git clone https://github.com/armbian/build && ./compile.sh` | Image အပြည့်အစုံအတွက် အဆင်ပြေပေမယ့် သတ်မှတ်ထားတဲ့ vendor kernel နဲ့ sysroot သီးသန့်ထုတ်ဖို့ မသင့်တော်ပါဘူး [41]။ |
| Radxa rbuild / rsdk | `radxa-repo/rbuild` က maintenance mode ဖြစ်ပြီး `RadxaOS-SDK/rsdk` က bdebstrap ကနေ mmdebstrap, jsonnet, guestfish ကို သုံးတယ်။ `rsdk build rock-5b-6_1 bullseye cli` ဆိုတဲ့ ဥပမာ ရှိတယ်။ | Board-specific recipe အတွက် ကောင်းတဲ့ reference ဖြစ်ပေမယ့် RadxaOS ရဲ့ ကိုယ်ပိုင် repo တွေ ပါတယ် [19][42][43]။ |

## $\color{red}{\text{၄။ ဒီ project အတွက် အကြံပြုထားတဲ့ လမ်းကြောင်း}}$

1. mmdebstrap ကို အဓိက builder အဖြစ်သုံးပြီး target glibc နဲ့ ကိုက်တဲ့ suite ကို ရွေးပါ။ ရှိပြီးသား board က glibc 2.43 ဖြစ်တာကြောင့် တူညီတဲ့ suite သို့မဟုတ် glibc နိမ့်တဲ့ suite ကိုသာ သုံးပါ [44]။

```bash
sudo apt install mmdebstrap qemu-user qemu-user-binfmt binfmt-support
sudo mmdebstrap --architectures=arm64 --variant=buildd \
  --include=libc6-dev,libstdc++-11-dev,pkg-config,ca-certificates \
  bookworm sysroot-arm64.tar http://deb.debian.org/debian
mkdir -p sysroot-arm64 && sudo tar -xpf sysroot-arm64.tar -C sysroot-arm64
```

2. Vendor kernel ရဲ့ UAPI headers ကို distro `linux-libc-dev` နေရာမှာ ထပ်ဆင့်တင်ပါ။

```bash
make -C /path/to/vendor/kernel ARCH=arm64 \
  INSTALL_HDR_PATH="$PWD/sysroot-arm64/usr" headers_install
```

3. Host မှာ cross toolchain တပ်ဆင်ပါ [26][30]။
   `libc6-dev-arm64-cross` နဲ့ `libstdc++-11-dev-arm64-cross` ပါ ထည့်ပါ [31][32]။

```bash
sudo apt install crossbuild-essential-arm64 \
  libc6-dev-arm64-cross libstdc++-11-dev-arm64-cross
```

4. pkg-config wrapper မှာ `PKG_CONFIG_SYSROOT_DIR` နဲ့ `PKG_CONFIG_LIBDIR` သတ်မှတ်ပြီး CMake toolchain file မှာ `CMAKE_SYSROOT` ထည့်ပါ [29]။
pkg-config wrapper အတွက် [33][34]။
5. Vendor `.deb` တွေကို `dpkg-deb -x` သို့မဟုတ် `dpkg --root=` နဲ့ ထည့်ပြီး sysroot tarball ကို checksum လုပ်ပါ — ဒါက ရှိပြီးသား `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/scripts/04_fetch_sysroot_archive_from_board.sh` ရဲ့ output နဲ့ အလားတူ ဖြစ်စေဖို့ဖြစ်တယ် [35][36]။
6. Smoke build လုပ်ပြီး `aarch64-linux-gnu-readelf -d` နဲ့ GLIBC symbol version တွေကို စစ်ပါ။ Board ပေါ်မှာ တကယ် run ကြည့်မှသာ ABI ကို အတည်ပြုနိုင်ပါတယ် [44]။

## $\color{red}{\text{၅။ သတိပြုရမယ့် အန္တရာယ်များ}}$

- Host cross toolchain ရဲ့ glibc 2.35 headers ကို board glibc 2.43 rootfs headers နဲ့ မရောပါနဲ့။ `-cross` package တွေက dpkg-cross prefix သုံးပြီး native arm64 rootfs က multiarch path သုံးတာမို့ `dpkg -L` နဲ့ စစ်ပါ [45]။
- `dpkg-deb -x` ကို install လို့ မယူဆပါနဲ့ — dependency နဲ့ maintainer script တွေ မ run ပါဘူး [35]။
- Kernel headers က userspace အတွက် လုံလောက်ပေမယ့် kernel module ဆောက်ဖို့ configured full build tree နဲ့ `Module.symvers` က သီးခြား လိုအပ်ပါတယ် [28]။

Sources:
[19] https://radxaos-sdk.github.io/rsdk/tutorials/customize.html
[24] https://manpages.debian.org/bookworm/debootstrap/debootstrap.8.en.html
[25] https://manpages.debian.org/trixie/mmdebstrap/mmdebstrap.1.en.html
[26] https://wiki.debian.org/CrossToolchains
[27] https://wiki.debian.org/QemuUserEmulation
[28] https://docs.kernel.org/kbuild/headers_install.html
[29] https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html
[30] https://packages.debian.org/bookworm/crossbuild-essential-arm64
[31] https://packages.debian.org/bookworm/libc6-dev-arm64-cross
[32] https://packages.debian.org/bookworm/libstdc++-11-dev-arm64-cross
[33] https://manpages.debian.org/bookworm/pkgconf/pkg-config.1.en.html
[34] https://autotools.info/pkgconfig/cross-compiling.html
[35] https://manpages.debian.org/bookworm/dpkg/dpkg-deb.1.en.html
[36] https://manpages.debian.org/bookworm/dpkg/dpkg.1.en.html
[37] https://wiki.debian.org/sbuild
[38] https://docs.docker.com/build/building/multi-platform
[39] https://buildroot.org/downloads/manual/manual.html
[40] https://docs.yoctoproject.org/sdk-manual/index.html
[41] https://docs.armbian.com/build-framework/getting-started
[42] https://raw.githubusercontent.com/radxa-repo/rbuild/main/README.md
[43] https://raw.githubusercontent.com/RadxaOS-SDK/rsdk/main/README.md
[44] https://sourceware.org/glibc/wiki/FAQ
[45] https://wiki.debian.org/Multiarch
[46] https://proot-me.github.io
[47] https://packages.debian.org/bookworm/multistrap

References:
- `./02_Rock5B_Make_Debian_Sysroot_From_Vendor_kernel/README/01_rootfs_sysroot_build_methods.md`
- `./02_Rock5B_Make_Debian_Sysroot_From_Vendor_kernel/README/00_kernel_sources_and_terminology.md`
- `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/scripts/04_fetch_sysroot_archive_from_board.sh`
- `./AGENTS_for_markdown.md`
- `./md_lists.md`