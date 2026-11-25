# $\color{#00c853}{\text{Step by step technical build instructions}}$

ဒီစာတမ်းက `./02_Rock5B_Make_Debian_Sysroot_From_Vendor_kernel/README/02_step_by_step_build.md` ဖြစ်ပါတယ်။ အစကနေ ပထမဆုံး လုပ်ရမယ့် အဆင့်တွေကို copy-paste လုပ်လို့ရတဲ့ command တွေနဲ့ ရေးထားတာဖြစ်တယ်။ Phase 0 ကနေ 6 အထိက host ပေါ်မှာပဲ ဖြစ်ပြီး board ကို မပြောင်းပါဘူး။ Phase 7 ကသာ board ပေါ်ကို kernel တင်ချင်မှ လုပ်ရမယ့် အဆင့်ဖြစ်တယ်။

## $\color{red}{\text{Phase 0 — ဘာတွေ တိတိကျကျ ဆုံးဖြတ်ရမလဲ}}$

မည်သည့် command မဆို မချခင် အောက်က တန်ဖိုးတွေကို ရေးချပါ။ နောက်မှာ repeat လုပ်လို့ရအောင် `data/checkpoints/inputs.txt` ထဲ သိမ်းပါ။

| တန်ဖိုး | ဘာဖြစ်ရမလဲ | မှတ်ချက် |
|---|---|---|
| `KERNEL_REPO` | `https://github.com/radxa/kernel.git` | Vendor BSP tree ဖြစ်တယ် [1][2] |
| `KERNEL_BRANCH` | `linux-6.1-stan-rkr5.1` | Radxa active stable branch ဖြစ်တယ် [2] |
| `KERNEL_COMMIT` | clone ပြီးရင် `git rev-parse HEAD` က ထွက်လာတဲ့ SHA | နောက်တစ်ခေါက် အတိအကျ ပြန်ရနိုင်ဖို့ လိုတယ် |
| `DEFCONFIG` | `rockchip_linux_defconfig` | Radxa kernel build မှာ သုံးတယ် [12] |
| `DTB` | `rockchip/rk3588-rock-5b.dtb` | Armbian board config ကလည်း ဒီ DTB ကို သတ်မှတ်တယ် [11] |
| `SUITE` | board glibc နဲ့ ကိုက်တဲ့ Debian suite | ရှိပြီးသား board က glibc 2.43 ဖြစ်တယ် |
| `BOOTLOADER_POLICY` | `keep` သို့မဟုတ် `replace` | ပထမအကြိမ်မှာ `keep` ကိုပဲ ရွေးပါ [13][14] |

```bash
REPO=/home/mr_robot/Desktop/Git/Rockstar
WORK="$REPO/02_Rock5B_Make_Debian_Sysroot_From_Vendor_kernel"
cd "$WORK"
mkdir -p data/kernels data/sysroot data/checkpoints

KERNEL_REPO=https://github.com/radxa/kernel.git
KERNEL_BRANCH=linux-6.1-stan-rkr5.1
DEFCONFIG=rockchip_linux_defconfig
DTB=rockchip/rk3588-rock-5b.dtb
SUITE=bookworm
BOOTLOADER_POLICY=keep

{
  echo "captured_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "KERNEL_REPO=$KERNEL_REPO"
  echo "KERNEL_BRANCH=$KERNEL_BRANCH"
  echo "DEFCONFIG=$DEFCONFIG"
  echo "DTB=$DTB"
  echo "SUITE=$SUITE"
  echo "BOOTLOADER_POLICY=$BOOTLOADER_POLICY"
} | tee data/checkpoints/inputs.txt
```

Suite ရွေးချယ်ရာမှာ build လုပ်တဲ့ glibc က board ရဲ့ glibc ထက် နိမ့် သို့မဟုတ် ညီရမယ်။ နိမ့်တဲ့ glibc နဲ့ ဆောက်ထားတဲ့ binary က အသစ်ကျတဲ့ board မှာ run လို့ရပေမယ့် အပြန်ကတော့ မရပါဘူး [44]။

