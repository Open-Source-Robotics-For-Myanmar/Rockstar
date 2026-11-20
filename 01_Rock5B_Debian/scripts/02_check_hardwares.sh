#!/usr/bin/env bash
# RK3588/RK3588S hardware inventory. No Python or package installation.
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/lib/common.sh"
connect_board mr_robot

inspect() {
    local selection=$1 name
    case "$selection" in
        1) name=cpu;; 2) name=memory;; 3) name=storage;; 4) name=network;;
        5) name=usb_pcie;; 6) name=gpu_display;; 7) name=camera_vpu_rga;;
        8) name=audio;; 9) name=gpio_buses;; 10) name=npu;;
        11) name=thermal_power_fan;; 12) name=wireless;; 13) name=rtc_led_buttons;;
        14) name=kernel_errors;; 15) name=cpu_load_test;; *) return 1;;
    esac
    # Save each check to a new file.
    name="${name}_$(date +%H%M%S)_${RANDOM}"
    {
        cat <<'REMOTE'
set -u
export LC_ALL=C
run() {
    printf '\n$'; printf ' %q' "$@"; printf '\n'
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "BLOCKED: missing command: $1"; return 0
    fi
    "$@"
    rc=$?
    if [ "$rc" -ne 0 ]; then echo "BLOCKED/ERROR: exit=$rc (check permissions, driver, or device)"; fi
    return 0
}
show() {
    for p in "$@"; do
        [ -e "$p" ] || continue
        printf '\n%s\n' "$p"
        cat "$p" 2>&1 || echo 'BLOCKED: cannot read file.'
    done
}
date -Is
uname -a
REMOTE
        case "$selection" in
            1) cat <<'REMOTE'
run lscpu
show /sys/devices/system/cpu/online /sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq /sys/devices/system/cpu/cpufreq/policy*/scaling_max_freq
REMOTE
            ;;
            2) cat <<'REMOTE'
run free -h
show /proc/meminfo /proc/swaps
REMOTE
            ;;
            3) cat <<'REMOTE'
run lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
run findmnt
run df -hT
run nvme list
for d in /dev/nvme[0-9]; do [ ! -c "$d" ] || run nvme smart-log "$d"; done
show /sys/bus/mmc/devices/*/type /sys/bus/mmc/devices/*/name /proc/mtd
REMOTE
            ;;
            4) cat <<'REMOTE'
run ip -br address
run ip route
run ip -s link
for p in /sys/class/net/*; do
    dev=${p##*/}
    [ "$dev" = lo ] && continue
    run ethtool "$dev"
done
REMOTE
            ;;
            5) cat <<'REMOTE'
run lsusb
run lsusb -t
run lspci -nnk
REMOTE
            ;;
            6) cat <<'REMOTE'
run ls -l /dev/dri
for p in /dev/mali*; do [ ! -e "$p" ] || run ls -l "$p"; done
show /sys/class/drm/card*-*/status /sys/class/drm/card*-*/modes
run modetest -c
echo 'Rendering is not tested. Run a GPU test in a desktop session.'
REMOTE
            ;;
            7) cat <<'REMOTE'
if command -v v4l2-ctl >/dev/null 2>&1; then
    run v4l2-ctl --list-devices
else
    echo 'INFO: v4l2-ctl is missing; using device/sysfs inventory.'
fi
for p in /dev/video*; do
    [ -e "$p" ] || continue
    run ls -l "$p"
    node=${p##*/}
    show "/sys/class/video4linux/$node/name"
    if [ -e "/sys/class/video4linux/$node/device" ]; then
        printf 'Device path: '
        readlink -f "/sys/class/video4linux/$node/device"
    fi
    if command -v v4l2-ctl >/dev/null 2>&1; then run v4l2-ctl -d "$p" --all; fi
done
for p in /dev/media*; do
    [ -e "$p" ] || continue
    run ls -l "$p"
    if command -v media-ctl >/dev/null 2>&1; then run media-ctl -d "$p" -p; fi
done
for p in /dev/mpp_service /dev/rga; do [ ! -e "$p" ] || run ls -l "$p"; done
if command -v ffmpeg >/dev/null; then
    ffmpeg -hide_banner -decoders 2>&1 | grep -Ei 'rkmpp|v4l2' || true
    ffmpeg -hide_banner -encoders 2>&1 | grep -Ei 'rkmpp|v4l2' || true
fi
echo 'Capture, encode, decode, and RGA functions are not tested.'
REMOTE
            ;;
            8) cat <<'REMOTE'
run aplay -l
run arecord -l
show /proc/asound/cards
run amixer scontents
echo 'Listen to playback and a microphone recording to verify audio.'
REMOTE
            ;;
            9) cat <<'REMOTE'
run gpiodetect
run gpioinfo
run i2cdetect -l
for p in /dev/i2c-* /dev/spidev* /dev/ttyS*; do [ ! -e "$p" ] || run ls -l "$p"; done
run ls /sys/class/pwm
run ls /sys/bus/iio/devices
show /proc/cmdline
echo 'No pins driven or I2C buses probed. Test with a loopback or fixture.'
REMOTE
            ;;
            10) cat <<'REMOTE'
