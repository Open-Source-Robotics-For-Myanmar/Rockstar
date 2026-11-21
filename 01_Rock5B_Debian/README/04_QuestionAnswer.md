# $\color{#00c853}{\text{ROCK 5B Cross-Compile SDK — မေးခွန်းနှင့်အဖြေများ}}$

ဤစာတမ်းတွင် ROCK 5B hardware စစ်ဆေးမှု၊ `03_check_base_dependencies.sh` ရလဒ်နှင့် cross-compile SDK/sysroot ဆိုင်ရာ မေးခွန်းများကို စုစည်းထားသည်။

> **မှတ်ချက်:** အရောင်မပြသော Markdown renderer များတွင်လည်း မေးခွန်း/အဖြေကို စာသားအညွှန်းဖြင့် ခွဲသိနိုင်သည်။

## $\color{red}{\text{၁။ NPU နှင့် USB Webcam စစ်ဆေးမှု}}$

<p><span style="color: red"><strong>မေးခွန်း:</strong> `02_check_hardwares.sh` ရလဒ်နဲ့ ကိုယ်တိုင်စစ်ထားတဲ့ NPU၊ USB Webcam အခြေအနေက ဘယ်လိုလဲ။</span></p>

<p><span style="color: blue"><strong>အဖြေ:</strong> Script က hardware inventory ကို စုဆောင်းတာဖြစ်ပြီး functional PASS အဖြစ် မသတ်မှတ်ပါ။ Manual output မှာ RKNPU driver က DRM အဖြစ် initialize ဖြစ်ပြီး debugfs load မှာ Core0 42% ပြခဲ့ပါတယ်။ `can't request region` နဲ့ `failed to initialize power model` စာများကိုလည်း တွေ့ရတဲ့အတွက် NPU inference ကို compatible RKNN demo နဲ့ စမ်းပြီး၊ inference အောင်မြင်မှုနဲ့ kernel error များကို ထပ်စစ်သင့်ပါတယ်။ USB Webcam အတွက် `/dev/video1`, `/dev/video2` နဲ့ `/dev/media0` ကို တွေ့ရှိပြီး device enumeration အဆင်ပြေပါတယ်။ ဒါပေမဲ့ video capture/stream ကို အဲဒီ output တစ်ခုတည်းနဲ့ အတည်မပြုနိုင်သေးပါ။</span></p>

## $\color{red}{\text{၂။ Hardware စစ်ဆေးမှု script ပြင်ဆင်ခြင်း}}$

<p><span style="color: red"><strong>မေးခွန်း:</strong> ဒီ NPU နဲ့ USB Cam manual စစ်ဆေးမှုတွေကို `02_check_hardwares.sh` ထဲ ထည့်မွမ်းမံပေးနိုင်မလား။</span></p>

<p><span style="color: blue"><strong>အဖြေ:</strong> Script ကို ပြင်ဆင်ထားပါတယ်။ Camera စစ်ဆေးမှုမှာ `v4l2-ctl` မရှိလျှင်လည်း `/dev/video*`, sysfs device name/path နဲ့ `/dev/media*` ကို စာရင်းပြုစုပါတယ်။ NPU စစ်ဆေးမှုမှာ debugfs `version/load`, devfreq အချက်အလက်နဲ့ RKNPU ဆိုင်ရာ kernel messages ကို ဖတ်ဖို့ကြိုးစားပါတယ်။ လက်ရှိ user အခွင့်အရေးမလုံလောက်လျှင် password မတောင်းတဲ့ `sudo -n` ကိုသာ စမ်းပြီး၊ မရပါက ဘာကြောင့် မဖတ်နိုင်ကြောင်း log ထဲမှာ ပြပါတယ်။ Script သည် debugfs ကို mount မလုပ်သလို NPU inference သို့မဟုတ် camera capture ကို အလိုအလျောက် မစမ်းပါ။ Bash syntax နဲ့ regression test အောင်မြင်ခဲ့ပြီး board ပေါ်မှာ ပြန် run စမ်းသပ်ထားခြင်းတော့ မဟုတ်ပါ။</span></p>

## $\color{red}{\text{၃။ Base dependency inventory နှင့် SDK အတွက် လိုအပ်ချက်များ}}$

<p><span style="color: red"><strong>မေးခွန်း:</strong> `03_check_base_dependencies.sh` ရလဒ်ကို ကြည့်ပြီး ဒီ board အတွက် cross-compile SDK ထုတ်ဖို့ ဘာတွေလိုသေးလဲ။</span></p>

<p><span style="color: blue"><strong>အဖြေ:</strong> ရလဒ်အရ board သည် ROCK 5B၊ Armbian/Ubuntu 26.04 `arm64` ဖြစ်ပြီး kernel `6.1.115-vendor-rk35xx`, glibc `2.43-2ubuntu2.3` နှင့် AArch64 loader ရှိပါတယ်။ `libstdc++6` နဲ့ `libgcc-s1` ရှိပေမဲ့ target ပေါ်မှာ C/C++ development headers မရှိသလို build toolchain ကိုလည်း မတွေ့ပါ။ Cross compiler, CMake/Ninja ကဲ့သို့ build tools ကို board ပေါ်တင်ရန်မဟုတ်ဘဲ host ပေါ်မှာ ပြင်ဆင်ရပါမယ်။</span></p>

<p><span style="color: blue"><strong>ဆက်လက်လိုအပ်သည်များ:</strong> (၁) target ABI နဲ့ကိုက်ညီတဲ့ sysroot (၂) board ၏ glibc version နှင့်တူသော `libc6-dev:arm64` နှင့် လိုအပ်သည့် အခြား target development packages (၃) host ပေါ်ရှိ AArch64 cross-toolchain (၄) app သုံးမည့် vendor libraries/headers (ဥပမာ RKNN, RGA, MPP) တို့ဖြစ်ပါတယ်။ NPU driver `v0.9.8` နဲ့ RKNPU debugfs ကို inventory မှာ တွေ့ရပေမဲ့ သုံးမည့် RKNN user-space runtime, headers နဲ့ model/toolkit version ကို လိုက်ဖက်မှုစစ်ရန်လိုပါတယ်။ `linux-libc-dev` သည် userspace kernel API headers ဖြစ်ပြီး kernel module build headers မဟုတ်ပါ။ Kernel module တည်ဆောက်မှသာ လက်ရှိ vendor kernel နဲ့ကိုက်ညီတဲ့ kernel source/build headers ကို သီးခြားရယူပါ။</span></p>

## $\color{red}{\text{၄။ Sysroot archive မပါဘဲ cross-compile လုပ်ခြင်း}}$

<p><span style="color: red"><strong>မေးခွန်း:</strong> Sysroot archive မယူဘဲနဲ့ cross-compile လုပ်လို့ရသလား။</span></p>

<p><span style="color: blue"><strong>အဖြေ:</strong> ရပါတယ်။ `target-libs.tar` ကို မယူလည်း cross-compile လုပ်နိုင်ပါတယ်။ ဒါပေမဲ့ cross-compiler အတွက် target architecture ၏ headers, libraries နဲ့ loader metadata ပါဝင်တဲ့ sysroot တစ်ခုတော့ လိုပါတယ်။ Archive သည် လက်ရှိ board ရှိဖိုင်များကို sysroot အဖြစ်ရယူတဲ့ နည်းလမ်းတစ်ခုသာဖြစ်ပြီး မဖြစ်မနေလိုအပ်တာ မဟုတ်ပါ။</span></p>

<p><span style="color: blue"><strong>အစားထိုးနည်း:</strong> Host ပေါ်တွင် board ၏ distro/release နှင့် version ကိုက်ညီသော ARM64 development packages များကို သီးခြား sysroot ထဲ download/unpack လုပ်နိုင်ပါတယ်။ Simple C/C++ app အတွက် minimal sysroot နဲ့စလို့ရပေမဲ့ app လိုအပ်သည့် vendor headers/libraries ကို သီးခြားဖြည့်ရပါမယ်။ လက်ရှိ board အတွက် `libc6-dev:arm64` ကို target `libc6` version အတိအကျနှင့်ကိုက်အောင်ရွေးပါ။</span></p>

## $\color{red}{\text{၅။ Archive မယူခြင်း၏ အန္တရာယ်များ}}$

