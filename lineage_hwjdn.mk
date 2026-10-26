#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Full dexpreopt on eng too. Android 14's runtime_libart.mk sets OVERRIDE_DISABLE_DEXOPT_ALL ?= true
# for eng, which pre-opts only the ART module's boot image: with no framework boot image
# (/system/framework/arm64/boot.art) zygote64 ran imageless, the 32-bit zygote compiled a boot
# image at every start, and system_server's first-boot dexopt never finished before its watchdog
# killed it (kiwi). This file is read before the products it inherits, so the ?= there keeps our value.
OVERRIDE_DISABLE_DEXOPT_ALL := false

# Release ART on eng too. Android 14's runtime_libart.mk ships the debug ART APEX
# (com.android.art.debug) on eng, and on a debuggable build libnativehelper loads libartd.so
# whenever it exists, whatever persist.sys.dalvik.vm.lib.2 says. On kiwi that made SystemUI and
# Settings stop responding. PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD cannot reach that inherited
# makefile from here (product variables are cleared per makefile), so the build/make patch
# (patches/lineage-21/build/make) adds this plain-variable override, read like the one above.
OVERRIDE_ART_TARGET_INCLUDE_DEBUG_BUILD := false

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# jdn shipped Android 6.0.1; kiwi shipped 5.1, hence _l on kiwi's tree.
# This governs the compatibility defaults applied to a device of that vintage.
$(call inherit-product, $(SRC_TARGET_DIR)/product/product_launched_with_m.mk)

$(call inherit-product, device/huawei/hwjdn/device.mk)

# Inherit some common LineageOS stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# Ship APEXes uncompressed. A compressed APEX is decompressed to /data and must be mounted
# through dm-verity with optional table arguments, which the 3.10 dm-verity rejects
# ("verity: Invalid argument count: 10-11 arguments required"); pre-installed APEXes on
# /system are loop-mounted without dm-verity. Set in this product makefile, not device.mk:
# its own value beats every inherited one (updatable_apex.mk sets true).
PRODUCT_COMPRESSED_APEX := false

# Device identifier. This must come after all inclusions
PRODUCT_BRAND := HUAWEI
PRODUCT_DEVICE := hwjdn
PRODUCT_MANUFACTURER := HUAWEI
PRODUCT_MODEL := JDN-L01
PRODUCT_NAME := lineage_hwjdn

PRODUCT_GMS_CLIENTID_BASE := android-huawei

# 1200x1920 at 320 dpi gives smallestWidthDp 600, which is the threshold
# Android 12L's large-screen features key off: the taskbar, drag-to-split,
# two-pane Settings and the split notification shade.
PRODUCT_CHARACTERISTICS := tablet
