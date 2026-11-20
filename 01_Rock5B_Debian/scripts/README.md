# ROCK 5B host scripts

**Host PC မှ run ပါ။** Python မလိုပါ။ Board တွင် packages မတင်ပါ။

```bash
cd 01_Rock5B_Debian/scripts
./01_flash_sdcard.sh
./02_check_hardwares.sh
./03_check_base_dependencies.sh
```

| Script | လုပ်ဆောင်ချက် |
|---|---|
| `01` | `../vendor_images/*.img.xz` ရွေး၊ disk ရွေး၊ unmount/flash/sync လုပ် |
| `02` | SSH ချိတ်၊ hardware menu ရွေး၊ output သိမ်း |
| `03` | SSH ချိတ်၊ OS/packages/ABI/libs/headers/kernel inventory နှင့် `SDK_REQUIREMENTS.md` ထုတ် |

- **01:** Select the image and disk, confirm with `yes`, then flash and sync. No checksum or read-back verification.
- **02/03:** IP၊ user၊ port ထည့်ပါ။ Password လိုလျှင် SSH ကတောင်းသည်။ Host key fingerprint ကိုစစ်ပြီးမှ လက်ခံပါ။ Password ကို log မရေးပါ။
- **03:** Default user `root` ဖြစ်သည်။ Root SSH ပိတ်ထားလျှင် ပုံမှန် user သုံးပါ။ Permission မရှိသော checks က log တွင်ပေါ်မည်။
- **03:** `SDK_REQUIREMENTS.md` သည် board baseline, target package/version, host-only toolchain နှင့် app အလိုက် ထပ်စစ်ရမည့် vendor dependencies ကို သီးခြားဖော်ပြသည်။ SDK လမ်းညွှန်မစမီ အဲဒီဖိုင်ကိုဖတ်ပါ။ ၎င်းသည် အလိုအလျောက်ပြီးပြည့်စုံသော app dependency list မဟုတ်ပါ။
- **02:** `a` သည် inventory အားလုံး။ `15` သည် installed `stress-ng` ဖြင့် CPU load 60s စမ်းခြင်း။ Cooling ပြင်ထားပါ။ အခြား checks များသည် read-only inventory ဖြစ်သည်။
- Output: `check_results/<timestamp>-<host>.<id>/*.txt`။ Hardware detection တစ်ခုတည်းက PASS မဟုတ်ပါ။ Camera check သည် `v4l2-ctl` မရှိလျှင်လည်း `/dev/video*` နှင့် sysfs အမည်/path ကို စာရင်းပြုစုသည်။ NPU check သည် debugfs load/version နှင့် kernel messages ကို ဖတ်ရန်ကြိုးစားသည်။ SSH user တွင် permission မရှိပါက `sudo -n` ရနိုင်မှသာ ဖတ်မည်၊ မရလျှင် log ထဲရှိ `sudo` command ကို board ပေါ်တွင် manual စမ်းပါ။ NPU inference အတွက် compatible native demo ထပ်လိုသည်။
- SDK inventory သည် sysroot backup မဟုတ်ပါ။ [Archive သုံးပြီး sysroot ပြင်နည်း](../README/04_create_cross_compiler_using_sysroot_archive.md) သို့မဟုတ် [archive မပါဘဲ package မှ sysroot ပြင်နည်း](../README/05_create_cross_compiler_without_sysroot_archive.md) ကိုရွေးပါ။

Host တွင် Bash၊ OpenSSH၊ coreutils၊ util-linux၊ xz လိုသည်။ Flash အတွက်သာ sudo လိုသည်။ Scripts က package install၊ driver ပြောင်းခြင်း၊ GPIO မောင်းခြင်း မလုပ်ပါ။ SSH login logs နှင့် host `known_hosts` ကတော့ ပုံမှန် update ဖြစ်နိုင်သည်။

စမ်းသပ်မှု: `bash tests/test_scripts.sh` — fake SSH/disk metadata သာသုံးပြီး SD card မရေးပါ၊ board မချိတ်ပါ။
