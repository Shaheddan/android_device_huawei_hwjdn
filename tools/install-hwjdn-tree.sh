#!/usr/bin/env bash
# install-hwjdn-tree.sh  (rev 5 -- diag service class fixed to `default`)
#     ./install-hwjdn-tree.sh ~/android/twrp11 ~/android/jdn/stock [kernel]
set -euo pipefail
TWRP="${1:-$HOME/android/twrp11}"
STOCK="${2:-$HOME/android/jdn/stock}"
KERNEL="${3:-$HOME/android/references/kiwi-twrp11/prebuilt/Image}"
DEV="$TWRP/device/huawei/hwjdn"
[ -d "$TWRP/build" ] || { echo "ERROR: $TWRP is not an Android source tree." >&2; exit 1; }
[ -f "$STOCK/unpacked_recovery/dt.img" ] || { echo "ERROR: dt.img missing." >&2; exit 1; }
[ -f "$KERNEL" ] || { echo "ERROR: kernel not found: $KERNEL" >&2; exit 1; }
echo "==> clearing any previous tree"
rm -rf "$DEV"; mkdir -p "$DEV"

cat > "$DEV/Android.mk" <<'__HWJDN_EOF__'
LOCAL_PATH := $(call my-dir)

# The guard stops hwjdn's subdir makefiles being parsed for every lunch target
# in the checkout -- which on a tree shared with kiwi produces duplicate-module
# errors pointing at the wrong device entirely.
ifeq ($(TARGET_DEVICE),hwjdn)
include $(call all-subdir-makefiles,$(LOCAL_PATH))
endif
__HWJDN_EOF__
echo "    Android.mk"

cat > "$DEV/AndroidProducts.mk" <<'__HWJDN_EOF__'
# The file the build scans to discover the product. If `lunch twrp_hwjdn-eng`
# reports "product not found", check HERE first, not BoardConfig.mk.

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/twrp_hwjdn.mk

COMMON_LUNCH_CHOICES := \
    twrp_hwjdn-eng \
    twrp_hwjdn-userdebug
__HWJDN_EOF__
echo "    AndroidProducts.mk"

cat > "$DEV/BoardConfig.mk" <<'__HWJDN_EOF__'
#
# BoardConfig.mk -- Huawei MediaPad T2 8.0 Pro (JDN-L01, device hwjdn)
# TWRP on the twrp-11 (Android 11) branch. MSM8939v2 / Adreno 405 / kernel 3.10.
#
# Structure follows mohammadsa9's kiwi tree, which ships a WORKING TWRP 3.7 on
# this same SoC. Every VALUE, however, comes from hwjdn's own stock RECOVERY.img
# header and live-device dumps. Where the two disagree, hwjdn's own data wins --
# a reference tells you what to look at, never what to change.
#

LOCAL_PATH := device/huawei/hwjdn

# ---- Platform --------------------------------------------------------------
# ro.board.platform reads exactly "msm8916" on the device -- the AOSP platform
# directory name for the whole 8916/8939 family.
TARGET_BOARD_PLATFORM     := msm8916
TARGET_BOARD_PLATFORM_GPU := qcom-adreno405
BOARD_USES_QCOM_HARDWARE  := true

# ---- Bootloader ------------------------------------------------------------
TARGET_BOOTLOADER_BOARD_NAME := MSM8916
TARGET_NO_BOOTLOADER         := true
TARGET_OTA_ASSERT_DEVICE     := hwjdn

# ---- Architecture ----------------------------------------------------------
# /proc/cpuinfo: 8x CPU part 0xd03 (Cortex-A53) rev 4, aarch64.
TARGET_ARCH             := arm64
TARGET_ARCH_VARIANT     := armv8-a
TARGET_CPU_ABI          := arm64-v8a
TARGET_CPU_ABI2         :=
TARGET_CPU_VARIANT      := cortex-a53

TARGET_2ND_ARCH         := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI      := armeabi-v7a
TARGET_2ND_CPU_ABI2     := armeabi
TARGET_2ND_CPU_VARIANT  := cortex-a53

# ---- Kernel ----------------------------------------------------------------
# ALL FOUR VERIFIED from hwjdn's stock RECOVERY.img header (BOOT.img agrees).
# The reference tree uses pagesize 4096, ramdisk_offset 0x02000000 and
# tags_offset 0x01E00000 -- those are KIWI's. Do not copy them.
BOARD_KERNEL_BASE     := 0x80000000
BOARD_KERNEL_PAGESIZE := 2048

# Stock cmdline verbatim, with the single deliberate change enforcing ->
# permissive because this is a recovery. There is NO console= and no
# androidboot.console= on this device; `earlyprintk` is what stock uses.
BOARD_KERNEL_CMDLINE := androidboot.hardware=qcom msm_rtb.filter=0x237 ehci-hcd.park=3 androidboot.bootdevice=7824900.sdhci lpm_levels.sleep_disabled=1 earlyprintk androidboot.selinux=permissive

BOARD_MKBOOTIMG_ARGS := --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --tags_offset 0x00000100

# 17,852,440 bytes is far too large for a compressed Image.gz. The reference
# tree confirms the same platform ships an uncompressed arm64 `Image`.
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_DT_IMAGE_NAME     := dt.img

# Replaces AOSP's boot-image rule with one that calls the bundled legacy
# mkbootimg.py, because AOSP's mkbootimg has no --dt. See mkbootimg/mkbootimg.mk.
BOARD_CUSTOM_BOOTIMG_MK := $(LOCAL_PATH)/mkbootimg/mkbootimg.mk

# Phase 1a: both lifted from stock RECOVERY.img, so panel/touch/eMMC init is
# already known-good and the first boot tests only TWRP.
TARGET_FORCE_PREBUILT_KERNEL := true
INSTALLED_DTIMAGE_TARGET     := $(LOCAL_PATH)/prebuilt/$(BOARD_DT_IMAGE_NAME)
TARGET_PREBUILT_KERNEL       := $(LOCAL_PATH)/prebuilt/$(BOARD_KERNEL_IMAGE_NAME)

# ---- Partitions ------------------------------------------------------------
# Sizes from /sys/block/mmcblk0/mmcblk0pNN/size, cross-checked against
# /proc/partitions. All 26 partitions agreed.
BOARD_FLASH_BLOCK_SIZE             := 131072
BOARD_BOOTIMAGE_PARTITION_SIZE     := 67108864     # p19 boot,     64 MB
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 67108864     # p20 recovery, 64 MB
BOARD_SYSTEMIMAGE_PARTITION_SIZE   := 2952790016   # p24 system,   2.75 GB
BOARD_USERDATAIMAGE_PARTITION_SIZE := 11345575424  # p26 userdata, 10.57 GB
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# ---- Recovery --------------------------------------------------------------
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
RECOVERY_VARIANT             := twrp
RECOVERY_SDCARD_ON_DATA      := true
TARGET_RECOVERY_QCOM_RTC_FIX := true
BOARD_HAS_NO_SELECT_BUTTON   := true

# NOTE: TARGET_RECOVERY_FSTAB is deliberately NOT set. On Android 11 the fstab
# pair ships inside the recovery ramdisk at /system/etc/{recovery.fstab,
# twrp.flags}. The previous revision used the Android 9 layout and put it at
# /etc/twrp.fstab, which A11 never reads.

# ---- TWRP: display ---------------------------------------------------------
# VERIFIED: fb0/modes = "U:1200x1920p-0". virtual_size reads "1200,3840"
# because 3840 is the double-buffered VIRTUAL height, not a panel dimension --
# do not "correct" 1200x1920 to 1200x3840.
# Panel: INX_NT51021_8_1200P_VIDEO. ro.sf.lcd_density = 320 (xhdpi).
DEVICE_RESOLUTION := 1200x1920
TW_THEME          := portrait_hdpi

# ---- TWRP: backlight -------------------------------------------------------
# VERIFIED present, max_brightness reads 255. /sys/class/backlight/ does not exist.
TW_BRIGHTNESS_PATH    := /sys/class/leds/lcd-backlight/brightness
TW_MAX_BRIGHTNESS     := 255
TW_DEFAULT_BRIGHTNESS := 150

# ---- TWRP: input -----------------------------------------------------------
# The reference blacklists "accelerometer" -- that is the device NAME on kiwi.
# hwjdn's /proc/bus/input/devices reports the accelerometer as "bma2x2-accel"
# (event1), so the literal string must differ or the blacklist matches nothing.
# There is NO hbtp_vm device on hwjdn, so it is not listed. The real digitiser
# is event5, "huawei,touchscreen"; power is event0, volume keys event6.
TW_INPUT_BLACKLIST := bma2x2-accel

# ---- TWRP: behaviour -------------------------------------------------------
TW_DEFAULT_LANGUAGE  := en
TW_EXTRA_LANGUAGES   := true
TW_USE_TOOLBOX       := true
TW_INCLUDE_NTFS_3G   := true
TW_NO_EXFAT_FUSE     := true
TW_EXCLUDE_SUPERSU   := true
TW_SCREEN_BLANK_ON_BOOT := true

# Non-Treble Marshmallow-era device: no APEX anywhere, and the ramdisk shares
# 64 MB with a 17.85 MB kernel and a 22.48 MB DT blob.
TW_EXCLUDE_APEX := true

# ---- Vold ------------------------------------------------------------------
TARGET_USE_CUSTOM_LUN_FILE_PATH := /sys/devices/platform/msm_hsusb/gadget/lun%d/file

# ---- Crypto ----------------------------------------------------------------
# OFF for the first boot. ro.crypto.type=block (FDE, not FBE) and
# fs_crypto_blkdev=/dev/block/dm-2. Enabling it needs stock qseecomd +
# libQSEEComAPI.so + keymaster blobs staged into the ramdisk, which would give a
# failed boot three suspects instead of one. Expect /data to show as
# unmountable on the first boot -- that is correct, not a bug.
# TW_INCLUDE_CRYPTO     := true
# TW_INCLUDE_CRYPTO_FBE := false
# TW_CRYPTO_FS_TYPE     := "ext4"
# TW_CRYPTO_REAL_BLKDEV := "/dev/block/bootdevice/by-name/userdata"
# TW_CRYPTO_MNT_POINT   := "/data"

# ---- Build workarounds -----------------------------------------------------
TARGET_KERNEL_CLANG_COMPILE := false
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_DUP_RULES := true
__HWJDN_EOF__
echo "    BoardConfig.mk"

cat > "$DEV/device.mk" <<'__HWJDN_EOF__'
# Screen density -- ro.sf.lcd_density reads 320 on the live device (xhdpi).
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xhdpi

# Display. VERIFIED: /sys/class/graphics/fb0/modes = "U:1200x1920p-0".
# Portrait-native, so width 1200 / height 1920 -- NOT the reference tree's
# 1080x1920, which is kiwi's phone panel.
TARGET_SCREEN_WIDTH  := 1200
TARGET_SCREEN_HEIGHT := 1920

# The recovery ramdisk contents. In Android 11 the recovery root has a /system
# directory, so the fstab pair lives at /system/etc -- NOT /etc as on Android 9.
PRODUCT_COPY_FILES += \
    device/huawei/hwjdn/recovery/root/init.recovery.qcom.rc:recovery/root/init.recovery.qcom.rc \
    device/huawei/hwjdn/recovery/root/ueventd.qcom.rc:recovery/root/ueventd.qcom.rc \
    device/huawei/hwjdn/recovery/root/system/etc/recovery.fstab:recovery/root/system/etc/recovery.fstab \
    device/huawei/hwjdn/recovery/root/system/etc/twrp.flags:recovery/root/system/etc/twrp.flags
__HWJDN_EOF__
echo "    device.mk"

mkdir -p "$DEV/mkbootimg"
cat > "$DEV/mkbootimg/mkbootimg.mk" <<'__HWJDN_EOF__'
# Custom boot image rule for hwjdn.
#
# WHY THIS FILE EXISTS
#   Android 11's mkbootimg is pure AOSP and has no `--dt`. That flag is the
#   Qualcomm/CAF extension that writes dt_size into the legacy v0 boot header.
#   AOSP's `--dtb` is NOT an equivalent -- it is a header v2 field for a
#   different mechanism, and a v2 image is unparseable by a 2016 bootloader.
#
#   BOARD_CUSTOM_BOOTIMG_MK is AOSP's sanctioned hook for replacing the boot
#   image rule outright, so we point it here and call the bundled legacy
#   mkbootimg.py instead. Adapted from mohammadsa9's kiwi tree, which uses
#   exactly this approach to ship a working TWRP 11 on the same SoC.

# INSTALLED_DTIMAGE_TARGET is set in BoardConfig.mk for the Phase 1a prebuilt,
# so this branch is skipped. It only fires in Phase 1b, once a kernel source
# tree exists and dt.img is generated from its dts.
ifeq ($(INSTALLED_DTIMAGE_TARGET),)
INSTALLED_DTIMAGE_TARGET := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ/arch/$(TARGET_KERNEL_ARCH)/boot/$(BOARD_DT_IMAGE_NAME)
$(INSTALLED_DTIMAGE_TARGET): $(INSTALLED_KERNEL_TARGET)
	$(call pretty,"Target dt image: $@")
	$(call make-kernel-target,$(BOARD_DT_IMAGE_NAME))
endif

BOARD_MKBOOTIMG_ARGS += --dt $(INSTALLED_DTIMAGE_TARGET)

MKBOOTIMG_OLD := $(call my-dir)/mkbootimg.py

$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG_OLD) $(INTERNAL_BOOTIMAGE_FILES) $(INSTALLED_DTIMAGE_TARGET)
	$(call pretty,"Target boot image: $@")
	$(hide) $(MKBOOTIMG_OLD) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@
	$(hide) $(call assert-max-image-size,$@,$(BOARD_BOOTIMAGE_PARTITION_SIZE))