## $\color{red}{\text{Phase 1 — host prerequisites}}$

Host က amd64 ဖြစ်နေရမယ်။ 2026-11-25 မှာ စစ်ထားတဲ့ အခြေအနေက amd64, disk 671 GB လွတ်, `aarch64-linux-gnu-gcc` ရှိပြီး `mmdebstrap`, `debootstrap`, `qemu-user` တွေ မရှိသေးဘူး။

```bash
sudo apt update
sudo apt install -y git make bc bison flex libssl-dev libncurses-dev \
  device-tree-compiler crossbuild-essential-arm64 \
  libc6-dev-arm64-cross libstdc++-11-dev-arm64-cross \
  mmdebstrap qemu-user qemu-user-binfmt binfmt-support \
  cmake ninja-build pkg-config
```

`crossbuild-essential-arm64` က cross gcc/g++ နဲ့ dpkg-cross ကို ဆွဲယူပေးတယ် [26][30]။
`libc6-dev-arm64-cross` နဲ့ `libstdc++-11-dev-arm64-cross` က headers နဲ့ static libs ပေးတယ် [31][32]။
`qemu-user` က foreign arm64 rootfs ထဲမှာ post-install script တွေ run ဖို့ လိုတယ် [27]။

```bash
dpkg --print-architecture
for c in aarch64-linux-gnu-gcc mmdebstrap qemu-aarch64-static cmake ninja; do
  printf '%-26s' "$c"; command -v "$c" || echo MISSING
done
df -h .
```

Expected output က architecture `amd64` ဖြစ်ပြီး အပေါ်က command အားလုံး path ပြရမယ်။ တစ်ခုခု `MISSING` ဖြစ်ရင် ဒီ Phase ကို ပြန်လုပ်ပါ။

## $\color{red}{\text{Phase 2 — vendor kernel ရယူပြီး commit ချိတ်ခြင်း}}$

```bash
KERNEL_DIR=data/kernels/radxa-kernel
git clone --depth 1 --branch "$KERNEL_BRANCH" "$KERNEL_REPO" "$KERNEL_DIR"
git -C "$KERNEL_DIR" rev-parse HEAD | tee data/checkpoints/kernel-commit.txt
```

Radxa ရဲ့ active branch တွေထဲမှာ 6.1 နဲ့ 6.12 နှစ်ခုလုံး ရှိပေမယ့် ရှိပြီးသား board image က 6.1.115 ဖြစ်တာကြောင့် 6.1 ကိုပဲ ဆက်ထားတာက အန္တရာယ်အနည်းဆုံးဖြစ်တယ် [2][17]။
အခြားရွေးချယ်စရာက Armbian `rk-6.1-rkr7.2` ဖြစ်ပြီး Armbian config မှာ `vendor` က ထို branch ကို သတ်မှတ်ထားတယ် [5][6]။
`radxa/kernel` ရဲ့ default `linux-7.0.11` ကိုတော့ ဒီ project အတွက် မသုံးပါနဲ့ [unverified]။

```bash
make -C "$KERNEL_DIR" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- "$DEFCONFIG"
make -C "$KERNEL_DIR" -j"$(nproc)" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
  Image dtbs modules
```

ဒီအဆင့်ပြီးရင် `$KERNEL_DIR/arch/arm64/boot/Image` နဲ့ `$KERNEL_DIR/arch/arm64/boot/dts/rockchip/rk3588-rock-5b.dtb` ရှိရမယ် [12]။ Module တွေကိုတော့ နောက် Phase မှာ rootfs ထဲ ထည့်ပါမယ်။

## $\color{red}{\text{Phase 3 — arm64 rootfs ဆောက်ခြင်း}}$

mmdebstrap က apt solver သုံးပြီး tar output ပေးနိုင်တာကြောင့် ဒီ project အတွက် အဆင်ပြေဆုံးဖြစ်တယ် [25]။

```bash
STAMP=$(date +%Y%m%d-%H%M%S)
ROOTFS_TAR="$PWD/data/sysroot/rock5b-${SUITE}-${STAMP}.tar"
ROOTFS_DIR="$PWD/data/sysroot/rootfs"

sudo mmdebstrap --architectures=arm64 --variant=buildd \
  --include=libc6-dev,libstdc++-11-dev,pkg-config,ca-certificates \
  "$SUITE" "$ROOTFS_TAR" http://deb.debian.org/debian

mkdir -p "$ROOTFS_DIR"
sudo tar -xpf "$ROOTFS_TAR" -C "$ROOTFS_DIR"
```

`--variant=buildd` က development packages အတွက် သင့်တော်တယ်။ merged-/usr က အများသုံး suite မှာ default ဖြစ်ပြီး mmdebstrap က တိတိကျကျ ကိုင်တွယ်တယ် [24][25]။

```bash
sudo chroot "$ROOTFS_DIR" /bin/sh -c 'cat /etc/os-release; ldd --version | head -1'
```

ဒီမှာ ထွက်လာတဲ့ glibc version က board ရဲ့ 2.43 ထက် မပိုရပါဘူး။ ပိုနေရင် SUITE ကို ပြောင်းပြီး ဒီ Phase ကို ပြန်လုပ်ပါ [44]။

## $\color{red}{\text{Phase 4 — vendor kernel headers နှင့် glue ဖိုင်တွေ ထည့်ခြင်း}}$

Distro ရဲ့ `linux-libc-dev` တစ်ခုတည်းကို အားကိုးမယ့်အစား ရွေးထားတဲ့ vendor kernel ရဲ့ UAPI headers ကို ထပ်တင်ပါ။ `headers_install` က userspace headers ကို သတ်မှတ်ထားတဲ့ path အောက်က `include/` ထဲ ထုတ်ပေးတယ် [28]။

```bash
sudo make -C "$KERNEL_DIR" ARCH=arm64 \
  INSTALL_HDR_PATH="$ROOTFS_DIR/usr" headers_install

sudo make -C "$KERNEL_DIR" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
  INSTALL_MOD_PATH="$ROOTFS_DIR" modules_install
sudo cp -a "$KERNEL_DIR/arch/arm64/boot/dts/rockchip/rk3588-rock-5b.dtb" \
  "$ROOTFS_DIR/boot/"
```

`headers_install` က userspace အတွက်သာ လုံလောက်ပါတယ်။ Out-of-tree kernel module ဆောက်ချင်ရင်တော့ configured full kernel build tree နဲ့ `Module.symvers` သီးခြား လိုအပ်ပါတယ် [28]။

Vendor `.deb` တွေ ရှိရင် အခု ထည့်ပါ။ `dpkg-deb -x` က extract သာလုပ်ပြီး install မလုပ်ဘူးဆိုတာ မမေ့ပါနဲ့ [35][36]။

```bash
for deb in /path/to/vendor/*.deb; do
  sudo dpkg-deb -x "$deb" "$ROOTFS_DIR"
done
```

pkg-config wrapper နဲ့ CMake toolchain file ထည့်ပါ။ `PKG_CONFIG_SYSROOT_DIR` နဲ့ `PKG_CONFIG_LIBDIR` က host library နေရာမှာ target `.pc` ဖိုင်တွေကို ရှာစေဖို့ ဖြစ်တယ် [33][34]။

```bash
mkdir -p "$PWD/data/sysroot/bin" "$PWD/data/sysroot/toolchains"
cat > "$PWD/data/sysroot/bin/rk3588-pkg-config" <<EOF
#!/usr/bin/env bash
export PKG_CONFIG_SYSROOT_DIR="$ROOTFS_DIR"
export PKG_CONFIG_LIBDIR="$ROOTFS_DIR/usr/lib/aarch64-linux-gnu/pkgconfig:$ROOTFS_DIR/usr/share/pkgconfig"
exec pkg-config "\$@"
EOF
chmod +x "$PWD/data/sysroot/bin/rk3588-pkg-config"

cat > "$PWD/data/sysroot/toolchains/rk3588.cmake" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_SYSROOT "$ROOTFS_DIR")
set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF
```

