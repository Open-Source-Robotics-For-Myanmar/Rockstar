#!/usr/bin/env python3
"""Create a standalone ARM64 cross-compilation workspace without a target sysroot.

Tkinter GUI port of ``05_create_RK3588_SDK_env_without_sysroot.sh``.

The nine inputs are metadata only. This program never SSHes to the board,
installs packages, downloads libraries, builds a project, or modifies an
existing SDK directory. Stdlib only; run via ../automation to use scripts/.venv.

Headless entry points used for testing:
    validate_values(values) -> dict
    collect_host_info()     -> dict
    build_workspace(values, host) -> pathlib.Path
"""

from __future__ import annotations

import os
import pathlib
import platform
import queue
import shlex
import shutil
import subprocess
import sys
import tempfile
import threading
try:
    import tkinter as tk
    from tkinter import font as tkfont, messagebox, ttk
    from tkinter.scrolledtext import ScrolledText
except ImportError as exc:
    raise SystemExit(
        "Tkinter is unavailable for %s. Install python3-tk for /usr/bin/python3 "
        "and run this GUI via ../automation." % sys.executable
    ) from exc

# python_gui_rules.md palette
BUTTON_COLOR = "#08E0F5"
BG_COLOR = "#1E2434"
FG_COLOR = "#F4F7FB"
ENTRY_BG = "#2B3245"
HINT_FG = "#9FAAC2"
ERROR_FG = "#FF8A80"

CROSS_COMPILE_DEFAULT = "aarch64-linux-gnu-"
SDK_DEFAULT = os.path.expanduser("~/RK3588_SDK_on_Ubuntu2204")


def _h(tag: str, text: str) -> tuple[str, str]:
    return tag, text


FIELD_SPECS = [
    {
        "key": 'TARGET_BOARD',
        "label": 'Target board/model',
        "default": '',
        "help": [
            _h('ရည်ရွယ်ချက်:', 'SDK ကို ဘယ် board အတွက် ပြင်ဆင်ထားသလဲ မှတ်တမ်းတင်ဖို့ board/model အမည် လိုပါတယ်။'),
            _h('အလုပ်လုပ်ပုံ:', 'Device tree ထဲက model ကို ဖတ်ပြီး tr က စာသားအဆုံးရှိ NUL ကို ဖယ်ပေးပါတယ်။ Armbian သုံးထားမှ အောက်က အစားထိုး command ကို သုံးပါ။'),
            _h('အရေးကြီးပုံ:', 'Board များစွာရှိတဲ့အခါ SDK မှတ်တမ်း မရောစေဖို့ပါ။ ဒီအမည်ထည့်တာက driver သို့မဟုတ် compiler ကို အလိုအလျောက် မရွေးပေးပါ။'),
            _h('On target:', "tr -d '\\0' < /proc/device-tree/model; echo"),
            _h('Alternative:', "grep -E '^(BOARD_NAME|BOARD)=' /etc/armbian-release"),
            _h('Enter:', 'ဥပမာ Radxa ROCK 5B ကို တစ်ကြောင်းတည်း ထည့်ပါ။'),
        ],
    },
    {
        "key": 'TARGET_COMPATIBLE',
        "label": 'Device-tree compatible value',
        "default": '',
        "help": [
            _h('ရည်ရွယ်ချက်:', 'Board ရဲ့ SoC က ဒီ SDK ရည်ရွယ်ထားတဲ့ RK3588 ဟုတ်မဟုတ် စစ်ဖို့ပါ။'),
            _h('အလုပ်လုပ်ပုံ:', 'Device tree ရဲ့ compatible စာရင်းကို Linux က hardware နဲ့ driver ကိုက်ညီမှု ရွေးရာမှာ သုံးပါတယ်။ tr က NUL ခြားထားတဲ့စာရင်းကို တစ်ကြောင်းစီခွဲပြီး grep က rk3588 ပါတဲ့ ပထမတန်ဖိုးကို ထုတ်ပါတယ်။'),
            _h('အရေးကြီးပုံ:', 'မတူတဲ့ SoC အတွက် SDK မှားဆောက်ခြင်းကို တားပေးပါတယ်။ ဒီ script က ထည့်ထားတဲ့စာသားမှာ rk3588 ပါမပါပဲ စစ်ပြီး board ကို ကိုယ်တိုင်ချိတ်စစ်တာ မဟုတ်ပါ။'),
            _h('On target:', "tr '\\0' '\\n' < /proc/device-tree/compatible | grep -m1 rk3588"),
            _h('Enter:', 'ဥပမာ rockchip,rk3588 — rk3588 ပါတဲ့ တန်ဖိုးတစ်ကြောင်းသာ ထည့်ပါ။ Output မရရင် board ကို ပြန်စစ်ပါ၊ unknown မထည့်ပါနဲ့။'),
        ],
    },
    {
        "key": 'TARGET_ARCH',
        "label": 'Target architecture (arm64/aarch64)',
        "default": '',
        "help": [
            _h('ရည်ရွယ်ချက်:', 'Target OS က 64-bit ARM program ကို run နိုင်မယ့် architecture ဟုတ်မဟုတ် သိဖို့ပါ။'),
            _h('အလုပ်လုပ်ပုံ:', 'dpkg က OS packages ရဲ့ architecture ကို ပြပါတယ်။ uname -m က kernel ရဲ့ architecture ကို ပြပါတယ်။ arm64 နဲ့ aarch64 က ဒီနေရာမှာ 64-bit ARM ကို ရည်ညွှန်းပါတယ်။'),
            _h('အရေးကြီးပုံ:', 'SDK က AArch64 compiler ကို သုံးတာမို့ x86_64 သို့မဟုတ် 32-bit ARM OS အတွက် မကိုက်ပါ။ Script က arm64/aarch64 ကိုသာ လက်ခံပြီး aarch64 အဖြစ် မှတ်တမ်းတင်ပါတယ်။'),
            _h('On target:', 'dpkg --print-architecture'),
            _h('Cross-check:', 'uname -m'),
            _h('Enter:', 'arm64 သို့မဟုတ် aarch64။ နှစ်ခုကွဲနေရင် userspace က 32-bit ဖြစ်မဖြစ် စစ်ပါ၊ kernel output တစ်ခုတည်းကို မမှီခိုပါနဲ့။'),
        ],
    },
    {
        "key": 'TARGET_OS',
        "label": 'Target OS name',
        "default": 'unknown',
        "help": [
            _h('ရည်ရွယ်ချက်:', 'Target ပေါ်က Linux distribution အမည်နဲ့ version ကို မှတ်တမ်းထားဖို့ပါ။'),
            _h('အလုပ်လုပ်ပုံ:', '/etc/os-release ထဲက PRETTY_NAME ကို ဖတ်ထုတ်ပါတယ်။ ဒါက Debian/Ubuntu စတဲ့ OS userspace အမည်ဖြစ်ပြီး kernel version နဲ့ မတူပါ။'),
            _h('အရေးကြီးပုံ:', 'နောက်ပိုင်း library/package ရှာတဲ့အခါ၊ အခြားစက်မှာ ပြန်ဆောက်တဲ့အခါ ဘယ် OS အတွက်လဲ သိနိုင်ပါတယ်။ ဒီတန်ဖိုးက compiler libraries ကို မပြောင်းပေးပါ။'),
            _h('On target:', '. /etc/os-release; printf \'%s\\n\' "$PRETTY_NAME"'),
            _h('Enter:', 'ဥပမာ Debian GNU/Linux 12 (bookworm)။ မသိရင် unknown ထည့်နိုင်ပါတယ်။'),
        ],
    },
    {
        "key": 'TARGET_CODENAME',
        "label": 'Target OS codename',
        "default": 'unknown',
        "help": [
            _h('ရည်ရွယ်ချက်:', 'Distribution ရဲ့ release အမည်တိုကို သိမ်းဖို့ပါ၊ ဥပမာ Debian ရဲ့ bookworm။'),
            _h('အလုပ်လုပ်ပုံ:', '/etc/os-release ထဲက VERSION_CODENAME ကို ထုတ်ပါတယ်။ မရှိရင် VERSION_ID ကို သုံးပါတယ်။'),
            _h('အရေးကြီးပုံ:', 'OS အမည်တူပေမဲ့ release မတူရင် package/library version တွေ ကွာနိုင်ပါတယ်။ မှန်တဲ့ release အတွက် documentation နဲ့ package repository ကို ရှာဖို့ အထောက်အကူဖြစ်ပြီး repository ကို ဒီ script က မပြောင်းပါ။'),
            _h('On target:', '. /etc/os-release; printf \'%s\\n\' "${VERSION_CODENAME:-$VERSION_ID}"'),
            _h('Enter:', 'ဥပမာ bookworm၊ jammy သို့မဟုတ် version number။ Output မရှိရင် unknown ထည့်ပါ။'),
        ],
    },
    {
        "key": 'TARGET_KERNEL',
        "label": 'Target kernel release',
        "default": 'unknown',
        "help": [
            _h('ရည်ရွယ်ချက်:', 'Target မှာ လက်ရှိ run နေတဲ့ Linux kernel release ကို မှတ်တမ်းထားဖို့ပါ။'),
            _h('အလုပ်လုပ်ပုံ:', 'uname -r က လက်ရှိ boot လုပ်ထားတဲ့ kernel release ကို ပြပါတယ်။ uname -v က build အသေးစိတ်ဖြစ်လို့ ဒီ input အတွက် မသုံးပါ။'),
            _h('အရေးကြီးပုံ:', 'Camera/NPU driver၊ ioctl နဲ့ kernel interface ဆိုင်ရာ ပြဿနာရှာရာမှာ လိုပါတယ်။ Version ထည့်ရုံနဲ့ kernel headers/driver မတင်ပေးသလို kernel module build အတွက်လည်း ဒီ SDK တစ်ခုတည်း မလုံလောက်ပါ။'),
            _h('On target:', 'uname -r'),
            _h('Enter:', 'ဥပမာ 6.1.115-vendor-rk35xx။ မသိရင် unknown ထည့်ပါ။'),
        ],
    },
    {
        "key": 'TARGET_GLIBC',
        "label": 'Target GNU libc version',
        "default": 'unknown',
        "help": [
            _h('ရည်ရွယ်ချက်:', 'Target ရဲ့ C runtime library (glibc) version ကို သိဖို့ပါ။ Program ရဲ့ file I/O၊ memory နဲ့ system call wrapper စတဲ့ အခြေခံလုပ်ဆောင်ချက်တွေကို ပံ့ပိုးပါတယ်။'),
            _h('အလုပ်လုပ်ပုံ:', 'getconf က GNU libc version ကို ထုတ်ပြီး awk က version နံပါတ်ကိုသာ ရွေးပါတယ်။ Dynamic binary ကို run တဲ့အခါ လိုအပ်တဲ့ GLIBC symbol versions တွေ target library မှာ ရှိရပါတယ်။'),
            _h('အရေးကြီးပုံ:', 'ဒီ SDK က target sysroot မသုံးဘဲ host cross-toolchain ရဲ့ libraries နဲ့ link လုပ်ပါတယ်။ Target မှာ binary လိုတဲ့ version မရှိရင် GLIBC_x.y not found ဖြစ်နိုင်ပါတယ်။ ဒီ input ကို သိမ်းထားတာသာဖြစ်ပြီး ABI ကို အလိုအလျောက် မစစ်၊ မပြင်ပေးပါ။'),
            _h('On target:', "getconf GNU_LIBC_VERSION | awk '{print $2}'"),
            _h('Enter:', 'ဥပမာ 2.36 — နံပါတ်သာထည့်ပါ။ GNU libc မရှိ သို့မဟုတ် မသိရင် unknown ထည့်နိုင်ပေမဲ့ GNU toolchain နဲ့ ကိုက်ညီမှုကို သီးခြားစစ်ရပါမယ်။'),
        ],
    },
    {
        "key": 'TARGET_LIBSTDCXX',
        "label": 'Target libstdc++ runtime version',
        "default": 'unknown',
        "help": [
            _h('ရည်ရွယ်ချက်:', 'Target ရဲ့ C++ runtime library (libstdc++) version ကို သိဖို့ပါ။ std::string၊ containers၊ streams စတဲ့ C++ library လုပ်ဆောင်ချက်တွေကို ပံ့ပိုးပါတယ်။'),
            _h('အလုပ်လုပ်ပုံ:', 'dpkg-query က installed package version ကို ပြပါတယ်။ အစားထိုး command က library ထဲက GLIBCXX version အမှတ်အသားတွေကို version အလိုက်စီပြီး အမြင့်ဆုံးကို ထုတ်ပါတယ်။ Package version နဲ့ GLIBCXX symbol version က တန်ဖိုးအမျိုးအစား မတူပါ။'),
            _h('အရေးကြီးပုံ:', 'Cross compiler နဲ့ build ထားတဲ့ C++ binary က target မှာမရှိတဲ့ symbol ကို လိုရင် GLIBCXX_x.y.z not found ဖြစ်နိုင်ပါတယ်။ ဒီမှတ်တမ်းတစ်ခုတည်းနဲ့ ABI ကိုက်ညီမှု မအာမခံနိုင်ဘဲ binary လိုတဲ့ symbols နဲ့ target library ကို သီးခြားတိုက်စစ်ရပါတယ်။'),
            _h('On target:', "dpkg-query -W -f='${Version}\\n' libstdc++6:arm64"),
            _h('Alternative:', "strings /usr/lib/aarch64-linux-gnu/libstdc++.so.6 | grep -E '^GLIBCXX_[0-9]+(\\.[0-9]+)*$' | sort -V | tail -n 1"),
            _h('Enter:', 'Installed package version သို့မဟုတ် ဥပမာ GLIBCXX_3.4.30 ကို ထည့်ပါ။ Library path က စက်အလိုက်ကွာနိုင်ပါတယ်။ မရှိ/မသိရင် unknown ထည့်ပါ။ Script က runtime library ကို install မလုပ်ပေးပါ။'),
        ],
    },
    {
        "key": 'SDK_ROOT',
        "label": 'Absolute SDK workspace path (on host)',
        "default": SDK_DEFAULT,
        "help": [
            _h('ရည်ရွယ်ချက်:', 'SDK workspace အသစ်ကို build host ပေါ်မှာ ဘယ်နေရာဖန်တီးမလဲ သတ်မှတ်ဖို့ပါ။ Target board ရဲ့ folder လမ်းကြောင်း မဟုတ်ပါ။'),
            _h('အလုပ်လုပ်ပုံ:', 'ဒီ folder ထဲမှာ env.sh၊ CMake toolchain၊ metadata နဲ့ libraries ထားဖို့ prefix directory တို့ကို ဖန်တီးပါတယ်။ Folder မရှိသေးရဘဲ parent directory မှာ ရေးခွင့်ရှိရပါတယ်။'),
            _h('အရေးကြီးပုံ:', 'ရှိပြီးသား project/files တွေ မထိခိုက်စေဖို့ ရှိနေပြီးသား destination ကို ငြင်းပါတယ်။ Browse သုံးရင် parent folder ရွေးပြီး SDK folder အသစ်အမည်ပေးပါ။'),
            _h('On host:', 'pwd'),
            _h('Enter:', 'ဥပမာ /home/your-user/RK3588_SDK_new လို absolute path အသစ်ကို ထည့်ပါ။ pwd က လက်ရှိ folder ကိုကြည့်ဖို့သာဖြစ်ပြီး အဲဒီရှိပြီးသား folder ကို destination အဖြစ် မထည့်ပါနဲ့။'),
        ],
    },
]