$(INSTALLED_RECOVERYIMAGE_TARGET): $(MKBOOTIMG_OLD) $(INSTALLED_DTIMAGE_TARGET) \
		$(recovery_ramdisk) \
		$(recovery_kernel)
	$(call pretty,"Target recovery image: $@")
	$(hide) $(MKBOOTIMG_OLD) $(INTERNAL_RECOVERYIMAGE_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@
	$(hide) $(call assert-max-image-size,$@,$(BOARD_RECOVERYIMAGE_PARTITION_SIZE))
__HWJDN_EOF__
echo "    mkbootimg/mkbootimg.mk"

mkdir -p "$DEV/mkbootimg"
cat > "$DEV/mkbootimg/mkbootimg.py" <<'__HWJDN_EOF__'
#!/usr/bin/env python
# Copyright 2015, The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from __future__ import print_function
from sys import argv, exit, stderr
from argparse import ArgumentParser, FileType, Action
from os import fstat
from struct import pack
from hashlib import sha1
import sys
import re

def filesize(f):
    if f is None:
        return 0
    try:
        return fstat(f.fileno()).st_size
    except OSError:
        return 0


def update_sha(sha, f):
    if f:
        sha.update(f.read())
        f.seek(0)
        sha.update(pack('I', filesize(f)))
    else:
        sha.update(pack('I', 0))


def pad_file(f, padding):
    pad = (padding - (f.tell() & (padding - 1))) & (padding - 1)
    f.write(pack(str(pad) + 'x'))


def write_header(args):
    BOOT_MAGIC = 'ANDROID!'.encode()
    args.output.write(pack('8s', BOOT_MAGIC))
    args.output.write(pack('10I',
        filesize(args.kernel),                          # size in bytes
        args.base + args.kernel_offset,                 # physical load addr
        filesize(args.ramdisk),                         # size in bytes
        args.base + args.ramdisk_offset,                # physical load addr
        filesize(args.second),                          # size in bytes
        args.base + args.second_offset,                 # physical load addr
        args.base + args.tags_offset,                   # physical addr for kernel tags
        args.pagesize,                                  # flash page size we assume
        filesize(args.dt),                              # size in bytes
        (args.os_version << 11) | args.os_patch_level)) # os version and patch level
    args.output.write(pack('16s', args.board.encode())) # asciiz product name
    args.output.write(pack('512s', args.cmdline[:512].encode()))

    sha = sha1()
    update_sha(sha, args.kernel)
    update_sha(sha, args.ramdisk)
    update_sha(sha, args.second)
    update_sha(sha, args.dt)
    img_id = pack('32s', sha.digest())

    args.output.write(img_id)
    args.output.write(pack('1024s', args.cmdline[512:].encode()))
    pad_file(args.output, args.pagesize)
    return img_id


class ValidateStrLenAction(Action):
    def __init__(self, option_strings, dest, nargs=None, **kwargs):
        if 'maxlen' not in kwargs:
            raise ValueError('maxlen must be set')
        self.maxlen = int(kwargs['maxlen'])
        del kwargs['maxlen']
        super(ValidateStrLenAction, self).__init__(option_strings, dest, **kwargs)

    def __call__(self, parser, namespace, values, option_string=None):
        if len(values) > self.maxlen:
            raise ValueError('String argument too long: max {0:d}, got {1:d}'.
                format(self.maxlen, len(values)))
        setattr(namespace, self.dest, values)


def write_padded_file(f_out, f_in, padding):
    if f_in is None:
        return
    f_out.write(f_in.read())
    pad_file(f_out, padding)


def parse_int(x):
    return int(x, 0)

def parse_os_version(x):
    match = re.search(r'^(\d{1,3})(?:\.(\d{1,3})(?:\.(\d{1,3}))?)?', x)
    if match:
        a = int(match.group(1))
        b = c = 0
        if match.lastindex >= 2:
            b = int(match.group(2))
        if match.lastindex == 3:
            c = int(match.group(3))
        # 7 bits allocated for each field
        assert a < 128
        assert b < 128
        assert c < 128
        return (a << 14) | (b << 7) | c
    return 0

def parse_os_patch_level(x):
    match = re.search(r'^(\d{4})-(\d{2})-(\d{2})', x)
    if match:
        y = int(match.group(1)) - 2000
        m = int(match.group(2))
        # 7 bits allocated for the year, 4 bits for the month
        assert y >= 0 and y < 128
        assert m > 0 and m <= 12
        return (y << 4) | m
    return 0

def parse_cmdline():
    parser = ArgumentParser()
    parser.add_argument('--kernel', help='path to the kernel', type=FileType('rb'),
                        required=True)
    parser.add_argument('--ramdisk', help='path to the ramdisk', type=FileType('rb'))
    parser.add_argument('--second', help='path to the 2nd bootloader', type=FileType('rb'))
    parser.add_argument('--cmdline', help='extra arguments to be passed on the '
                        'kernel command line', default='', action=ValidateStrLenAction, maxlen=1536)
    parser.add_argument('--base', help='base address', type=parse_int, default=0x10000000)
    parser.add_argument('--kernel_offset', help='kernel offset', type=parse_int, default=0x00008000)
    parser.add_argument('--ramdisk_offset', help='ramdisk offset', type=parse_int, default=0x01000000)
    parser.add_argument('--second_offset', help='2nd bootloader offset', type=parse_int,
                        default=0x00f00000)
    parser.add_argument('--os_version', help='operating system version', type=parse_os_version,
                        default=0)
    parser.add_argument('--os_patch_level', help='operating system patch level',
                        type=parse_os_patch_level, default=0)
    parser.add_argument('--tags_offset', help='tags offset', type=parse_int, default=0x00000100)
    parser.add_argument('--board', help='board name', default='', action=ValidateStrLenAction,
                        maxlen=16)
    parser.add_argument('--pagesize', help='page size', type=parse_int,
                        choices=[2**i for i in range(11,18)], default=2048)
    parser.add_argument('--id', help='print the image ID on standard output',
                        action='store_true')
    parser.add_argument('--dt', help='path to the device tree image', type=FileType('rb'))
    parser.add_argument('-o', '--output', help='output file name', type=FileType('wb'),
                        required=True)
    return parser.parse_args()


def write_data(args):
    write_padded_file(args.output, args.kernel, args.pagesize)
    write_padded_file(args.output, args.ramdisk, args.pagesize)
    write_padded_file(args.output, args.second, args.pagesize)
    write_padded_file(args.output, args.dt, args.pagesize)


def main():
    args = parse_cmdline()
    img_id = write_header(args)
    write_data(args)
    if args.id:
        if isinstance(img_id, str):
            # Python 2's struct.pack returns a string, but py3 returns bytes.
            img_id = [ord(x) for x in img_id]
        print('0x' + ''.join('{:02x}'.format(c) for c in img_id))

if __name__ == '__main__':
    main()
__HWJDN_EOF__
chmod +x "$DEV/mkbootimg/mkbootimg.py"
echo "    mkbootimg/mkbootimg.py"

mkdir -p "$DEV/recovery/root"
cat > "$DEV/recovery/root/init.recovery.qcom.rc" <<'__HWJDN_EOF__'
# init.recovery.qcom.rc -- Huawei MediaPad T2 8.0 Pro (hwjdn)
#
# Filename verified: ro.hardware = "qcom" (from androidboot.hardware=qcom on the
# stock kernel cmdline), so init sources this exact name.

on fs
    # *** THE MOST IMPORTANT FOUR LINES IN THIS TREE ***
    # On these legacy Qualcomm devices the /dev/block/bootdevice symlink is NOT
    # created automatically in recovery. Without it EVERY by-name path in
    # recovery.fstab and twrp.flags resolves to nothing -- TWRP comes up unable
    # to mount a single partition, or does not come up at all.
    # ro.boot.bootdevice is 7824900.sdhci on hwjdn (verified), and the sysfs
    # tree confirms the soc.0 parent (e.g. /sys/devices/soc.0/78b6000.i2c/...).
    wait /dev/block/platform/soc.0/${ro.boot.bootdevice}
    symlink /dev/block/platform/soc.0/${ro.boot.bootdevice} /dev/block/bootdevice

    # adb inside recovery on a 3.10 kernel needs the legacy FunctionFS path.
    # Without these adbd comes up but never enumerates, which leaves no way to
    # read /tmp/recovery.log when the screen is the thing that is broken.
    setprop sys.usb.ffs.aio_compat 1
    setprop persist.adb.nonblocking_ffs 0
    setprop ro.adb.nonblocking_ffs 0

on early-init
    # VERIFIED path; max_brightness reads 255. TWRP writes brightness before its
    # UI comes up, so if this node is not writable by then the screen stays dark
    # while TWRP runs perfectly well -- adb responds and it looks bricked.
    chown system system /sys/class/leds/lcd-backlight/brightness
    chmod 0666 /sys/class/leds/lcd-backlight/brightness

on init
    # event5 is the digitiser ("huawei,touchscreen"), event0 the power key,
    # event6 the volume keys. Covering 0-8 costs nothing and removes a whole
    # class of "touch is dead" false diagnosis.
    chmod 0666 /dev/input/event0
    chmod 0666 /dev/input/event1
    chmod 0666 /dev/input/event2
    chmod 0666 /dev/input/event3
    chmod 0666 /dev/input/event4
    chmod 0666 /dev/input/event5
    chmod 0666 /dev/input/event6
    chmod 0666 /dev/input/event7
    chmod 0666 /dev/input/event8

on boot
    write /sys/class/graphics/fb0/blank 0

# ---------------------------------------------------------------------------
# Persistent diagnostic dump.
#
# REV 3. Revs 1 and 2 never ran, and the cause is now READ FROM THE SOURCE
# rather than guessed. bootable/recovery/etc/init.rc line 74 contains the ONLY
# class_start in the entire recovery tree:
#
#     on boot
#         class_start default
#
# So `class late_start` (rev 1) and `class core` (rev 2) are never started by
# anything. Only `default` is. The kiwi reference's vm_bms service also uses
# `class core`, which means it is dead code there too -- copying it was the
# error. A service with no class line at all defaults to `default`; it is
# spelled out here so the next person does not have to rediscover this.
#
# REMOVE once TWRP works -- this is a debugging aid, not a feature.
service jdn-diag /system/bin/sh /system/bin/jdn_diag.sh
    class default
    user root
    group root
    oneshot
__HWJDN_EOF__
echo "    recovery/root/init.recovery.qcom.rc"

mkdir -p "$DEV/recovery/root/system/bin"
cat > "$DEV/recovery/root/system/bin/jdn_diag.sh" <<'__HWJDN_EOF__'
#!/system/bin/sh
#
# jdn_diag.sh -- dump recovery diagnostics somewhere that survives a reboot.
#
# REV 2. Rev 1 produced nothing. Two defects, both fixed here:
#   1. It began with `exec >/tmp/... 2>&1`. init starts this service early, and
#      if /tmp does not exist yet that redirect fails and the shell exits
#      immediately -- before even reaching the sleep. No redirect now; the
#      script writes its own trace only after it has somewhere to write it.
#   2. Its init service was `disabled` and depended on triggers that recovery
#      does not reliably fire. Now `class core`, started automatically.
#
# Targets, most convenient first:
#   1. microSD  /dev/block/mmcblk1p1  -- readable in any card reader, no adb
#   2. /log     /dev/block/mmcblk0p17 -- pullable from stock with `adb pull /log`
#
# RAW NODES, NOT by-name, on purpose: if the /dev/block/bootdevice symlink is
# what is broken, by-name resolves to nothing -- and that is one of the things
# this dump exists to determine.

# Give TWRP time to parse the fstab, probe partitions and settle. Also covers
# starting this service early from class core.
sleep 25

MNT=/tmp/jdn_dump
OUT=""
mkdir -p "$MNT" 2>/dev/null

for DEV in /dev/block/mmcblk1p1 /dev/block/mmcblk0p17; do
    umount "$MNT" 2>/dev/null
    if mount -t vfat -o rw "$DEV" "$MNT" 2>/dev/null; then
        if mkdir -p "$MNT/jdn-diag" 2>/dev/null; then
            OUT="$MNT/jdn-diag"
            break
        fi
    fi
done

# If neither mounted, leave it in tmpfs -- worthless on its own, but it proves
# the service ran, which is the thing rev 1 could not distinguish.
if [ -z "$OUT" ]; then
    OUT=/tmp/jdn-diag
    mkdir -p "$OUT" 2>/dev/null
fi

# Written FIRST, so its mere existence answers "did this thing even start?"
echo "jdn-diag rev2 ran; target=$OUT" > "$OUT/_ITRAN.txt" 2>&1
date >> "$OUT/_ITRAN.txt" 2>&1

# --- the file that answers the display question ----------------------------
dmesg                                         > "$OUT/dmesg.txt"      2>&1

# --- did TWRP itself get anywhere? -----------------------------------------
cat /tmp/recovery.log                         > "$OUT/recovery.log"   2>&1

# --- did the bootdevice symlink and fstab work? ----------------------------
ls -la /dev/block/bootdevice/by-name/         > "$OUT/byname.txt"     2>&1
ls -la /dev/block/                            > "$OUT/devblock.txt"   2>&1
ls -la /dev/block/platform/soc.0/             > "$OUT/platform.txt"   2>&1
mount                                         > "$OUT/mount.txt"      2>&1
cat /proc/partitions                          > "$OUT/partitions.txt" 2>&1

# --- display state ----------------------------------------------------------
ls -la /dev/graphics/                         > "$OUT/graphics.txt"   2>&1
ls -la /sys/class/graphics/                   >> "$OUT/graphics.txt"  2>&1
cat /sys/class/graphics/fb0/modes             > "$OUT/fb0.txt"        2>&1
cat /sys/class/graphics/fb0/virtual_size      >> "$OUT/fb0.txt"       2>&1
cat /sys/class/graphics/fb0/msm_fb_panel_info >> "$OUT/fb0.txt"       2>&1

# --- general ----------------------------------------------------------------
getprop                                       > "$OUT/getprop.txt"    2>&1
cat /proc/cmdline                             > "$OUT/cmdline.txt"    2>&1
cat /proc/version                             > "$OUT/version.txt"    2>&1
ls -la /                                      > "$OUT/rootls.txt"     2>&1
ls -la /system/bin/ /system/etc/              > "$OUT/systemls.txt"   2>&1
ps                                            > "$OUT/ps.txt"         2>&1

# sync before umount: dirty vfat pages at power-off corrupt cards, and this
# script is likely to be killed by a forced power-off moments from now.
sync
sleep 2
umount "$MNT" 2>/dev/null
sync
__HWJDN_EOF__
chmod +x "$DEV/recovery/root/system/bin/jdn_diag.sh"
echo "    recovery/root/system/bin/jdn_diag.sh"

mkdir -p "$DEV/recovery/root/system/etc"
cat > "$DEV/recovery/root/system/etc/recovery.fstab" <<'__HWJDN_EOF__'
# Android fstab file -- hwjdn recovery. AOSP fs_mgr COLUMN format.
#
# On Android 11 TWRP this pairs with twrp.flags in the same directory:
# recovery.fstab carries the plain fs_mgr entries, twrp.flags carries
# everything TWRP-specific. Both ship inside the recovery ramdisk at
# /system/etc/ -- NOT /etc, which is the Android 9 location.
#
# Every by-name path below is VERIFIED from
# /sys/block/mmcblk0/mmcblk0p*/uevent PARTNAME on the live device.
#
#<src>                                <mnt_point>   <type>  <mnt_flags and options>                                <fs_mgr_flags>
/dev/block/bootdevice/by-name/log      /log          vfat    nosuid,nodev,uid=1000,gid=1007,fmask=0007,dmask=0007   wait
/dev/block/bootdevice/by-name/config   /frp          emmc    defaults                                               defaults
/dev/block/bootdevice/by-name/pad      /persistent   emmc    defaults                                               defaults
/dev/block/bootdevice/by-name/persist  /persist      ext4    nosuid,nodev,barrier=1                                 wait
/dev/block/bootdevice/by-name/misc     /misc         emmc    defaults                                               defaults
__HWJDN_EOF__
echo "    recovery/root/system/etc/recovery.fstab"

mkdir -p "$DEV/recovery/root/system/etc"
cat > "$DEV/recovery/root/system/etc/twrp.flags" <<'__HWJDN_EOF__'
# twrp.flags -- hwjdn. TWRP flag format, ships at /system/etc/ in the ramdisk.
#
# Partition table VERIFIED without root via the sysfs uevent PARTNAME of every
# mmcblk0pNN, cross-checked against /proc/partitions. All 26 agreed.
#
# DELIBERATELY ABSENT: sbl1, hyp, sec, DDR, rpm, tz, aboot, config(/frp).
# The first seven are the bootloader/TZ chain -- exposing them in TWRP's backup
# UI invites a restore that bricks past fastboot. config is Factory Reset
# Protection; a stale FRP restore locks the user out of their own device.
# There is NO `splash` partition on this device.

# mount point   fstype  device                                      device2             flags
/boot           emmc    /dev/block/bootdevice/by-name/boot          flags=backup=1;display=Boot
/recovery       emmc    /dev/block/bootdevice/by-name/recovery      flags=backup=1;display=Recovery
/erecovery      emmc    /dev/block/bootdevice/by-name/erecovery     flags=backup=1;display=eRecovery

/system         ext4    /dev/block/bootdevice/by-name/system        flags=backup=0;display=System;wipeingui
/system_image   emmc    /dev/block/bootdevice/by-name/system        flags=backup=1;display=System-Image
/cache          ext4    /dev/block/bootdevice/by-name/cache         flags=backup=1;display=Cache;wipeingui
/cust           ext4    /dev/block/bootdevice/by-name/cust          flags=backup=1;display=Cust

# length=-16384 IS NOT OPTIONAL. The stock recovery fstab reserves the last
# 16 KB of userdata for the FDE crypto footer, and stock system fstab.qcom uses
# forceencrypt=footer. Without it TWRP sizes the filesystem to the whole
# partition and a format writes straight over the footer.
/data           ext4    /dev/block/bootdevice/by-name/userdata      flags=backup=1;display=Data;wipeingui;encryptable=footer;length=-16384

# Calibration store: WiFi/BT MACs, sensor and camera calibration. This is the
# partition behind the reported 02:00:00:00:00:00 MAC failure on this model,
# and it is NOT present in UPDATE.APP -- the device is the only copy.
/persist        ext4    /dev/block/bootdevice/by-name/persist       flags=backup=1;display=Persist

# oeminfo holds the IMEI and cannot be regenerated. Also absent from UPDATE.APP.
/oeminfo        emmc    /dev/block/bootdevice/by-name/oeminfo       flags=backup=1;display=OEMInfo

# THE context= OPTION IS LOAD-BEARING AND CONFIRMED: stock EMUI mounts this
# exact partition with context=u:object_r:firmware_file:s0 (seen in the live
# `mount` output). vfat has no xattrs, so a mount context is the only way
# anything under /firmware gets an SELinux label. Dropping it on kiwi
# mislabelled the TZ images and cost weeks.
/firmware       vfat    /dev/block/bootdevice/by-name/modem         flags=display=Firmware;mounttodecrypt;fsflags="ro,shortname=lower,uid=1000,gid=1000,dmask=222,fmask=333,context=u:object_r:firmware_file:s0"
/modem          emmc    /dev/block/bootdevice/by-name/modem         flags=backup=1;display=Modem

/misc           emmc    /dev/block/bootdevice/by-name/misc          flags=backup=1;display=Misc
/log            vfat    /dev/block/bootdevice/by-name/log           flags=display=Log

# Qualcomm EFS -- the paired modem NV store plus the filesystem guard. Losing
# these costs the radio calibration on the L01 (LTE).
/efs1           emmc    /dev/block/bootdevice/by-name/modemst1      flags=backup=1;display=EFS
/efs2           emmc    /dev/block/bootdevice/by-name/modemst2      flags=backup=1;subpartitionof=/efs1
/fsg            emmc    /dev/block/bootdevice/by-name/fsg           flags=backup=1;subpartitionof=/efs1

# Removable. mmcblk1 hangs off a SEPARATE controller (7864900.sdhci) from the
# eMMC (7824900.sdhci), verified in /sys/block -- so mmcblk1p1 really is the
# microSD and cannot accidentally point at internal storage.
/external_sd    auto    /dev/block/mmcblk1p1    /dev/block/mmcblk1  flags=display="MicroSD";storage;wipeingui;removable
/usb-otg        auto    /dev/block/sda1         /dev/block/sda      flags=display="USB-OTG";storage;wipeingui;removable
__HWJDN_EOF__
echo "    recovery/root/system/etc/twrp.flags"

mkdir -p "$DEV/recovery/root"
cat > "$DEV/recovery/root/ueventd.qcom.rc" <<'__HWJDN_EOF__'
# ueventd.qcom.rc -- hwjdn recovery
#
# Trimmed from the CAF msm8916 original to what a RECOVERY actually needs:
# graphics, storage, input and sensors. The full platform file also covers
# audio, camera, radio, bluetooth and fingerprint -- none of which recovery
# touches, and hwjdn has no fingerprint sensor at all.
#
# The i2c sysfs paths below are NOT copied blindly: hwjdn's own
# /proc/bus/input/devices reports its sensors under
# /devices/soc.0/78b6000.i2c/i2c-0/ (bma2x2-accel at 0-0018, light and
# proximity at 0-001e), which happens to match the reference exactly.

/dev/kgsl-3d0             0666   system     system
/dev/ion                  0664   system     system
/dev/rtc0                 0600   system     system

# sensors
/sys/devices/soc.0/78b6000.i2c/i2c-0/0-*            enable         0660    input    system
/sys/devices/soc.0/78b6000.i2c/i2c-0/0-*            poll_delay     0660    input    system
/sys/devices/soc.0/78b6000.i2c/i2c-0/0-*            enable_wakeup  0660    input    system
/sys/devices/soc.0/78b6000.i2c/i2c-0/0-*            flush          0660    input    system
/sys/devices/virtual/input/input*                   poll           0660    input    system
/sys/devices/virtual/input/input*                   pollrate_ms    0660    input    system

# wlan (present so TWRP's adb-over-network path is not surprised by perms)
/dev/wcnss_wlan           0660   system     system
/dev/wcnss_ctrl           0660   system     system
__HWJDN_EOF__
echo "    recovery/root/ueventd.qcom.rc"

cat > "$DEV/twrp_hwjdn.mk" <<'__HWJDN_EOF__'
# twrp_hwjdn.mk -- Huawei MediaPad T2 8.0 Pro (JDN-L01)
#
# Codename hwjdn is verbatim ro.product.device from the live device -- not
# "jdn", not Huawei's internal "jordan".

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)