run ls -l /dev/dri
for p in /dev/rknpu*; do [ ! -e "$p" ] || run ls -l "$p"; done
run find /sys/bus/platform/drivers -maxdepth 1 -iname '*npu*'
run find /sys/class/devfreq -maxdepth 1 -iname '*npu*'
for p in /sys/class/devfreq/*npu*/cur_freq /sys/class/devfreq/*npu*/available_frequencies /sys/class/devfreq/*npu*/governor; do
    [ ! -e "$p" ] || show "$p"
done
if command -v ldconfig >/dev/null; then ldconfig -p | grep -Ei 'rknn|rga|mpp|mali' || true; fi
for p in /sys/kernel/debug/rknpu/version /sys/kernel/debug/rknpu/load; do
    if [ -r "$p" ]; then
        show "$p"
    elif command -v sudo >/dev/null 2>&1 && sudo -n test -r "$p" 2>/dev/null; then
        printf '\n%s (sudo)\n' "$p"
        sudo -n cat "$p"
    elif [ -e "$p" ]; then
        echo "INFO: $p exists but is unreadable; try: sudo cat $p"
    else
        echo "INFO: $p is missing. This script does not mount debugfs."
    fi
done
if command -v dmesg >/dev/null 2>&1; then
    if kernel_log=$(dmesg 2>&1); then
        npu_log=$(printf '%s\n' "$kernel_log" | grep -i rknpu || true)
        if [ -n "$npu_log" ]; then
            printf '\nNPU kernel messages:\n%s\n' "$npu_log"
        else
            echo 'INFO: No RKNPU lines found in the accessible kernel log.'
        fi
    elif command -v sudo >/dev/null 2>&1 && kernel_log=$(sudo -n dmesg 2>&1); then
        npu_log=$(printf '%s\n' "$kernel_log" | grep -i rknpu || true)
        if [ -n "$npu_log" ]; then
            printf '\nNPU kernel messages (sudo):\n%s\n' "$npu_log"
        else
            echo 'INFO: No RKNPU lines found in the accessible kernel log.'
        fi
    else
        printf 'INFO: Kernel log is not readable by this SSH user; try: sudo dmesg | grep -i rknpu\n%s\n' "$kernel_log"
    fi
fi
echo 'NPU load is a point-in-time reading. Run inference with a compatible native RKNN demo to verify operation.'
REMOTE
            ;;
            11) cat <<'REMOTE'
show /sys/class/thermal/thermal_zone*/type /sys/class/thermal/thermal_zone*/temp /sys/class/thermal/thermal_zone*/trip_point_*_temp
show /sys/class/hwmon/hwmon*/name /sys/class/hwmon/hwmon*/fan*_input /sys/class/hwmon/hwmon*/pwm*
run sensors
echo 'Sysfs temperature / 1000 = Celsius. Software alone cannot verify PSU quality.'
REMOTE
            ;;
            12) cat <<'REMOTE'
run rfkill list
run iw dev
if command -v iw >/dev/null; then
    while read -r dev; do run iw dev "$dev" link; done < <(iw dev | awk '$1=="Interface" {print $2}')
fi
run bluetoothctl list
run bluetoothctl show
echo 'No wireless scan, connection, or pairing performed. Test data transfer separately.'
REMOTE
            ;;
            13) cat <<'REMOTE'
show /sys/class/rtc/rtc*/name /sys/class/rtc/rtc*/date /sys/class/rtc/rtc*/time
run ls -l /sys/class/leds
show /proc/bus/input/devices
echo 'Test RTC retention, buttons, and cold boot manually.'
REMOTE
            ;;
            14) cat <<'REMOTE'
run journalctl -k -b --no-pager -n 500
run systemctl --failed --no-pager
REMOTE
            ;;
            15) cat <<'REMOTE'
if command -v stress-ng >/dev/null; then
    stress-ng --cpu 8 --cpu-method all --verify --timeout 60s --metrics-brief
    rc=$?
    if [ "$rc" -eq 0 ]; then echo 'PASS: CPU 60s smoke test'; else echo "FAIL: stress-ng exit=$rc"; fi
    exit "$rc"
fi
echo 'BLOCKED: stress-ng is missing. No packages will be installed.'
exit 127
REMOTE
            ;;
        esac
        if [[ $selection != 15 ]]; then
            printf '%s\n' "echo 'RESULT: Inventory only. Functional checks are still required.'"
        fi
    } | run_remote "$name"
}
while true; do
    cat <<'MENU'

1 CPU             2 Memory          3 Storage
4 Network         5 USB / PCIe      6 GPU / Display
7 Camera/VPU/RGA   8 Audio           9 GPIO/I2C/SPI/UART/PWM/ADC
10 NPU            11 Thermal/Fan    12 Wi-Fi/Bluetooth
13 RTC/LED/Buttons 14 Kernel logs    15 CPU load 60s (requires stress-ng)
a All inventory (no load test)       0 Exit
MENU
    ask selection 'Select a check'
    case "$selection" in
        0) break;;
        a|A) for n in {1..14}; do inspect "$n" || echo "Failed check: $n"; done;;
        15)
            ask answer 'Ensure adequate cooling. Type RUN to start the load test'
            [[ $answer != RUN ]] || inspect 15 || true
            ;;
        [1-9]|1[0-4]) inspect "$selection" || true;;
        *) echo 'Choose an option from the menu.';;
    esac
done
echo "Logs saved to: $RESULT_DIR"
