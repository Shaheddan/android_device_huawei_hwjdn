LOCAL_PATH := $(call my-dir)

# The guard stops hwjdn's subdir makefiles being parsed for every lunch target
# in the checkout -- which on a tree shared with kiwi produces duplicate-module
# errors pointing at the wrong device entirely.
ifeq ($(TARGET_DEVICE),hwjdn)
include $(call all-subdir-makefiles,$(LOCAL_PATH))
endif
