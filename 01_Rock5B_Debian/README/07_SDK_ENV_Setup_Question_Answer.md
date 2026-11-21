# ROCK 5B / RK3588 SDK Environment Setup — မေးခွန်းနှင့်အဖြေများ

ဤစာတမ်းတွင် `07_create_RK3588_SDK_env_on_ubuntu2204.md` လမ်းညွှန်အတိုင်း တည်ဆောက်သော host-side SDK environment ဆိုင်ရာ မေးခွန်းများနှင့် အဖြေများကို စုစည်းထားသည်။

## ၁။ SDK workspace ၏ သဘောသဘာဝ

<p><span style="color: red"><strong>မေးခွန်း:</strong> အခုလို `RK3588_SDK_on_Ubuntu2204` folder က standard SDK environment folder တစ်ခုပဲလား၊ ကိုယ့်ဘာသာ ထင်ရာမြင်ရာလုပ်ထားတာလား။</span></p>

<p><span style="color: blue"><strong>အဖြေ:</strong> `RK3588_SDK_on_Ubuntu2204` ဆိုတဲ့ folder name နဲ့ path ကို ဒီ project အတွက် ကိုယ်တိုင်ရွေးထားတာဖြစ်ပြီး Ubuntu, GCC သို့မဟုတ် Rockchip က သတ်မှတ်ပေးထားတဲ့ official/standard SDK directory မဟုတ်ပါ။ ဒါပေမဲ့ ဖိုင်တွေကို စိတ်ကူးသလို အလွတ်သဘော စုပုံထားတာလည်း မဟုတ်ပါ။ `bin`, `toolchains`, `src`, `build`, `prefix`, `metadata`, `models` စတဲ့ folder များကို ဒီလမ်းညွှန်ရဲ့ ရည်ရွယ်ချက်အလိုက် ခွဲထားတဲ့ project-specific workspace layout ဖြစ်ပါတယ်။</span></p>

<p><span style="color: blue"><strong>အသုံးပြုထားသည့် standard အစိတ်အပိုင်းများ:</strong> Cross compiler (`aarch64-linux-gnu-g++`), CMake toolchain file, `pkg-config` နှင့် ARM64 ELF format တို့က ပုံမှန်အသုံးပြုသည့် tool/convention များဖြစ်ပါတယ်။ Compiler ကို host Ubuntu မှာ install လုပ်ပြီး `/usr/bin` ကနေသုံးတာဖြစ်ပြီး `RK3588_SDK_on_Ubuntu2204` ထဲမှာ compiler အပြည့်အစုံထည့်ထားတာ မဟုတ်ပါ။</span></p>

<p><span style="color: blue"><strong>သိထားရန်:</strong> ဒီ SDK setup က target board အတွက် full sysroot တစ်ခုကို မတည်ဆောက်ထားပါ။ `CMAKE_SYSROOT` ကို မသတ်မှတ်ဘဲ Ubuntu cross compiler ရဲ့ built-in target headers/libraries ကို အခြေခံထားပြီး `prefix` ထဲတွင် RKNN ကဲ့သို့ app သီးသန့် vendor library များကို ထည့်နိုင်အောင် ပြင်ထားတာပါ။ ထို့ကြောင့် “standard SDK folder” ထက် “standard cross-compilation tools ကို အသုံးပြုထားသော project-specific SDK workspace” ဟု နားလည်တာ ပိုမှန်ပါတယ်။</span></p>

## ၂။ ကိုယ့် C++ project ကို SDK workspace ထဲက build လုပ်ခြင်း

<p><span style="color: red"><strong>မေးခွန်း:</strong> အခု C++ project တစ်ခုကို စပြီး build တော့မယ်ဆိုရင် project ကို `src/` folder ထဲ link ထိုးပြီး build လုပ်လို့ရမလား။</span></p>

<p><span style="color: blue"><strong>အဖြေ:</strong> ရပါတယ်။ Project source ကို မရွှေ့ဘဲ SDK ရဲ့ `src/` အောက်မှာ symlink လုပ်ထားနိုင်ပါတယ်။ ဥပမာ project ရဲ့ CMakeLists.txt က `$HOME/Projects/my-cpp-app` ထဲမှာရှိပြီး SDK path က `$HOME/Desktop/Git/Rockstar/01_Rock5B_Debian/RK3588_SDK_on_Ubuntu2204` ဖြစ်တယ်ဆိုရင်—</span></p>

<pre><code>export RK3588_SDK="$HOME/Desktop/Git/Rockstar/01_Rock5B_Debian/RK3588_SDK_on_Ubuntu2204"
export PROJECT_SRC="$HOME/Projects/my-cpp-app"
test -f "$PROJECT_SRC/CMakeLists.txt"
ln -s "$PROJECT_SRC" "$RK3588_SDK/src/my-cpp-app"

cmake -S "$RK3588_SDK/src/my-cpp-app" \
  -B "$RK3588_SDK/build/my-cpp-app" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$RK3588_SDK/toolchains/rk3588.cmake" \
  -DCMAKE_BUILD_TYPE=Release
cmake --build "$RK3588_SDK/build/my-cpp-app" --parallel "$(nproc)"</code></pre>

<p><span style="color: blue"><strong>သတိပြုရန်:</strong> `src/my-cpp-app` သည် source ကိုညွှန်တဲ့ link သာဖြစ်ပြီး build output ကို သိမ်းတဲ့နေရာမဟုတ်ပါ။ Build files နှင့် output များကို `build/my-cpp-app` ထဲထားခြင်းဖြင့် project source tree ကို မရှုပ်စေပါ။ `src/my-cpp-app` ရှိပြီးသားဆို `ln -s` ကို ထပ်မလုပ်ပါနှင့်။ Project တွင် CMake မသုံးပါက build command ကို project ရဲ့ build system အလိုက်ပြောင်းသော်လည်း cross compiler/toolchain ကို အတိအကျသုံးပါ။</span></p>

## ၃။ Internet မရှိသော board သို့ application deploy လုပ်ခြင်း

<p><span style="color: red"><strong>မေးခွန်း:</strong> Board ရဲ့ OS ပဲရှိပြီး dependency တွေကို update/install မလုပ်နိုင်ပါ။ Offline ဖြစ်တဲ့အတွက် project binary နဲ့ runtime dependencies တွေကိုပါ ထည့်ပေးရမယ်ဆိုရင် deployment တစ်ခုမှာ ဘာတွေပါရမလဲ။</span></p>

<p><span style="color: blue"><strong>အဖြေ:</strong> Board မှာ `apt` သုံးစရာမလိုအောင် host ပေါ်မှာ application ကို build လုပ်ပြီး လိုအပ်တဲ့ application-specific runtime ဖိုင်တွေကို package ထဲထည့်ကူးရပါမယ်။ အခြေခံအားဖြင့် အောက်ပါပစ္စည်းတွေကို စာရင်းပြုစုပြီး deploy လုပ်ပါ—</span></p>

<ul>
<li><strong>Executable များ:</strong> ကိုယ့် app ရဲ့ ARM64 binary နဲ့ app က သုံးတဲ့ helper executable များ။</li>
<li><strong>Private runtime libraries:</strong> Board OS မှာ မရှိတဲ့၊ ကိုယ့် app သို့မဟုတ် vendor SDK ကလိုတဲ့ ARM64 `.so` များနှင့် ၎င်းတို့ရဲ့ ထပ်ဆင့် library dependencies များ။ ဥပမာ NPU သုံးလျှင် လိုက်ဖက်သော `librknnrt.so` ဖြစ်သည်။ SONAME symlink ရှိလျှင် အဲဒီ symlink ကိုပါ ထည့်ပါ။</li>
<li><strong>Data နှင့် configuration:</strong> Model (`.rknn` အပါအဝင်), config, vocabulary, assets, plugin များ၊ app က runtime မှဖတ်သည့် data များ။ License/certificate လိုအပ်ချက်ရှိလျှင်လည်း ထည့်သွင်းစီမံပါ။</li>
<li><strong>Deployment အထောက်အထား:</strong> Dependency/version မှတ်တမ်း၊ build/release identifier၊ package checksum (`sha256sum`) နှင့် install/run လုပ်ပုံ။ Update လုပ်ရာတွင် ဘာ version တင်ထားသည်ကို ပြန်စစ်နိုင်စေသည်။</li>
</ul>

<p><span style="color: blue"><strong>ဥပမာ package ပုံစံ:</strong></span></p>

<pre><code>my_app/
  bin/my_app
  lib/libprivate_dependency.so
  lib/librknnrt.so       # NPU app အတွက်လိုအပ်လျှင်
  models/model.rknn      # model သုံးလျှင်
  config/app.conf
  share/...              # app အတွက်လိုအပ်သော အခြား data</code></pre>

<p><span style="color: blue"><strong>OS-оос ирэх ёстой зүйл:</strong> Linux dynamic loader (`ld-linux-aarch64.so.1`), `libc.so.6`, `libstdc++.so.6` зэрэг үндсэн system runtime များကို ပုံမှန်အားဖြင့် board OS က ပေးရပါမယ်။ Build လုပ်ထားတဲ့ binary/library ရဲ့ `GLIBC_*` နှင့် `GLIBCXX_*` လိုအပ်ချက်တွေကို board OS မဖြည့်နိုင်ပါက `apt` မရှိခြင်းကြောင့် executable မ run နိုင်ပါ။ Host မှ target ABI နဲ့ကိုက်ညီအောင်ပြန် build လုပ်ပါ၊ သို့မဟုတ် သီးသန့် sysroot ဖြင့် build လုပ်ပါ။ `glibc`, dynamic loader သို့မဟုတ် OS ရဲ့ system libraries ကို `/opt` ထဲကူးပြီး အစားထိုးသုံးတာက လုံခြုံတဲ့နည်းမဟုတ်ပါ။</span></p>

<p><span style="color: blue"><strong>Hardware runtime နဲ့ driver:</strong> RKNN user-space runtime (`librknnrt.so`) ကို app folder ရဲ့ `lib/` ထဲထည့်နိုင်သော်လည်း kernel driver၊ device node၊ permissions၊ firmware သို့မဟုတ် kernel module ကို app package က အစားမထိုးနိုင်ပါ။ NPU/RGA/MPP လုပ်ဆောင်ချက်သုံးမယ်ဆို OS image ထဲမှာ လိုအပ်တဲ့ driver/device access အရင်ရှိပြီး runtime နဲ့ version ကိုက်ညီကြောင်း စမ်းသပ်ရပါမယ်။ မရှိရင် application package တစ်ခုတည်းနဲ့ offline board မှာ feature အလုပ်မလုပ်နိုင်ပါ။</span></p>

<p><span style="color: blue"><strong>စစ်ဆေးပုံ:</strong> Host ပေါ်မှာ `aarch64-linux-gnu-readelf -d` ဖြင့် binary နဲ့ private library များ၏ `NEEDED`/`RUNPATH` ကိုကြည့်ပြီး private library များကို app-relative path (ဥပမာ `$ORIGIN/../lib`) ကနေရှာနိုင်အောင်ထားပါ။ Board ပေါ်မှာ install လုပ်ပြီးမှ `ldd` ဖြင့် `not found` မရှိကြောင်းစစ်ကာ feature တစ်ခုချင်း run စမ်းပါ။ `dlopen()` ဖြင့်နောက်မှဖွင့်သည့် plugin dependency များကို `ldd` တစ်ခုတည်းက မဖော်ပြနိုင်ပါ။ App ကို root အဖြစ်မ run ပါနှင့်။ `/opt/rockstar/<app>/` ကဲ့သို့ သီးသန့် directory ထဲ install လုပ်ပြီး deployment တစ်ခုစီကို သီးခြားထားပါ။</span></p>

<p><span style="color: blue"><strong>မထည့်ရန်:</strong> C/C++ source, CMake build directory, compiler, development headers (`*.h`) နဲ့ `.a` static development libraries တွေကို app runtime မှာ မလိုအပ်လျှင် deploy package ထဲ မထည့်ပါ။ အဓိကက app ကို clean board ပေါ်မှာ offline run စမ်းပြီး အမှန်တကယ်လိုအပ်တဲ့ runtime, data နဲ့ OS/hardware prerequisites အားလုံးကို သီးခြားအတည်ပြုရန်ဖြစ်ပါတယ်။</span></p>

## ၄။ Project လိုအပ်သော C++ version ရွေးချယ်ခြင်း

<p><span style="color: red"><strong>မေးခွန်း:</strong> ငါ့ project က C++ version ကွဲတယ်ဆိုရင် ဘယ်လိုလုပ်မလဲ။</span></p>

<p><span style="color: blue"><strong>အဖြေ:</strong> Project သို့မဟုတ် dependency က လိုအပ်တဲ့ C++ standard ကို CMake build configuration မှာ ရွေးပါ။ လက်ရှိ Ubuntu 22.04 cross compiler သည် GCC 11.4.0 ဖြစ်သောကြောင့် အသုံးများတဲ့ C++17 ကို သုံးနိုင်ပြီး C++20 ကိုလည်း compiler ပံ့ပိုးသည့်အတိုင်း build လုပ်နိုင်ပါတယ်။ သို့သော် language standard တစ်ခုကို ရွေးနိုင်ခြင်းက အဲဒီ standard ရဲ့ feature အားလုံးကို compiler က ပြည့်စုံစွာပံ့ပိုးတယ်လို့ မဆိုလိုပါ။ Project လိုအပ်သည့် feature များကို compile/test လုပ်ပြီးအတည်ပြုပါ။</span></p>

<p><span style="color: blue"><strong>CMake ဥပမာ:</strong> `CMakeLists.txt` တွင် project လိုအပ်သော version ကို သတ်မှတ်ပါ။ ဥပမာ C++20 လိုအပ်ပါက—</span></p>

<pre><code>set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)</code></pre>

<p><span style="color: blue">Project target တစ်ခုတည်းအတွက် သတ်မှတ်လိုပါက `target_compile_features(my_app PRIVATE cxx_std_20)` ကိုသုံးနိုင်ပါတယ်။ C++17 လိုအပ်ရင် `20`/`cxx_std_20` ကို `17`/`cxx_std_17` အဖြစ်ပြောင်းပါ။ အခြား build system များတွင်လည်း project ရဲ့ compiler setting ကို အသုံးပြုပြီး cross compiler `aarch64-linux-gnu-g++` ဖြင့် build လုပ်ပါ။</span></p>

<p><span style="color: blue"><strong>အရေးကြီးသော ကွာခြားချက်:</strong> C++ standard သည် source code ဘာသာစကား feature များကို ရွေးတာဖြစ်ပြီး target board ပေါ်ရှိ `libstdc++.so.6` ကို အစားထိုးရွေးတာ မဟုတ်ပါ။ Build ပြီးနောက် binary ရဲ့ `GLIBCXX_*` လိုအပ်ချက်များနှင့် target ပေးနိုင်သော version ကို `aarch64-linux-gnu-readelf --version-info` ဖြင့်နှိုင်းယှဉ်ပြီး board ပေါ်မှာ `ldd`/run test လုပ်ပါ။ GCC 11 cross compiler ၏ C++ headers နဲ့ မတူညီသော compiler ၏ target libraries ကို ရောမသုံးပါနှင့်။ Compiler feature သို့မဟုတ် dependency က GCC 11 ထက်သစ်သော compiler လိုအပ်လျှင် host toolchain ကို သင့်လျော်စွာပြောင်းပြီး compatible sysroot/runtime ဖြင့် ပြန်တည်ဆောက်ရပါမယ်။</span></p>

## ၅။ C++ cross-compilation အတွက် GUI tools

<p><span style="color: red"><strong>မေးခွန်း:</strong> ဒီလိုမျိုး C++ SDK ကို အလွယ်တကူတည်ဆောက်လို့ရအောင် လုပ်ပေးထားတဲ့ GUI tools တွေရှိသလား။</span></p>

<p><span style="color: blue"><strong>အဖြေ:</strong> ရှိပါတယ်။ ဒါပေမဲ့ IDE/GUI တွေက ပုံမှန်အားဖြင့် ရှိပြီးသား compiler, CMake toolchain, SDK/sysroot ကို configure လုပ်ပြီး project ကို build လုပ်ရလွယ်အောင်ပေးတာဖြစ်ပါတယ်။ လက်ရှိ board OS အတွက် မှန်ကန်တဲ့ sysroot, runtime libraries, RKNN driver/runtime version တို့ကို အလိုအလျောက်ရှာပြီး အပြည့်အစုံတည်ဆောက်ပေးတယ်လို့ မယူဆသင့်ပါ။</span></p>

<ul>
<li><strong>VS Code + CMake Tools:</strong> လက်ရှိ CMake project အတွက် အလွယ်ဆုံးစတင်နိုင်တဲ့ရွေးချယ်မှုပါ။ `CMakePresets.json` ထဲမှာ cross toolchain (`toolchains/rk3588.cmake`), build directory, build type နဲ့ install/deploy settings ကိုသိမ်းထားပြီး VS Code မှာ configure/build လုပ်နိုင်ပါတယ်။ Compiler ကို host ပေါ်က `aarch64-linux-gnu-g++` သုံးစေပြီး board ပေါ် build မလုပ်ပါ။</li>
<li><strong>Qt Creator:</strong> CMake project များအတွက် cross compiler, debugger နဲ့ kit ကို GUI မှာသတ်မှတ်နိုင်ပါတယ်။ Custom kit ကိုတစ်ကြိမ် configure လုပ်ရပြီး target sysroot/dependencies ကိုတော့ ကိုယ်တိုင်ပြင်ဆင်ထားရပါမယ်။</li>
<li><strong>CLion:</strong> CMake cross-compilation profile/toolchain ကို configure လုပ်နိုင်ပါတယ်။ IDE license/edition အခြေအနေကို စစ်ပြီး compiler, toolchain file နဲ့ deployment setting ကို project အလိုက်သတ်မှတ်ပါ။</li>
</ul>

<p><span style="color: blue"><strong>ဒီ SDK အတွက် အကြံပြုချက်:</strong> Ubuntu 22.04 host ပေါ်မှာ VS Code နဲ့ CMake Tools ကိုသုံးပြီး လက်ရှိ 07 မှာဖန်တီးထားတဲ့ `rk3588.cmake` ကို project configure မှာချိတ်ပါ။ Project တစ်ခုစီရဲ့ C++ standard ကို `CMakeLists.txt` သို့မဟုတ် preset ထဲသတ်မှတ်ပြီး build output ကို သီးခြား `build/<project>` directory ထဲထားပါ။ Board deploy က သီးခြားအဆင့်ဖြစ်ပြီး 08 smoke-test လမ်းညွှန်အတိုင်း package/runtime စစ်ဆေးမှုကို ဆက်လုပ်ပါ။</span></p>

<p><span style="color: blue"><strong>သတိပြုရန်:</strong> GUI တစ်ခုတည်းနဲ့ target ရဲ့ ABI/runtime mismatch၊ မရှိတဲ့ RKNN/RGA/MPP library၊ board driver သို့မဟုတ် offline deployment လိုအပ်ချက်တွေကို ဖြေရှင်းမပေးနိုင်ပါ။ IDE နဲ့ build အောင်မြင်တာတစ်ခုတည်းက board ပေါ်မှာ run မယ်လို့ အာမမခံပါ။</span></p>