ဒီ toolchain variable တွေက canonical CMake cross-compile ပုံစံဖြစ်တယ် [29]။

## $\color{red}{\text{Phase 5 — sysroot archive ထုတ်ခြင်း}}$

ရှိပြီးသား `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/scripts/04_fetch_sysroot_archive_from_board.sh` က board ကနေ ဆွဲတဲ့ archive ကို `tar` + `.sha256` နဲ့ သိမ်းတဲ့ အလေ့အကျင့်ရှိတယ်။ ဒီဘက်မှာလည်း အဲဒီ format ကိုပဲ လိုက်ပါ။

```bash
ARCHIVE="$PWD/data/sysroot/rock5b-sysroot-${SUITE}-${STAMP}.tar"
(
  cd "$ROOTFS_DIR"
  tar --numeric-owner -cf "$ARCHIVE" \
    lib lib64 usr/lib usr/include usr/share/pkgconfig usr/local/lib usr/local/include 2>/dev/null || true
)
( cd "$PWD/data/sysroot" && sha256sum "${ARCHIVE##*/}" > "${ARCHIVE##*/}.sha256" )
tar -tf "$ARCHIVE" >/dev/null
```

Full rootfs ကိုတော့ `$ROOTFS_DIR` ထဲမှာပဲ ထားပါ။ Archive ထဲကို bootable image အတွက် လိုအပ်တဲ့ `/boot` တစ်ခုလုံး ထည့်စရာမလိုပါဘူး။

## $\color{red}{\text{Phase 6 — smoke build နှင့် ABI စစ်ဆေးခြင်း}}$

```bash
cat > /tmp/rk3588-smoke.cpp <<'EOF'
#include <cstdio>
int main() { std::puts("rock5b sysroot ok"); return 0; }
EOF

aarch64-linux-gnu-g++ --sysroot="$ROOTFS_DIR" /tmp/rk3588-smoke.cpp \
  -o "$PWD/data/checkpoints/rk3588-smoke"
file "$PWD/data/checkpoints/rk3588-smoke"
aarch64-linux-gnu-readelf -d "$PWD/data/checkpoints/rk3588-smoke" | grep NEEDED
aarch64-linux-gnu-readelf --version-info "$PWD/data/checkpoints/rk3588-smoke" \
  | grep -o 'GLIBC_[0-9.]*' | sort -Vu
```

`file` က `ELF ... ARM aarch64` ပြရမယ်။ GLIBC version တွေက rootfs ထဲက glibc ထက် မမြင့်ရပါဘူး [44]။

```bash
scp "$PWD/data/checkpoints/rk3588-smoke" root@192.168.1.15:/tmp/
ssh root@192.168.1.15 '/tmp/rk3588-smoke && ldd --version | head -1'
```

Board ပေါ်မှာ တကယ် run ပြီးမှ ABI ကို အတည်ပြုနိုင်ပါတယ်။

## $\color{red}{\text{Phase 7 — ရွေးချယ်စရာ — kernel ကို board ပေါ်တင်ခြင်း}}$

ဒီအဆင့်ကို မလုပ်ရင် board က အရင် kernel နဲ့ပဲ ရှိနေမယ်။ လုပ်မယ်ဆိုရင် အရင် `/boot` ထဲက ဖိုင်တွေကို backup လုပ်ပါ။

```bash
sudo cp "$KERNEL_DIR/arch/arm64/boot/Image" /boot/Image-rk61-vendor
sudo cp "$KERNEL_DIR/arch/arm64/boot/dts/rockchip/rk3588-rock-5b.dtb" /boot/
sudo cp -a "$ROOTFS_DIR/lib/modules/." /lib/modules/
sudo cp -a "$ROOTFS_DIR/lib/firmware/." /lib/firmware/
```

`extlinux.conf` ထဲမှာ `kernel`, `initrd`, `devicetreedir` တို့ ပါတဲ့ entry အသစ်ထည့်ပြီး `root=UUID=` ကို တကယ့် filesystem UUID နဲ့ တူအောင် ထားပါ [12]။ Armbian လည်း blkid နဲ့ UUID တွက်ပြီး အဲဒီပုံစံပဲ သုံးတယ် [21]။

U-Boot နဲ့ rkbin ကို မပြောင်းပါနဲ့။ ပြောင်းမယ်ဆိုရင် DDR TPL က closed blob ဖြစ်တာကြောင့် rkbin snapshot ကို တိတိကျကျ တွဲပြီး `idbloader.img` က LBA 64, `u-boot.itb` က LBA 16384 မှာ ရှိရမယ် [13][14][16]။

Rollback အတွက် အရင် `extlinux.conf` ကို ပြန်ရေးလိုက်ရင် အရင် kernel ပြန်တက်ပါမယ်။

## $\color{red}{\text{၈။ Checkpoint ဇယား}}$

| Phase | ပြီးဆုံးကြောင်း စစ်နည်း | ထွက်လာတဲ့ ဖိုင် |
|---|---|---|
| 0 | `inputs.txt` ဖတ်လို့ရတယ် | `data/checkpoints/inputs.txt` |
| 1 | `command -v` အားလုံး path ပြတယ် | — |
| 2 | `kernel-commit.txt` မှာ 40-character SHA ရှိတယ် | `data/kernels/radxa-kernel/`, `data/checkpoints/kernel-commit.txt` |
| 3 | `chroot` ထဲက glibc ≤ board glibc | `data/sysroot/rock5b-*.tar`, `data/sysroot/rootfs/` |
| 4 | `headers_install` ပြီး modules ရှိတယ် | `data/sysroot/toolchains/rk3588.cmake` |
| 5 | `tar -tf` အောင်မြင်ပြီး `.sha256` ရှိတယ် | `data/sysroot/rock5b-sysroot-*.tar(.sha256)` |
| 6 | aarch64 ELF ထွက်ပြီး board မှာ run မယ် | `data/checkpoints/rk3588-smoke` |
| 7 | `extlinux.conf` entry အသစ်ရှိတယ် | board `/boot/` |

Sources:
[1] https://github.com/rockchip-linux/kernel
[2] https://github.com/radxa/kernel/branches
[5] https://github.com/armbian/linux-rockchip/branches
[6] https://raw.githubusercontent.com/armbian/build/main/config/sources/families/include/rockchip_vendor_common.inc
[11] https://raw.githubusercontent.com/armbian/build/main/config/boards/rock-5b.conf
[12] https://wiki.radxa.com/Rock5/guide/build-kernel-on-5b
[13] https://docs.u-boot-project.org/en/latest/board/rockchip/rockchip.html
[14] https://gitlab.collabora.com/hardware-enablement/rockchip-3588/notes-for-rockchip-3588/-/blob/main/upstream_uboot.md
[16] https://github.com/radxa/rkbin
[17] https://docs.armbian.com/status/package-repository
[21] https://raw.githubusercontent.com/armbian/build/main/lib/functions/image/partitioning.sh
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
[44] https://sourceware.org/glibc/wiki/FAQ

References:
- `./02_Rock5B_Make_Debian_Sysroot_From_Vendor_kernel/README/02_step_by_step_build.md`
- `./02_Rock5B_Make_Debian_Sysroot_From_Vendor_kernel/README/00_kernel_sources_and_terminology.md`
- `./02_Rock5B_Make_Debian_Sysroot_From_Vendor_kernel/README/01_rootfs_sysroot_build_methods.md`
- `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/scripts/04_fetch_sysroot_archive_from_board.sh`
- `./AGENTS_for_markdown.md`
- `./md_lists.md`
