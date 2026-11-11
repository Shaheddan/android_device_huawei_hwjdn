LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE           := libril-wrapper
LOCAL_MULTILIB         := 64
LOCAL_VENDOR_MODULE    := true
LOCAL_SRC_FILES        := ril-wrapper.c
LOCAL_SHARED_LIBRARIES := libdl liblog libril libcutils
LOCAL_CFLAGS           := -Wall -Werror
# hwjdn: Android 14 builds every vendor module VNDK-style, without the old global
# include dirs (libhardware, media plugin/OMX, EGL); request them explicitly.
LOCAL_HEADER_LIBRARIES += libhardware_headers media_plugin_headers gl_headers
# Android 15: libril is a Soong module that no longer exports hardware/ril/include;
# telephony/ril.h comes from the ril_headers library.
LOCAL_HEADER_LIBRARIES += ril_headers
include $(BUILD_SHARED_LIBRARY)
