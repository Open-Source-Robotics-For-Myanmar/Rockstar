# ၀၅ — Sample C++ ကို SCP ဖြင့် deploy

[၀၄ archive နည်း](04_create_cross_compiler_using_sysroot_archive.md) သို့မဟုတ် [၀၅ archive မပါသောနည်း](05_create_cross_compiler_without_sysroot_archive.md) တစ်ခုဖြင့် SDK ပြင်ပြီးမှ run ပါ။ **Host မှ build၊ board မှ run** မည်။ Board တွင် apt မသုံးပါ။ နမူနာက executable + private shared library ကို စမ်းသည်။

## ၁။ Host မှ sample ဖန်တီးရန်

```bash
export SDK="$HOME/rock5b-sdk"
export TARGET=mr_robot@rock-5b
mkdir -p "$SDK/src/sample"
cat > "$SDK/src/sample/greeting.cpp" <<'CPP'
extern "C" const char* greeting() { return "Hello ROCK 5B"; }
CPP
cat > "$SDK/src/sample/main.cpp" <<'CPP'
#include <iostream>
extern "C" const char* greeting();
int main() { std::cout << greeting() << '\n'; }
CPP
cat > "$SDK/src/sample/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.20)
project(sample LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_library(greeting SHARED greeting.cpp)
set_target_properties(greeting PROPERTIES
  VERSION 1.0 SOVERSION 1 INSTALL_RPATH "$ORIGIN")
add_executable(hello main.cpp)
target_link_libraries(hello PRIVATE greeting)
set_target_properties(hello PROPERTIES INSTALL_RPATH "$ORIGIN/../lib")
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH FALSE)
install(TARGETS hello greeting RUNTIME DESTINATION bin LIBRARY DESTINATION lib)
CMAKE
cmake -S "$SDK/src/sample" -B "$SDK/build/sample" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$SDK/toolchain-arm64.cmake" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/my_project
cmake --build "$SDK/build/sample" --verbose
DESTDIR="$SDK/stage" cmake --install "$SDK/build/sample"
```

## ၂။ Binary နှင့် libraries စစ်ရန်

```bash
APP="$SDK/stage/opt/my_project"
file "$APP/bin/hello" "$APP/lib/libgreeting.so.1.0"
aarch64-linux-gnu-readelf -l "$APP/bin/hello" | grep interpreter
aarch64-linux-gnu-readelf -d "$APP/bin/hello" | grep -E 'NEEDED|RUNPATH'
aarch64-linux-gnu-readelf -d "$APP/lib/libgreeting.so.1.0" | grep -E 'NEEDED|RUNPATH'
aarch64-linux-gnu-readelf --version-info "$APP/bin/hello"
```

**မျှော်မှန်းချက်:** ARM aarch64၊ loader `/lib/ld-linux-aarch64.so.1`၊ app RUNPATH `$ORIGIN/../lib`၊ library RUNPATH `$ORIGIN`။ လိုအပ်သော `GLIBC_*` / `GLIBCXX_*` versions ကို target က ပေးနိုင်ရမည်။ Host `ldd` ဖြင့် ARM binary ကိုမစစ်ပါနှင့်။

## ၃။ SCP ဖြင့်ကူးရန်

`.so` symlinks မပျောက်စေရန် tar ထုပ်ပြီး SCP ဖြင့်ပို့မည်။ Sample runtime ဖိုင်များသာယူသည်။

```bash
PACKAGE_DIR=$(mktemp -d "$SDK/package.XXXXXX")
mkdir -p "$PACKAGE_DIR/my_project/bin" "$PACKAGE_DIR/my_project/lib"
cp -a "$APP/bin/hello" "$PACKAGE_DIR/my_project/bin/"
cp -a "$APP"/lib/libgreeting.so* "$PACKAGE_DIR/my_project/lib/"
tar -czf "$SDK/my_project.tar.gz" -C "$PACKAGE_DIR" my_project
(cd "$SDK" && sha256sum my_project.tar.gz > my_project.tar.gz.sha256)
ssh "$TARGET" 'mkdir -p "$HOME/my_project-upload"'
scp "$SDK/my_project.tar.gz" "$SDK/my_project.tar.gz.sha256" \
  "$TARGET:my_project-upload/"
```

Board တွင် login ဝင်ပြီး run ပါ။ `/opt` သို့ရေးရန်သာ sudo လိုသည်။ အဟောင်းရှိလျှင် app ကိုအရင်ရပ်ပြီး backup ယူပါ။

```bash
cd "$HOME/my_project-upload"
sha256sum -c my_project.tar.gz.sha256
# OK ဖြစ်မှ ဆက်လုပ်ရန်။
if [ -d /opt/my_project ]; then
    sudo mv /opt/my_project "/opt/my_project.backup-$(date +%Y%m%d-%H%M%S)"
fi
sudo mkdir -p /opt/my_project
sudo tar --no-same-owner -xzf my_project.tar.gz -C /opt/my_project --strip-components=1
# မိမိ build လုပ်ထားသော binary ကိုသာ စစ်ရန်။
ldd /opt/my_project/bin/hello
ldd /opt/my_project/lib/libgreeting.so.1
/opt/my_project/bin/hello
```

**PASS:** `not found` / version error မရှိ၊ `libgreeting.so.1` က `/opt/my_project/lib/` မှ load ဖြစ်ပြီး `Hello ROCK 5B` ထွက်ရမည်။ App ကို root ဖြင့် run ရန်မလိုပါ။

## ကိုယ့် app အတွက် ထပ်လုပ်ရန်

- Dependency `.so` အားလုံးနှင့် ၎င်းတို့၏ dependencies၊ plugins/models/data ကို package ထဲထည့်ပါ။
- Base မှယူသုံးသော libraries နှင့် private libraries စာရင်း/version ကိုမှတ်ပါ။
- `dlopen()` plugins များကို `ldd` တစ်ခုတည်းမဖမ်းနိုင်၍ feature တစ်ခုစီ run စစ်ပါ။
- Library မတွေ့လျှင် host package ကိုပြင်ပြီး ပြန်ကူးပါ။ Board မှာ apt တင်ခြင်း၊ `/usr/lib` ထဲကူးခြင်း မလုပ်ပါနှင့်။
- ဒီ sample အောင်ခြင်းက NPU/GPU app တစ်ခုလုံး အောင်ကြောင်းမဟုတ်ပါ။ ကိုယ့် app ၏ hardware paths ကိုသီးခြားစမ်းပါ။
