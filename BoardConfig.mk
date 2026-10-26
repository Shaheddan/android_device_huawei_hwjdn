#
# Copyright (C) 2015 The CyanogenMod Project
# Copyright (C) 2017-2021 The LineageOS Project
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/huawei/hwjdn

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a53

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53

TARGET_BOARD_SUFFIX := _64
TARGET_USES_64_BIT_BINDER := true

# ro.board.platform reads exactly "msm8916" on this device: the AOSP platform
# directory name covers the whole 8916/8939 family, and this is an MSM8939v2.
TARGET_BOARD_PLATFORM := msm8916

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := MSM8916
TARGET_NO_BOOTLOADER := true
TARGET_OTA_ASSERT_DEVICE := hwjdn

# Kernel
#
# THE TWO OFFSETS BELOW ARE NOT THE msm8939 CONVENTION AND NOT kiwi's.
# They were read out of this device's own stock RECOVERY.img header (BOOT.img
# agrees). kiwi uses tags 0x01E00000 / ramdisk 0x02000000; copying those here
# would produce an image the bootloader loads to the wrong addresses.
BOARD_KERNEL_BASE := 0x80000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_TAGS_OFFSET := 0x00000100
BOARD_RAMDISK_OFFSET     := 0x01000000

# Stock's cmdline verbatim, minus androidboot.selinux (set below for bringup)
# and minus the bootloader-appended serialno/verifiedbootstate/veritymode.
# There is no console= on this device; earlyprintk is what stock uses.
BOARD_KERNEL_CMDLINE := androidboot.hardware=qcom msm_rtb.filter=0x237 ehci-hcd.park=3 androidboot.bootdevice=7824900.sdhci lpm_levels.sleep_disabled=1 earlyprintk

# BRINGUP ONLY. Remove once a boot-time denial harvest is clean, exactly as
# kiwi did. Leaving it in ships a ROM with SELinux disabled.
BOARD_KERNEL_CMDLINE += androidboot.selinux=enforcing

# 17.85 MB of kernel is far too large for a compressed Image.gz; this is an
# uncompressed arm64 Image, as on every device in this family.
BOARD_KERNEL_IMAGE_NAME := Image

# Separated DT, as on stock. dtbtool reports Version:2 for this DTB (it has
# qcom,board-id but no PMIC ids) and produces six entries: chipsets 239/241/263
# against platform 8084 subtypes 0 and 4.
BOARD_KERNEL_SEPARATED_DT := true
BOARD_DTBTOOL_ARGS := -2

TARGET_KERNEL_SOURCE := kernel/huawei/jdn
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_CONFIG := jdn-64_defconfig
# GCC 4.9 only; this 3.10 tree does not build with clang.
TARGET_KERNEL_CLANG_COMPILE := false

# Audio
AUDIO_FEATURE_ENABLED_FM_POWER_OPT := true
AUDIO_FEATURE_ENABLED_KPI_OPTIMIZE := true
AUDIO_FEATURE_ENABLED_MULTI_VOICE_SESSIONS := true
AUDIO_FEATURE_ENABLED_NEW_SAMPLE_RATE := true
AUDIO_FEATURE_ENABLED_SND_MONITOR := true
AUDIO_FEATURE_HUAWEI_SOUND_PARAM_PATH := true
BOARD_USES_ALSA_AUDIO := true
USE_CUSTOM_AUDIO_POLICY := 1
USE_XML_AUDIO_POLICY_CONF := 1

# Bluetooth
BOARD_HAVE_BLUETOOTH_QCOM := true
BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR := $(DEVICE_PATH)/bluetooth

# Bootanimation
TARGET_BOOTANIMATION_PRELOAD := true
TARGET_BOOTANIMATION_TEXTURE_CACHE := true

# Camera
# camera.msm8916.so is 32-bit only, so a 64-bit cameraserver finds 0 devices.
# Running the HAL inside 32-bit mediaserver is what made kiwi's camera work.
TARGET_USES_MEDIA_EXTENSIONS := true
TARGET_HAS_LEGACY_CAMERA_HAL1 := true
TARGET_NEEDS_LEGACY_CAMERA_HAL1_DYN_NATIVE_HANDLE := true
TARGET_PROCESS_SDK_VERSION_OVERRIDE := \
        /system/bin/mediaserver=23 \
        /system/vendor/bin/mm-qcamera-daemon=23