DEFAULT_VALUES = {spec["key"]: spec["default"] for spec in FIELD_SPECS}

# ---------------------------------------------------------------------------
# Generated file templates.  `%s` placeholders are filled only with values
# that have passed validation; every other `$`/`${}` sequence is literal shell
# or CMake syntax and must survive untouched.
# ---------------------------------------------------------------------------

ENV_SH = """export RK3588_SDK="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export CC=%s
export CXX=%s
export AR=%s
export RANLIB=%s
export STRIP=%s
export PKG_CONFIG="$RK3588_SDK/bin/rk3588-pkg-config"
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH LD_LIBRARY_PATH
unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS CMAKE_PREFIX_PATH
unset PKG_CONFIG_PATH PKG_CONFIG_LIBDIR PKG_CONFIG_SYSROOT_DIR
"""

PKG_CONFIG_WRAPPER = """#!/usr/bin/env bash
set -Eeuo pipefail
sdk_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export PKG_CONFIG_PATH=
export PKG_CONFIG_LIBDIR="$sdk_dir/prefix/lib/pkgconfig:$sdk_dir/prefix/share/pkgconfig"
unset PKG_CONFIG_SYSROOT_DIR
exec %s "$@"
"""

CMAKE_TOOLCHAIN = """set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER "%s")
set(CMAKE_CXX_COMPILER "%s")
set(CMAKE_AR "%s")
set(CMAKE_RANLIB "%s")
set(CMAKE_STRIP "%s")
set(CMAKE_C_FLAGS_INIT "-march=armv8-a -mtune=generic")
set(CMAKE_CXX_FLAGS_INIT "-march=armv8-a -mtune=generic")
get_filename_component(RK3588_SDK_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(CMAKE_FIND_ROOT_PATH "${RK3588_SDK_ROOT}/prefix")
list(PREPEND CMAKE_PREFIX_PATH "${RK3588_SDK_ROOT}/prefix")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_FIND_USE_PACKAGE_REGISTRY FALSE)
set(CMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY FALSE)
set(PKG_CONFIG_EXECUTABLE "${RK3588_SDK_ROOT}/bin/rk3588-pkg-config"
    CACHE FILEPATH "Target pkg-config" FORCE)
"""

