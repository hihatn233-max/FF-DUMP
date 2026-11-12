TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES := Free\ Fire

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME := FFMenu
FFMenu_FILES := Tweak.xm VIPMenu.mm
FFMenu_CFLAGS := -fobjc-arc -std=c++17 -I. -DNDEBUG
FFMenu_FRAMEWORKS := UIKit Foundation QuartzCore
FFMenu_LIBRARIES := substrate
FFMenu_INSTALL_PATH := /usr/lib

# Vá lỗi linker của macOS
FFMenu_LDFLAGS := -Wl,-not_for_dylib_shared_cache
FFMenu_CCFLAGS := -fno-modules

include $(THEOS_MAKE_PATH)/library.mk
