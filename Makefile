TARGET := iphone:clang:latest:15.0
ARCHS := arm64
INSTALL_TARGET_PROCESSES := Free\ Fire

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := libMobileGestalt
libMobileGestalt_FILES := Tweak.xm VIPMenu.mm
libMobileGestalt_CFLAGS := -fobjc-arc -std=c++17 -I.
libMobileGestalt_FRAMEWORKS := UIKit Foundation QuartzCore
libMobileGestalt_LDFLAGS := -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk
