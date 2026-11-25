# ROCK 5B host scripts

**Host PC မှ run ပါ။ 01–05 အတွက် Python မလိုပါ။ 06 က Python Tkinter GUI ဖြစ်ပါတယ်။ Board တွင် packages မတင်ပါ။**

```bash
cd 01_Rock5B_SDK_Generation_On_Existing_OS_Images/scripts
./01_flash_sdcard.sh
./02_check_hardwares.sh
./03_check_base_dependencies.sh
./04_fetch_sysroot_archive_from_board.sh
./05_create_RK3588_SDK_env_without_sysroot.sh
# 06 က Python GUI — venv ထဲကနေ run ပါ (အောက်မှာ command ရှိပါတယ်)
```

| Script | လုပ်ဆောင်ချက် |
|---|---|
| `01` | `../vendor_images/*.img.xz` ရွေး၊ disk ရွေး၊ unmount/flash/sync လုပ် |
| `02` | SSH ချိတ်၊ hardware menu ရွေး၊ output သိမ်း |
| `03` | SSH ချိတ်၊ OS/packages/ABI/libs/headers/kernel inventory နှင့် `SDK_REQUIREMENTS.md` ထုတ် |
| `04` | `04_fetch_sysroot_archive_from_board.sh` ဖြင့် SSH ချိတ်၊ board မှ runtime libraries/headers ကို tar ဖြင့် host ရှိ `../data/fetch_sysroot_archive_from_board/` ထဲယူ |
| `05` | Host ပေါ်တွင် manual target baseline inputs ဖြင့် no-sysroot ARM64 workspace/toolchain configuration ဖန်တီး |
| `06` | Python Tkinter GUI ဖြင့် `05` နဲ့ အတူတူ no-sysroot workspace ဖန်တီး — field အလိုက် help, review, `yes` confirmation ပါ |

- **01:** Select the image and disk, confirm with `yes`, then flash and sync. No checksum or read-back verification.
- **02/03:** IP၊ user၊ port ထည့်ပါ။ Password လိုလျှင် SSH ကတောင်းသည်။ Host key fingerprint ကိုစစ်ပြီးမှ လက်ခံပါ။ Password ကို log မရေးပါ။
- **04:** IP၊ SSH user၊ port ကို prompt မှာထည့်ပါ။ Board ပေါ်တွင် Python သို့မဟုတ် package installation မလိုပါ။ Archive သည် `data/fetch_sysroot_archive_from_board/` ထဲတွင် `.tar` နှင့် `.sha256` အဖြစ်သိမ်းသည်။
- **03:** Default user `root` ဖြစ်သည်။ Root SSH ပိတ်ထားလျှင် ပုံမှန် user သုံးပါ။ Permission မရှိသော checks က log တွင်ပေါ်မည်။
- **03:** `SDK_REQUIREMENTS.md` သည် board baseline, target package/version, host-only toolchain နှင့် app အလိုက် ထပ်စစ်ရမည့် vendor dependencies ကို သီးခြားဖော်ပြသည်။ SDK လမ်းညွှန်မစမီ အဲဒီဖိုင်ကိုဖတ်ပါ။ ၎င်းသည် အလိုအလျောက်ပြီးပြည့်စုံသော app dependency list မဟုတ်ပါ။
- **05:** `--help` ကိုကြည့်ပြီး host မှ run ပါ။ Board နှင့် SSH မချိတ်ပါ၊ package install/update မလုပ်ပါ၊ target sysroot မတည်ဆောက်ပါ။ Script က board ပေါ်တွင် run ရမည့် read-only commands ကိုပြပြီး ရလဒ်များကို လူကိုယ်တိုင်ထည့်စေသည်။ `SDK_ROOT` ဖြင့် destination ရွေးနိုင်ပြီး ရှိပြီးသား path ကို မထပ်ရေးပါ။ AArch64 cross C/C++ compiler, CMake, Ninja, pkg-config နှင့် readelf ကို host မှ ကြိုတင်ပြင်ဆင်ထားရမည်။ RKNN/libdatachannel ကဲ့သို့ third-party libraries ကို ဒီအဆင့်တွင် မထည့်ပါ။
- **05:** `--non-interactive` အသုံးပြုလျှင် target metadata, SDK_ROOT နှင့် `CONFIRM_CREATE=yes` အပါအဝင် လိုအပ်သော environment variables အားလုံးကို သတ်မှတ်ပါ။ ပြီးလျှင် [SDK environment guide](../README/07_create_RK3588_SDK_env_on_ubuntu2204.md) နှင့် [smoke-test guide](../README/08_build_smoke_test_project.md) ကိုလိုက်ပါ။
- **06:** Python Tkinter GUI ဖြစ်ပါတယ်။ `05` နဲ့ အပြုအမူအတူတူ — board metadata ၉ ခုကို လူကိုယ်တိုင်ထည့်စေပြီး host cross-toolchain ကို စစ်ဆေးကာ no-sysroot ARM64 workspace ဖန်တီးသည်။ SSH မချိတ်ပါ၊ package install/download/build မလုပ်ပါ၊ ရှိပြီးသား SDK path ကို မထိပါ။
- **06:** field တစ်ခုချင်းစီရဲ့ **Help** ခလုတ်က board ပေါ်မှာ run ရမယ့် read-only command တွေနဲ့ ဘာလို့လိုအပ်တယ်ဆိုတာ ပြသည်။ Review မှာ ဖွဲ့စည်းပုံအားလုံးကို ပြပြီး `yes` ရိုက်မှသာ ဖိုင်တွေ ရေးသည်။ `--help` နဲ့ CLI help လည်း ရနိုင်သည်။ GUI က ဖွင့်တာနဲ့ full-screen maximize ဖြစ်ပြီး help/dialog တွေက main window ရဲ့ တစ်ဝက်အရွယ်နဲ့ ပွင့်ပါတယ်။
- **06:** `python_gui_rules.md` အတိုင်း font ကို `Roboto` လို့ အမြဲ configure လုပ်ပါတယ်။ `scripts/fonts/Roboto-*.ttf` ကို fontconfig ထဲ ထည့်ပေးပေမယ့် **no-Xft Tk** build မှာ Tk က TTF family ကို မမြင်လို့ core font နဲ့ အစားထိုးဖြစ်နေတယ်။ Roboto ကို မြင်လိုရင် Xft-enabled Tk လိုအပ်ပါတယ်။
- **06:** ထွက်လာတဲ့ ဖိုင်/ဖိုလ်ဒါတွေက `05` နဲ့ အတိအကျ အတူတူပါ (`env.sh`, `bin/rk3588-pkg-config`, `toolchains/rk3588.cmake`, `metadata/*`, `models/`)။ နောက်တစ်ဆင့်အတွက် [SDK environment guide](../README/07_create_RK3588_SDK_env_on_ubuntu2204.md) နဲ့ [smoke-test guide](../README/08_build_smoke_test_project.md) ကို လိုက်ပါ။
- **02:** `a` သည် inventory အားလုံး။ `15` သည် installed `stress-ng` ဖြင့် CPU load 60s စမ်းခြင်း။ Cooling ပြင်ထားပါ။ အခြား checks များသည် read-only inventory ဖြစ်သည်။
- Output: `../data/check_results_to_build_sdk_from_board/<timestamp>-<host>.<id>/` ထဲတွင် `.txt` inventory logs နှင့် `SDK_REQUIREMENTS.md` ရှိသည်။ Hardware detection တစ်ခုတည်းက PASS မဟုတ်ပါ။ Camera check သည် `v4l2-ctl` မရှိလျှင်လည်း `/dev/video*` နှင့် sysfs အမည်/path ကို စာရင်းပြုစုသည်။ NPU check သည် debugfs load/version နှင့် kernel messages ကို ဖတ်ရန်ကြိုးစားသည်။ SSH user တွင် permission မရှိပါက `sudo -n` ရနိုင်မှသာ ဖတ်မည်၊ မရလျှင် log ထဲရှိ `sudo` command ကို board ပေါ်တွင် manual စမ်းပါ။ NPU inference အတွက် compatible native demo ထပ်လိုသည်။
- SDK inventory သည် sysroot backup မဟုတ်ပါ။ [Archive သုံးပြီး sysroot ပြင်နည်း](../README/04_create_cross_compiler_using_sysroot_archive.md) သို့မဟုတ် [archive မပါဘဲ package မှ sysroot ပြင်နည်း](../README/05_create_cross_compiler_without_sysroot_archive.md) ကိုရွေးပါ။

Host တွင် Bash၊ OpenSSH၊ coreutils၊ util-linux၊ xz လိုသည်။ `06` အတွက် Python 3 နှင့် tkinter (`python3-tk`) လည်း လိုသည်။ Flash အတွက်သာ sudo လိုသည်။ Scripts က package install၊ driver ပြောင်းခြင်း၊ GPIO မောင်းခြင်း မလုပ်ပါ။ SSH login logs နှင့် host `known_hosts` ကတော့ ပုံမှန် update ဖြစ်နိုင်သည်။

စမ်းသပ်မှု: `bash tests/test_scripts.sh` — fake SSH/disk metadata သာသုံးပြီး SD card မရေးပါ၊ board မချိတ်ပါ။

`06` အတွက် ပထမဆုံး setup ကို တစ်ကြိမ်လုပ်ပါ:

```bash
sudo apt install python3-tk python3-venv
cd 01_Rock5B_SDK_Generation_On_Existing_OS_Images/scripts
/usr/bin/python3 -m venv .venv
touch .venv/.gitkeep
.venv/bin/python -m pip install -r requirements.txt
```

ပြီးရင် repo root ကနေ GUI ကို ခေါ်ပါ:

```bash
./01_Rock5B_SDK_Generation_On_Existing_OS_Images/automation
```

`automation` မှာ path variable နဲ့ command နှစ်ကြောင်းပဲ ပါပါတယ်: `.venv` ကို activate လုပ်ပြီး `.venv/bin/python` နဲ့ `06_create_RK3588_SDK_env_without_sysroot.py` ကို run ပါတယ်။ ဘယ် directory ကနေခေါ်ခေါ် script ရှိတဲ့နေရာက path ကို သုံးပါတယ်။

လက်ရှိ `requirements.txt` မှာ third-party package မလိုသေးပါ။ Tkinter ကို system ရဲ့ `python3-tk` package ကနေ သုံးပါတယ်။ Roboto Regular/Bold က `scripts/fonts/` ထဲမှာ ပါပြီးသားပါ။

References:
- `01_Rock5B_SDK_Generation_On_Existing_OS_Images/automation`
- `01_Rock5B_SDK_Generation_On_Existing_OS_Images/scripts/06_create_RK3588_SDK_env_without_sysroot.py`
- `01_Rock5B_SDK_Generation_On_Existing_OS_Images/scripts/requirements.txt`
- `01_Rock5B_SDK_Generation_On_Existing_OS_Images/scripts/05_create_RK3588_SDK_env_without_sysroot.sh`
- `python_gui_rules.md`
- [SDK environment guide](../README/07_create_RK3588_SDK_env_on_ubuntu2204.md)
- [smoke-test guide](../README/08_build_smoke_test_project.md)