# Charger
BOARD_CHARGER_DISABLE_INIT_BLANK := true
# This node accepts values and drives nothing on a stock kernel. It is real
# here only because kernel/huawei/jdn patches mdss_dsi.c and mdss_dsi_panel.c
# to tie it to the panel's three backlight enable GPIOs.
BACKLIGHT_PATH := /sys/class/leds/lcd-backlight/brightness

# Display
OVERRIDE_RS_DRIVER := libRSDriver_adreno.so
TARGET_ADDITIONAL_GRALLOC_10_USAGE_BITS := 0x02000000
TARGET_CONTINUOUS_SPLASH_ENABLED := true
TARGET_DISABLE_POSTRENDER_CLEANUP := true
# 1200x1920 at 320 dpi -> smallestWidthDp 600, the large-screen threshold that
# Android 12L's taskbar and two-pane layouts key off. kiwi is 480 (a phone).
TARGET_SCREEN_DENSITY := 320
TARGET_USES_ION := true

# Extended Filesystem Support
TARGET_EXFAT_DRIVER := sdfat

# FM -- this tablet does have a tuner (libfm_hal.so, libfm_jni.so, and the
# DTS declares it).
BOARD_HAVE_QCOM_FM := true
TARGET_QCOM_NO_FM_FIRMWARE := true

# Fonts
EXCLUDE_SERIF_FONTS := true

# GPS
TARGET_GPS_HAL_PATH := $(DEVICE_PATH)/gps

# Hardware disk encryption (FDE)
# Stock reports ro.crypto.type=block with forceencrypt=footer.
TARGET_HW_DISK_ENCRYPTION := true
TARGET_LEGACY_HW_DISK_ENCRYPTION := true

# HIDL
DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE := $(DEVICE_PATH)/device_framework_matrix.xml

# Legacy memfd
TARGET_HAS_MEMFD_BACKPORT := true

# Lights
# device/huawei/hwjdn/light drives /sys/class/leds/{red,green} directly. This
# device has no blue emitter and does not use kiwi's QMI-to-modem path.
TARGET_PROVIDES_LIBLIGHT := true

# Malloc
MALLOC_SVELTE := true

# Partitions -- sizes from this device's own partition table, read via the
# sysfs uevent PARTNAME of every mmcblk0pNN and cross-checked against the
# bootloader's ptable in /log/recovery_log.
TARGET_FS_CONFIG_GEN := $(DEVICE_PATH)/config.fs
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_USES_MKE2FS := true
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_PERSISTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_ROOT_EXTRA_FOLDERS := firmware persist
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864       # p19  64 MB
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 67108864   # p20  64 MB
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2952790016   # p24  2.75 GB
BOARD_USERDATAIMAGE_PARTITION_SIZE := 11345575424 # p26 10.57 GB
BOARD_CACHEIMAGE_PARTITION_SIZE := 268435456     # p22 256 MB
BOARD_PERSISTIMAGE_PARTITION_SIZE := 67108864    # p18  64 MB
BOARD_FLASH_BLOCK_SIZE := 131072

# Power
TARGET_USES_INTERACTION_BOOST := true
# jdn: core_ctl screen-on: the screen on/off core_ctl switch, built
# into the qcom power HAL through its device hook.
TARGET_POWERHAL_SET_INTERACTIVE_EXT := $(DEVICE_PATH)/power/power-interactive-ext.c
# NOTE: no TARGET_TAP_TO_WAKE_NODE. kiwi points at /sys/touch_screen/tap_to_wake,
# a node Huawei's own touch driver creates. This device runs nvt_ts_jdn, which
# reports coordinates and nothing else, and its DTS has no such property.

# Properties
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop

# Qualcomm support
BOARD_USES_QC_TIME_SERVICES := true
BOARD_USES_QCOM_HARDWARE := true

