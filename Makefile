ifeq ($(MACOS),1)
    ARCHS = i386 x86_64
    TARGET = macosx:clang::10.10
else
    ARCHS = arm64 arm64e
    TARGET = iphone:clang:14.5:10.00

SYSROOT = $(THEOS)/sdks/iPhoneOS14.5.sdk
THEOS_PACKAGE_SCHEME=roothide
    ftt_FRAMEWORKS = UIKit
    ftt_CODESIGN_FLAGS = -Sent.plist -Icom.ipadkid.ftt
endif

include $(THEOS)/makefiles/common.mk

TOOL_NAME = ftt
ftt_FILES = main.m
ftt_CFLAGS = -fobjc-arc
ftt_LDFLAGS += -lroothide

include $(THEOS_MAKE_PATH)/tool.mk
