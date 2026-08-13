# The file the build scans to discover the product. If `lunch twrp_hwjdn-eng`
# reports "product not found", check HERE first, not BoardConfig.mk.

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/twrp_hwjdn.mk

COMMON_LUNCH_CHOICES := \
    twrp_hwjdn-eng \
    twrp_hwjdn-userdebug