HOST_TXT = """Host OS: %s (%s)
Host architecture: %s
C compiler: %s
C compiler target: %s
C compiler version: %s
C++ compiler: %s
C++ compiler target: %s
C++ compiler version: %s
CMake: %s
Ninja: %s
pkg-config: %s
readelf: %s
"""

TARGET_TXT = """Board/model: %s
Device-tree compatible: %s
Architecture: %s
OS: %s
Codename: %s
Kernel: %s
GNU libc: %s
libstdc++ runtime: %s
Input method: manually provided by user; not verified over SSH
"""

TARGET_BASELINE_MD = """# Target baseline (user-provided)

| Item | Value |
|---|---|
| Board/model | %s |
| Device-tree compatible | %s |
| Architecture | %s |
| OS | %s |
| Codename | %s |
| Kernel | %s |
| GNU libc | %s |
| libstdc++ runtime | %s |

These values were entered by the user and were not independently verified.
This workspace uses the host cross-compiler built-in target files; it is not a target-matched sysroot.
Third-party libraries and hardware runtimes are not included.
"""


# ---------------------------------------------------------------------------
# Headless logic
# ---------------------------------------------------------------------------


def validate_values(values: dict) -> dict:
    """Normalise and validate all nine inputs; raise ValueError on error."""
    out = {}
    for spec in FIELD_SPECS:
        raw = values.get(spec["key"], spec["default"])
        out[spec["key"]] = "" if raw is None else str(raw).strip()

    for key in ("TARGET_BOARD", "TARGET_COMPATIBLE", "TARGET_ARCH", "SDK_ROOT"):
        if not out[key]:
            raise ValueError("%s is required." % key)

    for key, value in out.items():
        if "\n" in value or "\r" in value:
            raise ValueError("%s must be a single line." % key)
        if key.startswith("TARGET_") and "|" in value:
            raise ValueError("%s cannot contain '|' (it breaks the markdown table)." % key)

    if "rk3588" not in out["TARGET_COMPATIBLE"].lower():
        raise ValueError(
            "Device-tree compatible value must identify RK3588, not '%s'."
            % out["TARGET_COMPATIBLE"]
        )

    arch = out["TARGET_ARCH"].lower()
    if arch not in ("arm64", "aarch64"):
        raise ValueError(
            "Target architecture must be arm64/aarch64, not '%s'."
            % out["TARGET_ARCH"]
        )
    out["TARGET_ARCH"] = "aarch64"

    sdk_root = out["SDK_ROOT"]
    if sdk_root.startswith("~"):
        sdk_root = os.path.expanduser(sdk_root)
    if not os.path.isabs(sdk_root):
        raise ValueError("SDK_ROOT must be an absolute path (got '%s')." % sdk_root)
    if sdk_root == os.path.sep:
        raise ValueError("SDK_ROOT cannot be the filesystem root.")
    sdk_root = os.path.normpath(sdk_root)
    if os.path.lexists(sdk_root):
        raise ValueError(
            "SDK path already exists and will not be modified: %s" % sdk_root
        )
    out["SDK_ROOT"] = sdk_root
    return out


