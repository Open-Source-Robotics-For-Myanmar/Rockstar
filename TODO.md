

ထဲမှာ ubuntu 22.04 မှာ cross-compilation sdk ဆောက်ပြီး 
simple cpp cli app တစ်ခု build ကြည့်ပြီးသွားမယ်။

deploy လုပ်မယ့် 01_Rock5B_SDK_Generation_On_Existing_OS_Images/README/06_deploy_sample_cpp.md ကိုဆက် update လုပ်မယ်။


05_create_RK3588_SDK_env_without_sysroot.sh

ကို script ရေးပေးပါ။ 

အပေါ်မှာပြင်ရမယ့် အပိုင်းတွေကို environment variables _ std input များများသုံးပေးပါ။

နောင်တစ်ချိန် OS အပြောင်းအလဲရှိတဲ့အခါ ကျရင် processor တူပေမယ့် dependencies version တွေပြောင်းလဲနိုင်တဲ့အတွက် အာ့လိုပြောင်းလဲနိုင်တဲ့ အပိုင်းတွေကို ငါက 03_check_base_dependencies.sh သုံးပြီး သွားစစ်ဆေး၊ ရလာတဲ့အချက်အလက်တွေကို အခုလို environment variables _ std input တွေထည့်ထားတဲ့အတွက် အားလုံးအဆင်ပြေစွာ SDK ကို တည်ဆောက်နိုင်မှာဖြစ်ပါတယ်။ 

ဒီ script သည်


Vendor Upstream ကိုရှာရန်

Compute Chip Only Upstream ကိုရှာရန်။