<p><span style="color: red"><strong>မေးခွန်း:</strong> Sysroot archive မယူရင် ဘာတွေဖြစ်လာနိုင်လဲ။</span></p>

<p><span style="color: blue"><strong>အဖြေ:</strong> Archive မရှိတာကိုယ်တိုင်က ပြဿနာမဟုတ်ပါ။ အစားထိုး sysroot မပြင်ဆင်ထားခြင်းက ပြဿနာဖြစ်နိုင်ပါတယ်။ Header/library မတွေ့လို့ build မအောင်နိုင်ခြင်း၊ host ၏ x86_64 library ကို မှားသုံးမိလို့ target ပေါ်မ run နိုင်ခြင်း၊ glibc/libstdc++ ABI မကိုက်လို့ `GLIBC_*` သို့မဟုတ် `GLIBCXX_* not found` ဖြစ်ခြင်းနှင့် RKNN/RGA/MPP လို vendor dependency မပါလို့ build သို့မဟုတ် runtime မှာ feature မအောင်မြင်ခြင်းတို့ ဖြစ်နိုင်ပါတယ်။ `dlopen()` plugin များကို compile/link အဆင့်က မဖမ်းမိနိုင်သောကြောင့် အသုံးပြုမည့် feature တစ်ခုချင်းစီကို board ပေါ်မှာ စမ်းသပ်ပါ။</span></p>

## $\color{red}{\text{၆။ Yocto/Buildroot နှင့် အခြားသူများအသုံးပြုသည့်နည်းလမ်း}}$

<p><span style="color: red"><strong>မေးခွန်း:</strong> ပုံမှန်အားဖြင့် အစားထိုး sysroot ကို Yocto, Buildroot တို့ကနေ တည်ဆောက်ကြတာလား။ တခြားသူတွေ ဘယ်လိုလုပ်ကြသလဲ။</span></p>

<p><span style="color: blue"><strong>အဖြေ:</strong> Target OS ကို Yocto ဖြင့်တည်ဆောက်ထားလျှင် `populate_sdk` က compiler, sysroot နဲ့ setup script ပါဝင်တဲ့ SDK ထုတ်ပေးနိုင်ပါတယ်။ Buildroot ဖြင့် image တည်ဆောက်ထားလျှင် ၎င်း၏ output toolchain/sysroot ကို အသုံးပြုကြပါတယ်။ ဒီနည်းတွေက image နဲ့ SDK ကို project တစ်ခုတည်းက ထုတ်ပေးနိုင်တာကြောင့် version ကိုက်ညီအောင် ထိန်းရလွယ်ပါတယ်။</span></p>

<p><span style="color: blue"><strong>အခြားနည်းများ:</strong> Debian/Ubuntu လို package-based target များအတွက် host မှ cross-compiler သုံးပြီး target release နဲ့ version ကိုက်တဲ့ `-dev` packages များမှ sysroot ပြင်ဆင်ခြင်း၊ သို့မဟုတ် ရှိပြီးသား board filesystem မှ libraries ကိုကူးပြီး development packages ဖြည့်ခြင်းတို့ကိုလည်း အသုံးပြုကြပါတယ်။ Container/chroot က host build environment ကို သီးခြားထားပေးတာဖြစ်ပြီး target sysroot ကို အလိုအလျောက် မပေးပါ။</span></p>

<p><span style="color: blue"><strong>ဒီ ROCK 5B အတွက်:</strong> လက်ရှိ Armbian/Ubuntu 26.04 image ကို ဆက်သုံးမယ်ဆိုရင် Yocto/Buildroot နဲ့ image ကို ပြန်တည်ဆောက်ရန်မလိုဘဲ package-based sysroot ကို host ပေါ်မှာ ပြင်ဆင်တာက သဘာဝကျပါတယ်။ Vendor runtime ကို Ubuntu repository မှာ မရနိုင်လျှင် board/app နဲ့ကိုက်ညီပြီး အသုံးပြုခွင့်သတ်မှတ်ချက်များကို လိုက်နာနိုင်သော vendor/upstream ရင်းမြစ်မှ သီးခြားရယူပါ။ Yocto သို့မဟုတ် Buildroot သို့ ပြောင်းသုံးခြင်းက board OS ကို အဲဒီ build system နဲ့ ကိုယ်တိုင်တည်ဆောက်မယ့်အခါ ပိုသင့်တော်ပါတယ်။</span></p>

## $\color{red}{\text{၇။ Sysroot archive ထဲတွင် ပါဝင်မည့်အရာများ}}$

<p><span style="color: red"><strong>မေးခွန်း:</strong> Sysroot archive ယူလိုက်ရင် အထဲမှာ ဘာတွေပါလာမလဲ။</span></p>

<p><span style="color: blue"><strong>အဖြေ:</strong> လမ်းညွှန်ထဲက tar command အတိုင်းယူလျှင် board ရဲ့ `/lib`, `/lib64`, `/usr/lib`, `/usr/include`, `/usr/share/pkgconfig`, `/usr/local/lib` နဲ့ `/usr/local/include` directory များထဲမှာ ရှိပြီးသားဖိုင်များ ပါလာပါမယ်။ အဓိကအားဖြင့် ARM64 runtime shared libraries (`.so`), ရှိပါက static libraries (`.a`), symbolic links, C/C++ headers နဲ့ `pkg-config` metadata (`.pc`) တို့ဖြစ်ပါတယ်။ `/usr/lib` ထဲတွင်တပ်ဆင်ထားတဲ့ vendor libraries တွေလည်း ပါနိုင်ပါတယ်။</span></p>

<p><span style="color: blue"><strong>သတိပြုရန်:</strong> ဒီ archive က board မှာရှိပြီးသားဖိုင်တွေကိုသာ ကူးတာဖြစ်ပြီး မရှိသေးတဲ့ development headers ကို အလိုအလျောက် ဖန်တီးပေးတာမဟုတ်ပါ။ သင့် inventory မှာ `libc6-dev` မတပ်ထားတဲ့အတွက် C library development headers မပြည့်စုံနိုင်ပါ။ Cross compiler, CMake/Ninja လို host build tools၊ package repository/cache နဲ့ kernel module တည်ဆောက်ရန် vendor kernel source/build headers တို့လည်း ဒီ archive ရဲ့ ရည်ရွယ်ထားတဲ့အကြောင်းအရာ မဟုတ်ပါ။ `/opt` အောက်ကဖိုင်များကိုလည်း လမ်းညွှန်ထဲက tar command က မထည့်ပါ။ လိုအပ်တဲ့ဖိုင်တွေကို သီးခြားစစ်ပြီး ရယူပါ။</span></p>

<p><span style="color: blue"><strong>အကြံပြုချက်:</strong> Archive ရလာလျှင် `tar -tf` နဲ့ အတွင်းဖိုင်စာရင်းကိုကြည့်ပြီး sysroot ထဲ extract လုပ်ပါ။ ထို့နောက် board နဲ့ကိုက်ညီတဲ့ `-dev` packages နဲ့ app သုံးမယ့် vendor headers/libraries ကို ဖြည့်ပါ။ ဒီနည်းက runtime libraries ရဲ့ symlinks နဲ့ ABI ကို board မှတိုက်ရိုက်ရနိုင်ပေမဲ့ archive တစ်ခုတည်းကို complete SDK လို့ မယူဆသင့်ပါ။</span></p>

## $\color{red}{\text{၈။ libc6-dev ထည့်ခြင်းဖြင့် Sysroot ပိုပြည့်စုံလာမလား}}$

<p><span style="color: red"><strong>မေးခွန်း:</strong> `libc6-dev` ကို apt နဲ့ ထည့်လိုက်ရင် sysroot မှာ ဘာတွေ ထပ်ရလာနိုင်လဲ၊ ပိုပြည့်စုံသွားနိုင်မလား။</span></p>

<p><span style="color: blue"><strong>အဖြေ:</strong> `libc6-dev` ကို target sysroot ထဲထည့်ရင် glibc development အပိုင်း ပိုပြည့်စုံလာပါမယ်။ ပုံမှန်အားဖြင့် `stdio.h` ကဲ့သို့ C headers၊ startup object files (`crt*.o`)၊ linker အတွက် development files နဲ့ link လုပ်ရာမှာလိုအပ်တဲ့ symlink များ ပါဝင်ပါတယ်။ ဒါတွေက C program ကို compile/link လုပ်ရာမှာ အရေးကြီးပါတယ်။</span></p>

<p><span style="color: blue"><strong>ကန့်သတ်ချက်:</strong> ဒီ package တစ်ခုတည်းနဲ့ sysroot တစ်ခုလုံး ပြည့်စုံမသွားပါ။ C++ headers/runtime ကို cross-toolchain သို့မဟုတ် သက်ဆိုင်ရာ target development package က ပေးရပြီး၊ app သုံးမယ့် OpenSSL၊ RKNN၊ RGA စတဲ့ library တစ်ခုချင်းစီအတွက် သက်ဆိုင်ရာ `-dev` package သို့မဟုတ် vendor headers/libraries ကို ထပ်ထည့်ဖို့လိုနိုင်ပါတယ်။ Kernel module တည်ဆောက်ရန်လိုတဲ့ kernel headers ကလည်း သီးခြားဖြစ်ပါတယ်။</span></p>

<p><span style="color: blue"><strong>ဒီ board အတွက်:</strong> Board ရဲ့ `libc6` version က `2.43-2ubuntu2.3` ဖြစ်တဲ့အတွက် အဲဒီ version နဲ့တိတိကျကျကိုက်ညီတဲ့ `libc6-dev:arm64` ကို host ပေါ်ရှိ သီးခြား sysroot ထဲ download/unpack လုပ်တာက ပိုသင့်တော်ပါတယ်။ Board ပေါ်မှာ `apt install` လုပ်ရင် board ကိုယ်တိုင်ပြောင်းလဲသွားမယ်။ Board ကို မပြောင်းလဲဘဲထားလိုပါက package ကို host ပေါ်တွင် download လုပ်ပြီး sysroot ထဲမှာ unpack လုပ်ပါ။ ထည့်ပြီးနောက် cross-build လုပ်ကာ board ပေါ်မှာ စမ်းသပ်အတည်ပြုပါ။</span></p>

## $\color{red}{\text{၉။ libc6-dev ကို Board သို့မဟုတ် Host မှာ ထည့်သင့်သလား}}$

<p><span style="color: red"><strong>မေးခွန်း:</strong> Board ကို development/compilation အတွက်မသုံးဘဲ runtime libraries အတွက်သာသုံးမယ်ဆိုရင် `libc6-dev` ကို board ပေါ်တင်တာက မလိုအပ်ဘဲ storage ယူမလား။ amd64 host ပေါ်မှာ SDK/sysroot ဆောက်ပြီး cross-compile လုပ်တာ ပိုကောင်းသလား။</span></p>

<p><span style="color: blue"><strong>အဖြေ:</strong> ဟုတ်ပါတယ်။ Board ကို runtime အတွက်သာထားပြီး build ကို amd64 host ပေါ်မှာ cross-compile လုပ်မယ်ဆိုရင် `libc6-dev` ကို board ပေါ်မှာ install လုပ်စရာမလိုပါ။ အဲဒီလို install လုပ်ခြင်းက development files တွေအတွက် board ရဲ့ storage ကို သုံးစေမှာဖြစ်ပြီး target system ကိုလည်း ပြောင်းလဲစေပါတယ်။</span></p>

<p><span style="color: blue"><strong>လုပ်ဆောင်ရန်:</strong> amd64 host ပေါ်မှာ ARM64 cross-toolchain ကိုသုံးပြီး သီးခြား sysroot ပြင်ဆင်ပါ။ Board နဲ့ကိုက်ညီတဲ့ ARM64 `libc6-dev` package ကို host မှာ download လုပ်ပြီး sysroot ထဲ unpack လုပ်ပါ။ **Host ရဲ့ amd64 `libc6-dev` ကို target sysroot ထဲ မသုံးပါနှင့်။** ဒီ package ရဲ့ headers နဲ့ link အတွက်လိုတဲ့ development files တွေက build အချိန်မှာသာ အသုံးပြုပြီး app နှင့်အတူ board ဆီကူးပို့စရာမလိုပါ။ Board မှာ ရှိပြီးသား runtime libraries နဲ့ app က လိုအပ်တဲ့ runtime dependencies တွေကိုသာ အသုံးပြု/ပို့ဆောင်ပါ။</span></p>

<p><span style="color: blue"><strong>ဒီ board အတွက်:</strong> target `libc6` version သည် `2.43-2ubuntu2.3` ဖြစ်သောကြောင့် ထို version နှင့်ကိုက်ညီသည့် ARM64 development package ကို sysroot ထဲထည့်ပါ။ Build ပြီးနောက် binary ကို board ပေါ်စမ်းပြီး လိုအပ်သော runtime library နဲ့ ABI များကိုက်ညီကြောင်း စစ်ဆေးပါ။</span></p>

## $\color{red}{\text{၁၀။ Inventory အချက်အလက်များဖြင့် Archive မပါဘဲ SDK ဆောက်ခြင်း}}$

<p><span style="color: red"><strong>မေးခွန်း:</strong> Sysroot archive မယူဘဲ `03_check_base_dependencies.sh` မှရတဲ့ version အသေးစိတ်ကိုသာ အခြေခံပြီး ကိုယ်တိုင် SDK ဆောက်လို့ရသလား။</span></p>

<p><span style="color: blue"><strong>အဖြေ:</strong> ရပါတယ်။ Inventory ထဲက distro/release, architecture, glibc, runtime package နဲ့ kernel version အချက်အလက်တွေကို အခြေခံပြီး amd64 host ပေါ်မှာ SDK/sysroot ကို ကိုယ်တိုင်ပြင်ဆင်နိုင်ပါတယ်။ ဒါပေမဲ့ version အချက်အလက်တွေက sysroot ကိုယ်တိုင် မဟုတ်ပါ။ သက်ဆိုင်ရာ ARM64 `.deb` development/runtime packages တွေနဲ့ app လိုအပ်တဲ့ vendor libraries/headers ကို ရယူပြီး host ပေါ်ရှိ သီးခြား sysroot ထဲမှာ unpack လုပ်ရပါမယ်။</span></p>

<p><span style="color: blue"><strong>လိုက်နာရန်:</strong> Target `libc6` version `2.43-2ubuntu2.3` နဲ့ကိုက်ညီတဲ့ ARM64 `libc6-dev` ကိုရွေးပါ၊ host amd64 package ကို target sysroot ထဲ မထည့်ပါနှင့်။ App က RKNN/RGA/MPP သို့မဟုတ် အခြား vendor library သုံးပါက target driver/runtime နဲ့ ကိုက်ညီသော runtime, headers, libraries နဲ့ version များကို သီးခြားရယူပြီး စစ်ဆေးပါ။ Kernel module တည်ဆောက်ရန်လိုမှသာ လက်ရှိ vendor kernel နဲ့ကိုက်ညီတဲ့ kernel source/build headers ကို သီးခြားရယူပါ။</span></p>

<p><span style="color: blue"><strong>အတည်ပြုရန်:</strong> Cross-compile ပြီး binary ရဲ့ ARM64 architecture နဲ့ လိုအပ်တဲ့ GLIBC/GLIBCXX ABI များကိုစစ်ပါ။ ထို့နောက် board ပေါ်မှာ တကယ် run စမ်းပြီး dynamic/plugin dependencies အပါအဝင် app လိုအပ်တဲ့ feature များ အလုပ်လုပ်ကြောင်း အတည်ပြုပါ။</span></p>

## $\color{red}{\text{ဆက်စပ်လမ်းညွှန်များ}}$

- [၀၃ — Base OS အချက်အလက် စစ်ခြင်း](03_check_base_dependencies.md)
- [၀၄ — Sysroot archive သုံးပြီး SDK ပြင်ဆင်ခြင်း](04_create_cross_compiler_using_sysroot_archive.md)
- [၀၅ — Sysroot archive မပါဘဲ SDK ပြင်ဆင်ခြင်း](05_create_cross_compiler_without_sysroot_archive.md)
- [၀၆ — Sample C++ ကို SCP ဖြင့် deploy](06_deploy_sample_cpp.md)

References:
- `./01_Rock5B_Debian/README/04_QuestionAnswer.md`
- `./01_Rock5B_Debian/README/00_HOW_TO_BUILD_LINUX_SDK.md`
- `./md_lists.md`
