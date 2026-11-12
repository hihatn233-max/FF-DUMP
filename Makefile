TARGET := iphone:clang:latest:15.0
ARCHS := arm64
INSTALL_TARGET_PROCESSES := Free\ Fire

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := FFMenu
FFMenu_FILES := Tweak.xm VIPMenu.mm
FFMenu_CFLAGS := -fobjc-arc -std=c++17 -I.
FFMenu_FRAMEWORKS := UIKit Foundation QuartzCore
FFMenu_LDFLAGS := -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk
