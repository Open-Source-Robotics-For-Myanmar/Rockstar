# $\color{#00c853}{\text{Board archive မသုံးဘဲ packages မှ sysroot ဖန်တီးခြင်း — အားသာချက် / အားနည်းချက်}}$

## $\color{red}{\text{အားသာချက်}}$

- Physical board၊ SSH သို့မဟုတ် board filesystem copy မလိုဘဲ host ပေါ်တွင် ပြင်ဆင်နိုင်သည်။
- Target distro/release နှင့် ARM64 packages ကို သတ်မှတ်၍ ထိန်းချုပ်နိုင်သည်။
- လိုအပ်သော runtime နှင့် development packages များသာ ထည့်နိုင်သဖြင့် sysroot အရွယ်အစား လျော့နိုင်သည်။
- Package versions၊ checksums နှင့် repository snapshot ကို မှတ်တမ်းထားလျှင် environment ပြန်ဖန်တီးရန် ပိုလွယ်သည်။
- Isolated download/extraction နည်းသုံးလျှင် target packages များကို host system ထဲ install လုပ်ရန်မလိုပါ။

## $\color{red}{\text{အားနည်းချက်}}$

- CPU architecture သာသိခြင်း မလုံလောက်ပါ။ Target OS/release၊ libc၊ C++ ABI နှင့် dependency versions ကိုပါ သတ်မှတ်ရသည်။
- Dependency resolution၊ repository signing keys နှင့် version consistency ကို ကိုယ်တိုင်စီမံရသည်။
- Package extraction ပြီးသည့် filesystem တွင် post-install scripts မ run ထားသဖြင့် လိုအပ်သော generated files မစုံနိုင်ပါ။
- Absolute symlinks၊ linker scripts၊ multiarch layout နှင့် pkg-config paths ကို ပြန်စစ်ရနိုင်သည်။
- Vendor/NPU/GPU libraries နှင့် manually installed files များကို distro repository တစ်ခုတည်းမှ မရနိုင်ပါ။
- Cross-compiler နှင့် target libc/C++ development packages ကိုက်ညီမှုသည် သီးခြားတာဝန်ဖြစ်သည်။
- Package versions ဟောင်းများ repository မှ ပျောက်သွားလျှင် snapshot သို့မဟုတ် သိမ်းထားသော packages မရှိဘဲ အတိအကျပြန်ဖန်တီးရန် ခက်နိုင်သည်။

References:
- `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/README/05_create_cross_compiler_without_sysroot_archive.md`
- `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/README/00_HOW_TO_BUILD_LINUX_SDK.md`
- `./md_lists.md`