def _read_os_release() -> dict:
    info = {}
    try:
        with open("/etc/os-release", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                info[key.strip()] = value.strip().strip('"').strip("'")
    except OSError:
        pass
    return info


def collect_host_info() -> dict:
    """Check host prerequisites and gather the toolchain metadata."""
    if platform.system() != "Linux" or platform.machine() != "x86_64":
        raise RuntimeError(
            "This tool expects a Linux amd64/x86_64 host; detected %s %s."
            % (platform.system(), platform.machine())
        )

    os_release = _read_os_release()
    host_os = os_release.get("PRETTY_NAME") or os_release.get("ID") or "unknown"
    host_version = os_release.get("VERSION_ID", "unknown")
    cross = os.environ.get("CROSS_COMPILE", CROSS_COMPILE_DEFAULT)
    commands = {
        "cc": os.environ.get("C_COMPILER", cross + "gcc"),
        "cxx": os.environ.get("CXX_COMPILER", cross + "g++"),
        "ar": os.environ.get("AR", cross + "ar"),
        "ranlib": os.environ.get("RANLIB", cross + "ranlib"),
        "strip": os.environ.get("STRIP", cross + "strip"),
        "readelf": os.environ.get("READELF", cross + "readelf"),
        "pkg_config": os.environ.get("PKG_CONFIG", "pkg-config"),
        "cmake": os.environ.get("CMAKE", "cmake"),
        "ninja": os.environ.get("NINJA", "ninja"),
    }
    labels = {
        "cc": "AArch64 C compiler",
        "cxx": "AArch64 C++ compiler",
        "ar": "AArch64 archiver",
        "ranlib": "AArch64 ranlib",
        "strip": "AArch64 strip",
        "readelf": "AArch64 readelf",
        "pkg_config": "pkg-config",
        "cmake": "CMake",
        "ninja": "Ninja",
    }
    resolved = {}
    for key, command in commands.items():
        found = shutil.which(command)
        if not found:
            raise RuntimeError(
                "Missing %s command '%s'. Install/configure it on the host, then rerun."
                % (labels[key], command)
            )
        resolved[key] = found

    def _run(args: list[str]) -> str:
        result = subprocess.run(
            args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, check=True,
        )
        return result.stdout.strip()

    machines = {}
    for key in ("cc", "cxx"):
        machine = _run([resolved[key], "-dumpmachine"])
        if "aarch64" not in machine or "linux" not in machine:
            raise RuntimeError(
                "%s target '%s' is not AArch64 Linux." % (labels[key], machine)
            )
        machines[key] = machine

    def _first_line(args: list[str]) -> str:
        output = _run(args)
        return output.splitlines()[0] if output else ""

    return {
        "host_os": host_os,
        "host_os_version": host_version,
        "host_arch": platform.machine(),
        **resolved,
        "cc_machine": machines["cc"],
        "cxx_machine": machines["cxx"],
        "cc_version": _first_line([resolved["cc"], "--version"]),
        "cxx_version": _first_line([resolved["cxx"], "--version"]),
    }


def _write(path: pathlib.Path, text: str) -> None:
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def build_workspace(values: dict, host: dict) -> pathlib.Path:
    """Create the SDK workspace atomically; never touch an existing path."""
    sdk_root = pathlib.Path(values["SDK_ROOT"])
    parent = sdk_root.parent
    name = sdk_root.name
    parent.mkdir(parents=True, exist_ok=True)
    temp = pathlib.Path(tempfile.mkdtemp(prefix=".%s.tmp." % name, dir=str(parent)))
    try:
        for sub in (
            "bin", "toolchains", "src", "build",
            "prefix/include", "prefix/lib", "metadata", "models",
        ):
            (temp / sub).mkdir(parents=True, exist_ok=True)

        quoted = {key: shlex.quote(host[key]) for key in
                  ("cc", "cxx", "ar", "ranlib", "strip", "pkg_config")}
        _write(
            temp / "env.sh",
            ENV_SH % (
                quoted["cc"], quoted["cxx"], quoted["ar"],
                quoted["ranlib"], quoted["strip"],
            ),
        )
        wrapper = temp / "bin/rk3588-pkg-config"
        _write(wrapper, PKG_CONFIG_WRAPPER % quoted["pkg_config"])
        wrapper.chmod(0o755)
        _write(
            temp / "toolchains/rk3588.cmake",
            CMAKE_TOOLCHAIN % (
                host["cc"], host["cxx"], host["ar"], host["ranlib"], host["strip"],
            ),
        )
        _write(
            temp / "metadata/host.txt",
            HOST_TXT % (
                host["host_os"], host["host_os_version"], host["host_arch"],
                host["cc"], host["cc_machine"], host["cc_version"],
                host["cxx"], host["cxx_machine"], host["cxx_version"],
                host["cmake"], host["ninja"], host["pkg_config"],
                host["readelf"],
            ),
        )
        target_fields = (
            values["TARGET_BOARD"], values["TARGET_COMPATIBLE"],
            values["TARGET_ARCH"], values["TARGET_OS"], values["TARGET_CODENAME"],
            values["TARGET_KERNEL"], values["TARGET_GLIBC"],
            values["TARGET_LIBSTDCXX"],
        )
        _write(temp / "metadata/target.txt", TARGET_TXT % target_fields)
        _write(temp / "metadata/target-baseline.md", TARGET_BASELINE_MD % target_fields)

        if os.path.lexists(str(sdk_root)):
            raise RuntimeError(
                "SDK destination appeared during setup; no existing files were "
                "overwritten: %s" % sdk_root
            )
        os.rename(str(temp), str(sdk_root))
        temp = None
        return sdk_root
    finally:
        if temp is not None and temp.exists():
            shutil.rmtree(str(temp), ignore_errors=True)


SUMMARY_TEMPLATE = """Review the setup configuration:

  Host OS:              %(host_os)s (%(host_os_version)s, %(host_arch)s)
  Target board:         %(TARGET_BOARD)s
  Device compatible:    %(TARGET_COMPATIBLE)s
  Target architecture:  %(TARGET_ARCH)s
  Target OS/codename:   %(TARGET_OS)s / %(TARGET_CODENAME)s
  Target kernel:        %(TARGET_KERNEL)s
  Target glibc:         %(TARGET_GLIBC)s
  Target libstdc++:     %(TARGET_LIBSTDCXX)s
  Cross C compiler:     %(cc)s (%(cc_machine)s)
  Cross C++ compiler:   %(cxx)s (%(cxx_machine)s)
  SDK workspace:        %(SDK_ROOT)s

Important: these board values are metadata only. The SDK will use the host
cross-compiler's built-in headers/libraries and will not match a target sysroot.
Third-party libraries (including RKNN and libdatachannel) are not installed.
"""


# ---------------------------------------------------------------------------
# GUI
# ---------------------------------------------------------------------------


def _load_bundled_fonts() -> None:
    """Register Google Roboto fonts for this Linux process, without installing them.

    Must run before Tk initialises its font cache.
    Regular and Bold assets are bundled for offline use.
    """
    if not sys.platform.startswith("linux"):
        return
    import ctypes
    import ctypes.util

    try:
        library = ctypes.util.find_library("fontconfig")
        if not library:
            return
        fontconfig = ctypes.CDLL(library)
        fontconfig.FcConfigGetCurrent.restype = ctypes.c_void_p
        fontconfig.FcConfigAppFontAddFile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        fontconfig.FcConfigAppFontAddFile.restype = ctypes.c_int
        config = fontconfig.FcConfigGetCurrent()
        if not config:
            return
        for path in sorted(pathlib.Path(__file__).resolve().with_name("fonts").glob("Roboto-*.ttf")):
            if not fontconfig.FcConfigAppFontAddFile(config, os.fsencode(path)):
                print(f"Could not load font: {path.name}", file=sys.stderr)
    except (OSError, AttributeError) as exc:
        print(f"Bundled fonts unavailable; using installed fonts: {exc}", file=sys.stderr)


def _maximize(window: tk.Tk | tk.Toplevel) -> None:
    """Ask the window manager to maximise, keeping native decorations."""
    window.overrideredirect(False)
    window.resizable(True, True)
    try:
        if window.tk.call("tk", "windowingsystem") == "x11":
            # EWMH state changes are asynchronous; do not immediately read back
            # the state and replace it with screen-sized client geometry.
            window.attributes("-zoomed", True)
        else:
            window.state("zoomed")
    except tk.TclError:
        # Keep the normal, decorated geometry when maximisation is unsupported.
        pass


def _place_half(parent: tk.Tk | tk.Toplevel, dialog: tk.Toplevel) -> None:
    """Sub-windows are half the size of the maximised main window."""
    parent.update_idletasks()
    parent_w = parent.winfo_width() or parent.winfo_screenwidth()
    parent_h = parent.winfo_height() or parent.winfo_screenheight()
    width = max(360, parent_w // 2)
    height = max(260, parent_h // 2)
    x = parent.winfo_rootx() + max(0, (parent_w - width) // 2)
    y = parent.winfo_rooty() + max(0, (parent_h - height) // 2)
    dialog.geometry("%dx%d+%d+%d" % (width, height, x, y))
    dialog.transient(parent)


class App:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.vars: dict[str, tk.StringVar] = {}
        self.status = tk.StringVar(
            value="Enter the target details, then choose Review & Create."
        )
        self._style()
        self._build()

    def _style(self) -> None:
        # python_gui_rules.md requires the Roboto Google font. Request it
        # unconditionally: checking tkfont.families() made a no-Xft Tk silently
        # fall back to the X core font "gothic", so the rule was never applied.
        self.font_family = "Roboto"
        if "Roboto" not in set(tkfont.families(self.root)):
            print(
                "Roboto is unavailable to Tk. Check the bundled fonts/ files "
                "and use ../automation with system Python and python3-tk "
                "(Xft support is required on Linux).",
                file=sys.stderr,
            )
        for name in ("TkDefaultFont", "TkTextFont", "TkMenuFont", "TkHeadingFont",
                     "TkCaptionFont", "TkSmallCaptionFont", "TkIconFont", "TkTooltipFont"):
            tkfont.nametofont(name, root=self.root).configure(
                family=self.font_family, size=11
            )
        self.root.option_add("*Font", "TkDefaultFont")
        style = ttk.Style(self.root)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        style.configure(".", font="TkDefaultFont")
        style.configure("Treeview", rowheight=30)
        style.configure("TFrame", background=BG_COLOR)
        style.configure("TLabel", background=BG_COLOR, foreground=FG_COLOR)

    def _button(self, parent: tk.Misc, text: str, command, width: int = 12) -> tk.Button:
        return tk.Button(
            parent, text=text, command=command, width=width,
            bg=BUTTON_COLOR, fg=BG_COLOR, activebackground="#5CE9F8",
            activeforeground=BG_COLOR, relief="flat", bd=0,
            font=(self.font_family, 10, "bold"), padx=10, pady=7,
            highlightthickness=1, highlightcolor=FG_COLOR,
        )

    def _dialog(self, title: str) -> tk.Toplevel:
        dialog = tk.Toplevel(self.root, bg=BG_COLOR)
        dialog.title(title)
        dialog.configure(bg=BG_COLOR)
        _place_half(self.root, dialog)
        dialog.bind("<Escape>", lambda event: dialog.destroy())
        return dialog

    def _build(self) -> None:
        self.root.title("RK3588 SDK environment (without sysroot)")
        self.root.configure(bg=BG_COLOR)
        self.root.geometry("1000x700")
        self.root.minsize(720, 480)
        self.root.after_idle(lambda: _maximize(self.root))
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)

        shell = ttk.Frame(self.root, padding=16)
        shell.grid(row=0, column=0, sticky="nsew")
        shell.columnconfigure(0, weight=1)
        shell.rowconfigure(2, weight=1)

        heading = tk.Label(
            shell,
            text="Create a standalone ARM64/Linux GNU cross-toolchain workspace",
            bg=BG_COLOR, fg=BUTTON_COLOR, font=(self.font_family, 16, "bold"),
        )
        heading.grid(row=0, column=0, sticky="w", pady=(0, 4))
        intro = tk.Label(
            shell,
            text="Run the shown commands ON THE TARGET BOARD. Every value is metadata only: "
                 "nothing is downloaded, installed or built, and no sysroot is created.",
            bg=BG_COLOR, fg=HINT_FG, wraplength=900, justify="left",
        )
        intro.grid(row=1, column=0, sticky="w", pady=(0, 12))
        shell.bind("<Configure>", lambda event: (
            heading.configure(wraplength=max(200, event.width - 48)),
            intro.configure(wraplength=max(200, event.width - 48)),
        ))

        canvas = tk.Canvas(shell, bg=BG_COLOR, highlightthickness=0)
        scroll = ttk.Scrollbar(shell, orient="vertical", command=canvas.yview)
        canvas.grid(row=2, column=0, sticky="nsew", padx=(0, 8))
        scroll.grid(row=2, column=1, sticky="ns")
        canvas.configure(yscrollcommand=scroll.set)

        form = tk.Frame(canvas, bg=BG_COLOR)
        form_id = canvas.create_window((0, 0), window=form, anchor="nw")
        canvas.bind("<Configure>", lambda event: canvas.itemconfigure(
            form_id, width=event.width
        ))
        form.columnconfigure(1, weight=1)
        form.bind(
            "<Configure>",
            lambda event: canvas.configure(scrollregion=canvas.bbox("all")),
        )
        def scroll_form(event):
            if event.widget.winfo_toplevel() != self.root:
                return
            direction = -1 if event.num == 4 or event.delta > 0 else 1
            canvas.yview_scroll(direction, "units")

        for sequence in ("<MouseWheel>", "<Button-4>", "<Button-5>"):
            self.root.bind(sequence, scroll_form, add="+")

        for row, spec in enumerate(FIELD_SPECS):
            label = tk.Label(
                form, text=spec["label"], bg=BG_COLOR, fg=FG_COLOR,
                font=(self.font_family, 10, "bold"),
            )
            label.grid(row=row, column=0, sticky="w", padx=(4, 10), pady=7)
            variable = tk.StringVar(value=spec["default"])
            self.vars[spec["key"]] = variable
            entry = tk.Entry(
                form, textvariable=variable, bg=ENTRY_BG, fg=FG_COLOR,
                insertbackground=FG_COLOR, relief="flat", bd=4,
            )
            entry.grid(row=row, column=1, sticky="ew", padx=6, pady=7)
            if spec["key"] == "SDK_ROOT":
                self._button(form, "Browse…", self.browse_sdk, width=10).grid(
                    row=row, column=2, padx=6, pady=7
                )
            self._button(
                form, "Help", lambda s=spec: self.show_field_help(s), width=8
            ).grid(row=row, column=3, padx=(10, 4), pady=7)

        actions = ttk.Frame(shell, padding=(0, 12, 0, 0))
        actions.grid(row=3, column=0, sticky="ew")
        self._button(actions, "Validate", self.on_validate).pack(
            side="left", padx=(4, 8), pady=4
        )
        self._button(actions, "Review & Create", self.on_review, width=18).pack(
            side="left", padx=8, pady=4
        )
        self._button(actions, "Full guide", self.show_full_guide).pack(
            side="left", padx=8, pady=4
        )
        self._button(actions, "Quit", self.root.destroy).pack(
            side="right", padx=(8, 4), pady=4
        )

        self.status_label = tk.Label(
            shell, textvariable=self.status, bg=BG_COLOR, fg=HINT_FG,
            wraplength=1000, justify="left", anchor="w",
        )
        self.status_label.grid(row=4, column=0, sticky="ew", pady=(6, 0))

    def browse_sdk(self) -> None:
        """Choose an existing parent and name a new, uncreated workspace."""
        dialog = self._dialog("Choose SDK workspace")
        dialog.columnconfigure(0, weight=1)
        dialog.rowconfigure(2, weight=1)
        candidate = pathlib.Path(os.path.expanduser(self.vars["SDK_ROOT"].get()))
        current = candidate.parent if candidate.is_absolute() else pathlib.Path.home()
        while not current.is_dir() and current != current.parent:
            current = current.parent
        location = tk.StringVar(value=str(current))
        name = tk.StringVar(value=candidate.name or pathlib.Path(SDK_DEFAULT).name)
        tk.Label(dialog, text="Choose a parent folder, then name the new SDK folder.",
                 bg=BG_COLOR, fg=FG_COLOR, anchor="w").grid(
                     row=0, column=0, sticky="ew", padx=16, pady=12)
        navigation = tk.Frame(dialog, bg=BG_COLOR)
        navigation.grid(row=1, column=0, sticky="ew", padx=16)
        navigation.columnconfigure(0, weight=1)
        path_entry = tk.Entry(navigation, textvariable=location, bg=ENTRY_BG,
                              fg=FG_COLOR, insertbackground=FG_COLOR)
        path_entry.grid(row=0, column=0, sticky="ew", padx=(0, 8))
        listing = ttk.Frame(dialog)
        listing.grid(row=2, column=0, sticky="nsew", padx=16, pady=12)
        listing.columnconfigure(0, weight=1)
        listing.rowconfigure(0, weight=1)
        tree = ttk.Treeview(listing, show="tree", selectmode="browse")
        tree.grid(row=0, column=0, sticky="nsew")
        scrollbar = ttk.Scrollbar(listing, command=tree.yview)
        scrollbar.grid(row=0, column=1, sticky="ns")
        tree.configure(yscrollcommand=scrollbar.set)
        folders = {}

        def navigate(path):
            nonlocal current
            try:
                path = pathlib.Path(path).expanduser().resolve(strict=True)
                children = sorted((p for p in path.iterdir() if p.is_dir()),
                                  key=lambda p: p.name.casefold())
            except OSError as exc:
                messagebox.showerror("Cannot open folder", str(exc), parent=dialog)
                return
            current = path
            location.set(str(path))
            tree.delete(*tree.get_children())
            folders.clear()
            for child in children:
                folders[tree.insert("", "end", text=child.name)] = child

        def open_selected(event=None):
            selection = tree.selection()
            if selection:
                navigate(folders[selection[0]])
            return "break"

        self._button(navigation, "Go", lambda: navigate(location.get()), 4).grid(
            row=0, column=1, padx=4)
        self._button(navigation, "Up", lambda: navigate(current.parent), 4).grid(
            row=0, column=2, padx=(4, 0))
        path_entry.bind("<Return>", lambda event: navigate(location.get()))
        tree.bind("<Double-1>", open_selected)
        tree.bind("<Return>", open_selected)
        footer = tk.Frame(dialog, bg=BG_COLOR)
        footer.grid(row=3, column=0, sticky="ew", padx=16, pady=(0, 12))
        footer.columnconfigure(1, weight=1)
        tk.Label(footer, text="New folder:", bg=BG_COLOR, fg=FG_COLOR).grid(
            row=0, column=0, padx=(0, 8))
        tk.Entry(footer, textvariable=name, bg=ENTRY_BG, fg=FG_COLOR,
                 insertbackground=FG_COLOR).grid(row=0, column=1, sticky="ew")

        def choose():
            folder_name = name.get().strip()
            if not folder_name or folder_name in (".", "..") or "/" in folder_name:
                messagebox.showerror("Invalid folder name", "Enter one new folder name.",
                                     parent=dialog)
                return
            destination = current / folder_name
            if os.path.lexists(destination):
                messagebox.showerror("Folder already exists",
                                     "Choose a new name; existing folders are never modified.",
                                     parent=dialog)
                return
            self.vars["SDK_ROOT"].set(str(destination))
            dialog.destroy()

        self._button(footer, "Use path", choose, 10).grid(row=1, column=1,
                                                        sticky="e", pady=(12, 0))
        self._button(footer, "Cancel", dialog.destroy, 8).grid(
            row=1, column=0, sticky="w", pady=(12, 0))
        navigate(current)
        dialog.wait_visibility()
        dialog.grab_set()
        path_entry.focus_set()

    def _values(self) -> dict:
        return {key: var.get() for key, var in self.vars.items()}

    def _set_status(self, message: str, error: bool = False) -> None:
        self.status.set(message)
        self.status_label.configure(fg=ERROR_FG if error else HINT_FG)

    def on_validate(self) -> bool:
        try:
            values = validate_values(self._values())
        except ValueError as exc:
            self._set_status("Validation failed: %s" % exc, error=True)
            messagebox.showerror("Validation failed", str(exc), parent=self.root)
            return False
        self._set_status("Validated. SDK workspace: %s" % values["SDK_ROOT"])
        return True

    def show_field_help(self, spec: dict) -> None:
        dialog = self._dialog("Help - " + spec["label"])
        dialog.title("Help - " + spec["key"])
        tk.Label(
            dialog, text=spec["label"], bg=BG_COLOR, fg=BUTTON_COLOR,
            font=(self.font_family, 13, "bold"),
        ).pack(anchor="w", padx=16, pady=(16, 10))
        text = ScrolledText(dialog, bg=ENTRY_BG, fg=FG_COLOR, wrap="word",
                            relief="flat", padx=10, pady=10)
        text.pack(fill="both", expand=True, padx=16, pady=4)
        for tag, line in spec["help"]:
            text.insert("end", f"{tag} {line}\n\n")
        text.configure(state="disabled")
        self._button(dialog, "Close", dialog.destroy, width=10).pack(
            anchor="e", padx=16, pady=12
        )

    def show_full_guide(self) -> None:
        dialog = self._dialog("Full field guide")
        text = ScrolledText(
            dialog, bg=ENTRY_BG, fg=FG_COLOR, wrap="word", relief="flat", bd=4
        )
        text.pack(fill="both", expand=True, padx=16, pady=16)
        guide = [
            "HOW TO COLLECT EVERY PROMPTED VALUE",
            "",
            "Run each 'On target' command on the TARGET BOARD (RK3588), not on the build host.",
            "Enter only the value, not the label and not the whole command.",
            "Every target value is metadata only: nothing here downloads, installs or configures",
            "the compiler. Use 'unknown' when unavailable; compatible, architecture and SDK path",
            "are checked.",
            "",
        ]
        for index, spec in enumerate(FIELD_SPECS, 1):
            guide.append("%d) %s [%s]" % (index, spec["label"], spec["key"]))
            for tag, line in spec["help"]:
                guide.append("   %s %s" % (tag, line) if tag else "   %s" % line)
            guide.append("")
        text.insert("1.0", "\n".join(guide))
        text.configure(state="disabled")
        self._button(dialog, "Close", dialog.destroy, width=10).pack(
            anchor="e", padx=16, pady=(0, 16)
        )

    def on_review(self) -> None:
        if not self.on_validate():
            return
        values = validate_values(self._values())
        try:
            host = collect_host_info()
        except (RuntimeError, subprocess.CalledProcessError, OSError) as exc:
            self._set_status("Host check failed: %s" % exc, error=True)
            messagebox.showerror("Host check failed", str(exc), parent=self.root)
            return

        dialog = self._dialog("Review configuration")
        summary = SUMMARY_TEMPLATE % {**values, **host}
        tk.Label(
            dialog, text="Review the setup configuration:", bg=BG_COLOR,
            fg=BUTTON_COLOR, font=(self.font_family, 13, "bold"),
        ).pack(anchor="w", padx=16, pady=(16, 8))
        summary_text = ScrolledText(dialog, bg=ENTRY_BG, fg=FG_COLOR,
                                    wrap="word", height=8, relief="flat")
        summary_text.pack(fill="both", expand=True, padx=16)
        summary_text.insert("1.0", summary)
        summary_text.configure(state="disabled")

        confirm_row = tk.Frame(dialog, bg=BG_COLOR)
        confirm_row.pack(fill="x", padx=16, pady=12)
        tk.Label(
            confirm_row, text="Type yes to continue:", bg=BG_COLOR, fg=HINT_FG,
        ).pack(side="left", padx=(0, 8))
        answer = tk.StringVar()
        entry = tk.Entry(
            confirm_row, textvariable=answer, bg=ENTRY_BG, fg=FG_COLOR,
            insertbackground=FG_COLOR, relief="flat", bd=4, width=10,
        )
        entry.pack(side="left")
        entry.focus_set()

        def confirm() -> None:
            if answer.get().strip() != "yes":
                messagebox.showerror(
                    "Cancelled", "Type yes to create the workspace. Nothing was created.",
                    parent=dialog,
                )
                return
            dialog.destroy()
            self._start_build(values)

        self._button(dialog, "Create workspace", confirm, width=18).pack(
            side="left", padx=12
        )
        self._button(dialog, "Cancel", dialog.destroy, width=10).pack(side="left")
        dialog.bind("<Return>", lambda event: confirm())

    def _start_build(self, values: dict) -> None:
        self._set_status("Creating SDK workspace...")
        self.root.config(cursor="watch")
        result_queue: queue.Queue = queue.Queue()

        def worker() -> None:
            try:
                host = collect_host_info()
                path = build_workspace(values, host)
                result_queue.put(("ok", str(path)))
            except Exception as exc:  # noqa: BLE001 - report any failure in the GUI
                result_queue.put(("error", str(exc)))

        threading.Thread(target=worker, daemon=True).start()
        self._poll(result_queue)

    def _poll(self, result_queue: queue.Queue) -> None:
        try:
            kind, payload = result_queue.get_nowait()
        except queue.Empty:
            self.root.after(100, lambda: self._poll(result_queue))
            return
        self.root.config(cursor="")
        if kind == "ok":
            self._set_status("SDK environment created: %s" % payload)
            self._show_success(payload)
        else:
            self._set_status("Creation failed: %s" % payload, error=True)
            messagebox.showerror("Creation failed", payload, parent=self.root)

    def _show_success(self, path: str) -> None:
        dialog = self._dialog("SDK environment created")
        tk.Label(
            dialog, text="SDK environment created", bg=BG_COLOR, fg="#7BE3A3",
            font=(self.font_family, 14, "bold"),
        ).pack(anchor="w", padx=16, pady=(16, 8))
        tk.Label(
            dialog,
            text="%s\n\nActivate in this terminal with:\n  source \"%s/env.sh\"\n\n"
                 "Build a smoke-test project by following "
                 "README/08_build_smoke_test_project.md." % (path, path),
            bg=BG_COLOR, fg=FG_COLOR, justify="left", anchor="w", wraplength=520,
        ).pack(fill="x", padx=16, pady=8)
        self._button(dialog, "Close", dialog.destroy, width=10).pack(
            anchor="e", padx=16, pady=12
        )


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if argv:
        if argv[0] in ("-h", "--help"):
            print((__doc__ or "").strip())
            print("\nRun without arguments to open the GUI.")
            return 0
        print("Unknown option: %s (use --help)." % argv[0], file=sys.stderr)
        return 2
    _load_bundled_fonts()
    root = tk.Tk()
    App(root)
    root.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
