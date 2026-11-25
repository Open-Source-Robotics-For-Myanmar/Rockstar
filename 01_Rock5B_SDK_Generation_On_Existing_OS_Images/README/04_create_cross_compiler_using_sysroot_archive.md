# $\color{#00c853}{\text{Board sysroot archive သုံးခြင်း — အားသာချက် / အားနည်းချက်}}$

## $\color{red}{\text{အားသာချက်}}$

- Board OS မှ library နှင့် loader များကို တိုက်ရိုက်ရရှိသဖြင့် target userspace ABI နှင့် ကိုက်ညီရန် ပိုလွယ်သည်။
- Board တွင် development packages ပါလျှင် သက်ဆိုင်ရာ headers၊ linker files နှင့် package metadata ကိုပါ ရနိုင်သည်။
- Archive ထဲထည့်ထားသော vendor/manual libraries များကိုလည်း ရနိုင်သည်။
- Package တစ်ခုချင်းရှာဖွေစုဆောင်းရမှု လျော့နည်းပြီး board ၏ လက်ရှိအခြေအနေကို snapshot အဖြစ် ထိန်းသိမ်းနိုင်သည်။
- တူညီသော OS/runtime ရှိသည့် device များအတွက် sysroot ကို ပြန်သုံးနိုင်သည်။

## $\color{red}{\text{အားနည်းချက်}}$

- Board သို့မဟုတ် ၎င်း၏ filesystem archive ကို အရင်ရရှိထားရန် လိုသည်။
- Runtime-only filesystem တွင် C/C++ development headers နှင့် linker files မစုံနိုင်ပါ။
- ကူးယူထားသော directory အတိုင်းအတာပြင်ပရှိ vendor files မပါနိုင်ပါ။
- Absolute symlinks၊ linker scripts နှင့် pkg-config paths များသည် host တွင် မမှန်နိုင်သဖြင့် ပြင်ဆင်ရနိုင်သည်။
- Archive က cross-compiler ကို မပေးပါ။ Compiler၊ libc နှင့် C++ runtime တို့၏ compatibility ကို သီးခြားစစ်ရသည်။
- Userspace sysroot ရှိခြင်းက kernel modules အတွက် matching kernel build tree ရရှိခြင်း မဟုတ်ပါ။
- Board package update ဖြစ်လျှင် snapshot ဟောင်းနေနိုင်ပြီး ပြန်ကူးယူရသည်။ Board ၏ မလိုအပ်သောဖိုင်၊ configuration သို့မဟုတ် credentials ပါလာနိုင်သည်။

References:
- `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/README/04_create_cross_compiler_using_sysroot_archive.md`
- `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/README/00_HOW_TO_BUILD_LINUX_SDK.md`
- `./md_lists.md`