# vendor/twrp/config/common.mk carries TWRP's own product configuration. An
# earlier revision of this tree omitted it on the reasoning that plain AOSP
# inherits were "safer"; the working kiwi TWRP 11 tree inherits it, so that
# reasoning was wrong.
$(call inherit-product, vendor/twrp/config/common.mk)

$(call inherit-product, device/huawei/hwjdn/device.mk)

PRODUCT_DEVICE        := hwjdn
PRODUCT_NAME          := twrp_hwjdn
PRODUCT_BRAND         := Huawei
PRODUCT_MODEL         := JDN-L01
PRODUCT_MANUFACTURER  := HUAWEI

# NOT inherited, deliberately: full_base_telephony.mk. The reference tree pulls
# it in, but a recovery has no use for telephony and it only adds build surface.
__HWJDN_EOF__
echo "    twrp_hwjdn.mk"


echo "==> staging prebuilts"
mkdir -p "$DEV/prebuilt"
cp "$KERNEL" "$DEV/prebuilt/Image"
cp "$STOCK/unpacked_recovery/dt.img" "$DEV/prebuilt/dt.img"
echo; echo "==> verification"
ls -l "$DEV/prebuilt/"
echo "  kiwi lineage Image = 19226296  |  jdn stock Image = 17852440"
echo
grep -A5 "^service jdn-diag" "$DEV/recovery/root/init.recovery.qcom.rc"

