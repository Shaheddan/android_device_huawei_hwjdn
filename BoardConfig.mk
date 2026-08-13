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
# hbtp_vm is a VIRTUAL pointer device created by kiwi's defconfig (Host Based
# Touch Processing). jdn's STOCK kernel has none, which is why I removed it --
# but we run KIWI's kernel, which does create it, and TWRP will bind to it and
# receive nothing. Both entries are needed. \x0a is the separator TWRP expects.
# NOTE THE DOUBLE BACKSLASH. This value passes through out/soong/soong.variables,
# which is JSON -- and JSON has no \x escape, only \u. A single backslash makes
# Soong reject the entire config file with 'invalid character x in string escape
# code'. Doubled here, JSON decodes it back to \x0a, which is the newline
# separator TWRP's C code expects between blacklist entries.
TW_INPUT_BLACKLIST := bma2x2-accel\\x0ahbtp_vm

# ---- TWRP: behaviour -------------------------------------------------------
TW_DEFAULT_LANGUAGE  := en
TW_EXTRA_LANGUAGES   := true
TW_USE_TOOLBOX       := true
TW_INCLUDE_NTFS_3G   := true
TW_NO_EXFAT_FUSE     := true
TW_EXCLUDE_SUPERSU   := true
# TWRP's brightness writes go to /sys/class/leds/lcd-backlight/brightness,
# which on this device is wired to NOTHING (verified: writing 200 holds but
# lights nothing). So TWRP can blank the screen but can never un-blank it.
# Blanking must therefore be disabled outright, or the GUI renders black
# forever while otherwise running perfectly.
# Blanking is safe now: the brightness node really drives the backlight
# (see the hw_bl_gpio hook in mdss_dsi_panel_bl_ctrl), so TWRP can turn
# the screen off AND back on. Both flags removed -- power button blanks,
# and the idle timeout works too. Put TW_NO_SCREEN_TIMEOUT back if the
# auto-off proves annoying during long operations.

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
