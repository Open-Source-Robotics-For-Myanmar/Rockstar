# $\color{#00c853}{\text{SDK မတင်မီ ROCK 5B hardware စစ်ရန်}}$

**Commands ကို ROCK 5B ပေါ်တွင် အပိုင်းလိုက် run ပါ။** Device/IP/path နမူနာများကို မိမိစက်အတိုင်းပြင်ပါ။ Device တွေ့ရုံနှင့် အလုပ်လုပ်သည်ဟု မသတ်မှတ်ပါနှင့်။

| မှတ်တမ်း | အဓိပ္ပါယ် |
|---|---|
| PASS | လက်တွေ့စမ်းသပ်မှုအောင် |
| FAIL | စမ်းသပ်မှုမအောင် |
| BLOCKED | Driver/runtime/စမ်းရန်ပစ္စည်း မရှိသေး |
| N/A | မတပ်ထား၊ deployment အတွက်လည်း မလို |

လိုအပ်သော hardware အားလုံး **PASS** ဖြစ်မှ deploy ပါ။ Driver မရှိခြင်းက hardware ပျက်ကြောင်း မဆိုလိုပါ။ [ROCK 5B specs](https://radxa.com/products/rock5/5b/#documentation) · [Pinout](https://docs.radxa.com/en/rock5/rock5b/hardware-design/hardware-interface)

## $\color{red}{\text{၁။ ပြင်ဆင်ခြင်း}}$

- [ ] Board/RAM/OS/PSU နှင့် တပ်ထားသော accessories ကိုမှတ်ပါ။
- [ ] Heatsink/fan တပ်ပါ။ Module/ribbon cable ချိတ်မီ power ပိတ်ပါ။
- [ ] စမ်းရန် monitor၊ USB device၊ LAN peer နှင့် camera တို့ ပြင်ပါ။

```bash
sudo apt update
sudo apt install -y pciutils usbutils ethtool iperf3 stress-ng memtester \
  fio nvme-cli smartmontools mmc-utils lm-sensors mesa-utils mesa-utils-extra \
  vulkan-tools libdrm-tests alsa-utils v4l-utils ffmpeg gpiod i2c-tools \
  iw bluez rfkill python3 python3-venv python3-opencv python3-numpy git
mkdir -p "$HOME/rock5b-verification"
script -q -f "$HOME/rock5b-verification/session-$(date +%Y%m%d-%H%M%S).log"
export LC_ALL=C
export CHECK_START="$(date --iso-8601=seconds)"
cat /etc/os-release
uname -a
tr '\0' '\n' < /proc/device-tree/model
lscpu
free -h
systemctl --failed
sudo journalctl -k -b --no-pager
```

**PASS:** ROCK 5B/RK3588၊ aarch64၊ CPU ၈ core၊ တပ်ထားသော RAM နှင့်ကိုက်သည်။ Reserved memory ကြောင့် RAM အနည်းငယ်လျော့ပြခြင်း ပုံမှန်ဖြစ်သည်။ Package မရလျှင် အခြား packages ကို သီးခြားတင်ပါ။

## $\color{red}{\text{၂။ CPU / RAM / အပူ / power / fan}}$

```bash
for z in /sys/class/thermal/thermal_zone*; do
  echo "$z"
  cat "$z/type" "$z/temp"
  grep -H . "$z"/trip_point_*_temp 2>/dev/null
done
stress-ng --cpu 8 --cpu-method all --verify --timeout 5m --metrics-brief
sudo memtester 256M 1
sensors
grep -H . /sys/class/hwmon/hwmon*/fan*_input 2>/dev/null
# ဒုတိယ terminal မှ test လုပ်နေချိန် အပူကြည့်ရန်။
watch -n 2 'grep -H . /sys/class/thermal/thermal_zone*/temp'
```

**PASS:** Error/reboot/hang မရှိ၊ အပူတည်ငြိမ်၊ fan လည်သည်။ Sysfs အပူကို ၁၀၀၀ ဖြင့်စားလျှင် °C ရသည်။ Critical trip အနီးရောက်လျှင် test ရပ်ပါ။ `memtester` က သတ်မှတ်ထားသော 256 MiB ကိုသာစစ်သည်။ PSU ကောင်းမကောင်းကို command တစ်ခုတည်းဖြင့် မသိနိုင်ပါ။

## $\color{red}{\text{၃။ microSD / eMMC / NVMe / SPI flash}}$

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
findmnt /
df -hT
sudo nvme list
# တပ်ထားသော controller အမည်ဖြင့် ပြင်ပါ။
sudo nvme smart-log /dev/nvme0
sudo smartctl -a /dev/nvme0
for d in /sys/bus/mmc/devices/*; do
  [ -d "$d" ] || continue
  echo "$d"
  cat "$d/type" "$d/name"
done
cat /proc/mtd
# eMMC ဟု အတည်ပြုပြီးမှ၊ SD card တွင် မသုံးရန်။
sudo mmc extcsd read /dev/mmcblkX
```

Mounted storage **တစ်ခုစီ** အတွက် အောက်ပါ test ပြန်လုပ်ပါ။ `TEST_DIR` ကို အဲဒီ disk ပေါ်က writable directory ပြောင်းပါ။ အနည်းဆုံး 1 GiB နေရာလွတ်ထားပါ။ **Raw disk ကို fio filename အဖြစ် မပေးပါနှင့်။**

```bash
TEST_DIR="$HOME/rock5b-verification"
findmnt -T "$TEST_DIR"
df -h "$TEST_DIR"
TEST_FILE=$(mktemp "$TEST_DIR/fio-check.XXXXXX")
fio --name=check --filename="$TEST_FILE" --size=256M --rw=write \
  --bs=1M --ioengine=sync --direct=1 --verify=crc32c --do_verify=1 \
  --verify_fatal=1 --fsync_on_close=1 --group_reporting
rm -- "$TEST_FILE"
```

**PASS:** Data verification အောင်၊ I/O/media error မရှိ၊ NVMe critical warning မရှိ။ Direct I/O မရလျှင် မှတ်တမ်းတင်ပြီး `--direct=0` ဖြင့်ပြန်စမ်းပါ။ SPI ကို erase/flash မလုပ်ပါနှင့်။ လိုအပ်သည့် boot media တစ်ခုစီမှ boot စမ်းပါ။

## $\color{red}{\text{၄။ Ethernet / Wi-Fi / Bluetooth / PoE}}$

```bash
ip -br address
ip route
ETH=eth0 # မိမိ interface ပြင်ရန်။
PEER=192.168.1.10 # LAN peer IP ပြင်ရန်။
sudo ethtool "$ETH"
ip -s link show dev "$ETH"
ping -I "$ETH" -c 20 "$PEER"
# Peer စက်တွင် iperf3 -s ကို အရင် run ပါ။
iperf3 -c "$PEER" -t 30
iperf3 -c "$PEER" -t 30 -R
ip -s link show dev "$ETH"
```

**PASS:** Link တည်ငြိမ်၊ packet loss/error မတိုး၊ negotiated speed နှင့်ကိုက်သည်။ 2.5G အတွက် peer/switch/cable ကလည်း ထောက်ပံ့ရမည်။ Route သည် စမ်းနေသော interface ကိုသုံးကြောင်းစစ်ပါ။

Wi-Fi/Bluetooth module တပ်ထားမှ:

```bash
rfkill list
iw dev
WLAN=wlan0 # မိမိ interface ပြင်ရန်။
sudo iw dev "$WLAN" scan | head -60
iw dev "$WLAN" link
# Wi-Fi ချိတ်ပြီးမှ run ပါ။
ping -I "$WLAN" -c 20 "$PEER"
bluetoothctl list
bluetoothctl show
bluetoothctl --timeout 20 scan on
```

**PASS:** Wi-Fi မှ data ပို့နိုင်၊ Bluetooth device ကို pair/connect လုပ်ပြီး တကယ်သုံးနိုင်ရမည်။ Scan ရရုံ မလုံလောက်ပါ။ PoE HAT ရှိလျှင် PoE source ဖြင့် boot/load စမ်းပါ။

## $\color{red}{\text{၅။ USB / GPU / display}}$

```bash
lsusb
lsusb -t
ls -l /dev/dri /dev/mali* 2>/dev/null
for c in /sys/class/drm/card*-*; do
  [ -f "$c/status" ] || continue
  echo "$c"
  cat "$c/status" "$c/modes"
done
modetest -c
# Board ၏ desktop session မှ run ရန်။
glxinfo -B
eglinfo
vulkaninfo --summary # Vulkan လိုအပ်မှ။
```

- [ ] USB-A port တစ်ခုစီမှာ device တပ်ပြီး data transfer စမ်းပါ။ USB storage ကို အဆင့် ၃ ဖြင့်စစ်ပါ။
- [ ] USB 3 device/cable ဖြင့် USB 3 port က `5000M` ပြရမည်။
- [ ] GPU benchmark ရှိလျှင် `glmark2` သို့မဟုတ် image နှင့်ကိုက်ညီသော EGL/DRM test run ပါ။
- [ ] HDMI outputs နှစ်ခု၊ USB-C DP နှင့် တပ်ထားသော DSI/touch ကို တစ်ခုစီစမ်းပါ။

**PASS:** Hardware Mali renderer သုံးပြီး ပုံရိပ်တည်ငြိမ်သည်။ `llvmpipe/softpipe/lavapipe` က software rendering ဖြစ်သည်။ SSH မှ display မရှိဘဲ run မရခြင်းကို GPU ပျက်ဟု မသတ်မှတ်ပါနှင့်။ [Interface လမ်းညွှန်](https://docs.radxa.com/en/rock5/rock5b/getting-started/interface-usage)

## $\color{red}{\text{၆။ NPU — AI deployment အတွက် မဖြစ်မနေ}}$

### $\color{cyan}{\text{Driver စစ်ရန်}}$

```bash
sudo journalctl -k -b | grep -Ei 'rknpu|npu|iommu'
find /sys/bus/platform/drivers -maxdepth 1 -iname '*npu*'
ldconfig -p | grep -E 'librknn(rt|_api)'
mountpoint -q /sys/kernel/debug || sudo mount -t debugfs debugfs /sys/kernel/debug
sudo cat /sys/kernel/debug/rknpu/version
sudo cat /sys/kernel/debug/rknpu/load
```

Debugfs/device node အမည်က kernel အလိုက် ကွာနိုင်သည်။ **Driver တွေ့ရုံနှင့် PASS မဟုတ်ပါ။** Compatible RKNN runtime မရှိသေးလျှင် inference test ကို BLOCKED မှတ်ပါ။

### $\color{cyan}{\text{Diagnostic runtime နှင့် model စမ်းရန်}}$

[Official RKNN repository](https://github.com/airockchip/rknn-toolkit2) မှ **driver နှင့်ကိုက်ညီသော release** ကိုရွေးပါ။ Wheel က board ၏ Python ABI + **aarch64** နှင့်ကိုက်ရမည်။ x86_64 wheel မသုံးပါနှင့်။

```bash
cd "$HOME/rock5b-verification"
git clone https://github.com/airockchip/rknn-toolkit2.git
cd rknn-toolkit2
git tag --list
RKNN_REF=REPLACE_WITH_COMPATIBLE_TAG_OR_COMMIT
# အပေါ်က placeholder ကိုပြင်ပြီးမှ ဆက်လုပ်ပါ။
git checkout "$RKNN_REF"
git rev-parse HEAD
python3 --version
find rknn-toolkit-lite2 -name '*aarch64.whl'
python3 -m venv --system-site-packages "$HOME/rock5b-verification/rknn-check-env"
source "$HOME/rock5b-verification/rknn-check-env/bin/activate"
RKNN_WHEEL=/absolute/path/to/matching_aarch64.whl
python -m pip install "$RKNN_WHEEL"
cd rknn-toolkit-lite2/examples/resnet18
python test.py
```

**PASS:** Model load/init/inference အောင်ပြီး supplied shuttle ပုံအတွက် space shuttle classification ထွက်ရမည်။ Version/permission error ဖြစ်လျှင် ပြင်ပြီးပြန်စမ်းပါ။ Wheel မကိုက်လျှင် supported Python environment သုံးပါ။

### $\color{cyan}{\text{NPU core ၃ ခုစလုံး စစ်ရန်}}$

အပေါ်က example directory နှင့် activated environment ထဲမှ run ပါ။

```bash
python - <<'PY'
import cv2
import numpy as np
from rknnlite.api import RKNNLite
image = cv2.imread('space_shuttle_224.jpg')
assert image is not None, 'Missing image'
image = np.expand_dims(cv2.cvtColor(image, cv2.COLOR_BGR2RGB), 0)
baseline = None
for name in ('NPU_CORE_0', 'NPU_CORE_1', 'NPU_CORE_2'):
    runtime = RKNNLite()
    try:
        assert runtime.load_rknn('resnet18_for_rk3588.rknn') == 0
        assert runtime.init_runtime(core_mask=getattr(RKNNLite, name)) == 0
        for _ in range(30):
            result = runtime.inference(inputs=[image])
            assert result is not None and len(result) > 0
            scores = np.asarray(result[0])
            assert scores.size == 1000 and np.isfinite(scores).all()
            top = int(scores.argmax())
            if baseline is None:
                baseline = top
            assert top == baseline, (name, top, baseline)
        print(name, 'PASS', top)
    finally:
        runtime.release()
PY
sudo journalctl -k -b | grep -Ei 'rknpu|iommu|fault|timeout'
```

**PASS:** Core တစ်ခုစီ inference ၃၀ ကြိမ်အောင်၊ top class တူ၊ NPU/IOMMU fault မရှိ။ Inference ပြီးချိန် load `0` ပြခြင်း ပုံမှန်ဖြစ်သည်။ [မူရင်း example](https://github.com/airockchip/rknn-toolkit2/blob/master/rknn-toolkit-lite2/examples/resnet18/test.py)

## $\color{red}{\text{၇။ Camera / HDMI input / VPU / RGA}}$

```bash
v4l2-ctl --list-devices
media-ctl -d /dev/media0 -p # တကယ့် media node ဖြင့်ပြင်ရန်။
VIDEO=/dev/videoX # Capture node ကိုရွေးရန်။
v4l2-ctl -d "$VIDEO" --all
v4l2-ctl -d "$VIDEO" --list-formats-ext
# Source နှင့်ကိုက်ညီသော format သတ်မှတ်ပြီးမှ။
v4l2-ctl -d "$VIDEO" --stream-mmap=4 --stream-count=100 \
  --stream-to=/dev/null --stream-poll
ffmpeg -hide_banner -decoders | grep -Ei 'rkmpp|v4l2'
ffmpeg -hide_banner -encoders | grep -Ei 'rkmpp|v4l2'
# h264_rkmpp decoder ပါသော build ဖြစ်မှ။
ffmpeg -hide_banner -loglevel verbose -c:v h264_rkmpp \
  -i /absolute/path/to/known-good-h264.mp4 -t 30 -an -f null -
```

- **Camera:** CSI/USB တစ်ခုစီမှ frame ရပြီး preview ပုံမှန်ရမည်။ Sensor overlay လိုနိုင်သည်။
- **HDMI input:** Unprotected source သုံး၍ [HDMI RX guide](https://docs.radxa.com/en/rock5/rock5b/app-development/hdmi-rx) အတိုင်းစမ်းပါ။
- **VPU:** Hardware decoder ဖြင့် clip decode အောင်ပြီး output ပုံမှန်ဖြစ်ရမည်။ Encoder လိုလျှင် hardware encode output ကို ပြန်ဖွင့်စစ်ပါ။
- **RGA:** Matching resize/color demo ကို run ပြီး output စစ်ပါ။ [RGA guide](https://docs.radxa.com/en/rock5/rock5b/app-development/rga-usage-guide)

Device/codec စာရင်းပေါ်ရုံ မလုံလောက်ပါ။ Stock FFmpeg မှာ accelerator မပါလျှင် matching diagnostic tools မရမချင်း BLOCKED မှတ်ပါ။

## $\color{red}{\text{၈။ Audio}}$

```bash
aplay -l
arecord -l
alsamixer
PLAYBACK=plughw:CARD=REPLACE,DEV=0
CAPTURE=plughw:CARD=REPLACE,DEV=0
speaker-test -D "$PLAYBACK" -c 2 -t wav -l 1
arecord -D "$CAPTURE" -f S16_LE -r 48000 -c 2 -d 5 \
  "$HOME/rock5b-verification/mic.wav"
aplay -D "$PLAYBACK" "$HOME/rock5b-verification/mic.wav"
```

**PASS:** ဘယ်/ညာ အသံမှန်၊ microphone recording ကြည်လင်သည်။ Card/format/channel ကို မိမိ device အတိုင်းပြင်ပါ။ လိုအပ်သည့် analog/HDMI/DP/USB audio တစ်ခုစီစမ်းပါ။

## $\color{red}{\text{၉။ GPIO / I2C / SPI / UART / PWM / ADC}}$

```bash
gpiodetect
gpioinfo
i2cdetect -l
ls -l /dev/i2c-* /dev/spidev* /dev/ttyS* 2>/dev/null
cat /proc/cmdline
ls /sys/class/pwm /sys/bus/iio/devices
```

**Pinout ကိုအရင်စစ်ပါ:** GPIO = **3.3 V**၊ ADC = **1.8 V**။ Signal pin သို့ 5 V မပေးပါနှင့်။ အသုံးပြုနေသော pin/serial console ကို loopback မလုပ်ပါနှင့်။ လိုသော overlay သာဖွင့်ပါ။

| Interface | လက်တွေ့စစ်ရန် |
|---|---|
| GPIO | `gpioset --help` / `gpioget --help` ဖြင့် syntax စစ်၊ free output/input ကို resistor ဖြင့်ချိတ်၊ low/high တူမတူစစ် |
| I2C | Peripheral datasheet က ခွင့်ပြုသော ID register ကို `i2ctransfer -y BUS w1@ADDRESS REGISTER r1` ဖြင့်ဖတ်၊ နမူနာတန်ဖိုးများ ပြင်ရန် |
| SPI | Free port တွင် MOSI/MISO ချိတ်၊ `spidev_test -D /dev/spidevX.Y -s 500000 -v` ဖြင့် TX/RX တူမတူစစ် |
| PWM | Configured output frequency/duty ကို scope ဖြင့်တိုင်း |
| ADC | IIO `in_voltage*_raw` / `in_voltage*_scale` ကို GND နှင့် 1.8 V အောက် known voltage ဖြင့်နှိုင်း |

Free UART တွင် TX/RX ချိတ်ပြီး:

```bash
UART=/dev/ttySX # Console မဟုတ်သော port ဖြင့်ပြင်ရန်။
stty -F "$UART" 115200 raw -echo -ixon -ixoff -crtscts
CAPTURE_FILE=$(mktemp)
timeout 5 cat "$UART" > "$CAPTURE_FILE" &
READER_PID=$!
sleep 1
printf 'ROCK5B_UART_TEST\n' > "$UART"
wait "$READER_PID" # Timeout exit 124 ဖြစ်ခြင်း ပုံမှန်။
grep -Fx 'ROCK5B_UART_TEST' "$CAPTURE_FILE"
rm -- "$CAPTURE_FILE"
```

**PASS:** ပို့သောစာသားအတိုင်းရသည်။ Test ပြီးလျှင် loopback ကြိုးဖြုတ်ပါ။

## $\color{red}{\text{၁၀။ RTC / LED / buttons / ပြန်တက်ခြင်း}}$

```bash
ls -l /dev/rtc*
for r in /sys/class/rtc/rtc*; do
  echo "$r"
  cat "$r/name"
done
sudo hwclock --show --rtc=/dev/rtc0 # Battery-backed RTC ကိုရွေးရန်။
ls /sys/class/leds
cat /proc/bus/input/devices
```

- [ ] RTC battery ရှိလျှင် main power ဖြုတ်/ပြန်တပ်ပြီး network time sync မဖြစ်မီ အချိန်မှန်မမှန်စစ်ပါ။
- [ ] LED နှင့် user/power button ပုံမှန်လုပ်သည်။
- [ ] `sudo reboot` ပြီး login ပြန်ရသည်။
- [ ] `sudo poweroff` ပြီး power ဖြုတ်/ပြန်တပ်လျှင် boot ရသည်။
- [ ] CPU/NPU/camera/network ကို အတူတူသုံးပြီး power/အပူ တည်ငြိမ်သည်။

## $\color{red}{\text{၁၁။ နောက်ဆုံးရလဒ်}}$

Reboot မလုပ်မီ logs သိမ်းပါ။

```bash
sudo journalctl -k -b --since "$CHECK_START" --no-pager \
  > "$HOME/rock5b-verification/kernel-after-tests.log"
grep -Ei 'error|fail|timeout|reset|fault|thermal|I/O' \
  "$HOME/rock5b-verification/kernel-after-tests.log"
dpkg-query -W > "$HOME/rock5b-verification/packages.txt"
exit # Transcript ပိတ်ရန်။
```

| စစ်မည့်အရာ | PASS / FAIL / BLOCKED / N/A နှင့် မှတ်ချက် |
|---|---|
| CPU / RAM / power / fan | |
| SD / eMMC / NVMe / boot | |
| Ethernet / Wi-Fi / Bluetooth / PoE | |
| USB port တစ်ခုစီ | |
| GPU / HDMI outputs / DP / DSI / touch | |
| NPU core ၃ ခု | |
| Camera / HDMI input / VPU / RGA | |
| Audio playback / capture | |
| GPIO / I2C / SPI / UART / PWM / ADC | |
| RTC / LED / buttons / reboot / combined load | |

**Deploy ခွင့်:** လိုအပ်သည့် feature အားလုံး PASS၊ မရှင်းရသေးသော crash/I/O/accelerator error မရှိ၊ driver/runtime versions မှတ်တမ်းရှိရမည်။ ဤစာတမ်းရှိခြင်းက board စမ်းပြီးပြီဟု မဆိုလိုပါ။

References:
- `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/README/02_verify_builtin_pheripherials.md`
- `./01_Rock5B_SDK_Generation_On_Existing_OS_Images/README/00_HOW_TO_BUILD_LINUX_SDK.md`
- `./md_lists.md`

