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
