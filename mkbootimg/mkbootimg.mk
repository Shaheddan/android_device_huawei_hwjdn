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
