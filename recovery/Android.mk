LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

# Android 15 moved edify and the non-A/B updater from bootable/recovery to
# bootable/deprecated-ota; otautil stayed. The headers hwjdn uses are unchanged.
LOCAL_C_INCLUDES := \
    bootable/recovery \
    bootable/deprecated-ota/edify/include \
    bootable/recovery/otautil/include \
    bootable/deprecated-ota/updater/include

LOCAL_SRC_FILES := recovery_updater.cpp
LOCAL_MODULE := librecovery_updater_hwjdn
# hwjdn: Android 14 builds every vendor module VNDK-style, without the old global
# include dirs (libhardware, media plugin/OMX, EGL); request them explicitly.
LOCAL_HEADER_LIBRARIES += libhardware_headers media_plugin_headers gl_headers
include $(BUILD_STATIC_LIBRARY)
