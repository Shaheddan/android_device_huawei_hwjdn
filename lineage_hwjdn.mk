#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# jdn shipped Android 6.0.1; kiwi shipped 5.1, hence _l on kiwi's tree.
# This governs the compatibility defaults applied to a device of that vintage.
$(call inherit-product, $(SRC_TARGET_DIR)/product/product_launched_with_m.mk)

$(call inherit-product, device/huawei/hwjdn/device.mk)

# Inherit some common LineageOS stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

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