# Recovery
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.qcom
TARGET_RECOVERY_PIXEL_FORMAT := ABGR_8888
TARGET_RECOVERY_DENSITY := xhdpi

# Release
TARGET_BOARD_INFO_FILE := $(DEVICE_PATH)/board-info.txt

# Release tools
TARGET_RECOVERY_UPDATER_LIBS := librecovery_updater_hwjdn
TARGET_RELEASETOOLS_EXTENSIONS := $(DEVICE_PATH)/releasetools

# RIL
TARGET_RIL_VARIANT := caf
TARGET_USES_OLD_MNC_FORMAT := true

# SELinux
include device/qcom/sepolicy-legacy/sepolicy.mk

BOARD_VENDOR_SEPOLICY_DIRS += \
    device/huawei/hwjdn/sepolicy

# VNDK
TARGET_VNDK_USE_CORE_VARIANT := true

# Vendor Init
TARGET_INIT_VENDOR_LIB := libinit_hwjdn

# Vold
TARGET_USE_CUSTOM_LUN_FILE_PATH := /sys/devices/platform/msm_hsusb/gadget/lun%d/file

# Wifi -- same prima/WCNSS stack as kiwi (WCNSS_qcom_cfg.ini, wcnss-service,
# cnss-daemon, wifi.chip.type=2.7), so kiwi's configuration transfers.
BOARD_HAS_QCOM_WLAN := true
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_qcwcn
PRODUCT_VENDOR_MOVE_ENABLED := true
BOARD_WLAN_DEVICE := qcwcn
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_qcwcn
WIFI_DRIVER_FW_PATH_AP := "ap"
WIFI_DRIVER_FW_PATH_STA := "sta"
WIFI_HIDL_UNIFIED_SUPPLICANT_SERVICE_RC_ENTRY := true
WPA_SUPPLICANT_VERSION := VER_0_8_X
TARGET_DISABLE_WCNSS_CONFIG_COPY := true
TARGET_USES_QCOM_WCNSS_QMI := true
TARGET_USES_WCNSS_CTRL := true
TARGET_PROVIDES_WCNSS_QMI := true

# inherit from the proprietary version
-include vendor/huawei/hwjdn/BoardConfigVendor.mk

# Build-system exceptions (each demanded by an explicit build error on kiwi)
BUILD_BROKEN_USES_BUILD_COPY_HEADERS := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# Shims
#
# STARTING SET ONLY, inherited from kiwi's scan. kiwi's dump carried the same
# shared Huawei camera bundle, and its symbol scan already flagged this
# device's imx219 _pad chromatix blobs as importing Huawei log symbols.
#
# The rest must come from a scan of THIS device's blobs for undefined Huawei
# symbols -- kiwi's list also names sensors.kiwi.so, fingerprint.msm8916.so and
# several ov5648/s5k4e1 files that are kiwi's hardware, not ours.
TARGET_LD_SHIM_LIBS := \
    /system/vendor/lib/libchromatix_imx219_liteon_pad_zsl_preview.so|libshim_cutils_hwjdn.so:\
    /system/vendor/lib/libchromatix_imx219_ofilm_pad_zsl_preview.so|libshim_cutils_hwjdn.so:\
    /system/vendor/lib/libdmd.so|libshim_cutils_hwjdn.so:\
    /system/vendor/lib64/libdmd.so|libshim_cutils_hwjdn.so:\
    /system/vendor/bin/thermal-engine|libshim_cutils_hwjdn.so:\
    /system/vendor/lib64/libbtaddr.so|libshim_btaddr_hwjdn.so:\
    /system/vendor/lib64/libmm-abl.so|libshim_powermanager_hwjdn.so

# Dexpreopt
# eng builds default to pre-opting only the boot image and system server, so
# every app is compiled on the phone at first boot. On kiwi that first boot
# ran 15+ minutes, and the 3.10 kernel has no pidfd_open, so installd cannot
# time out a stuck dex2oat. Pre-opt everything at build time, as user and
# userdebug builds do.
WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY := false
