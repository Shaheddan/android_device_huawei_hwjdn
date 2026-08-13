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
