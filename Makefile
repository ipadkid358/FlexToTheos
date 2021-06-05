ifeq ($(MACOS),1)
    ARCHS = i386 x86_64
    TARGET = macosx:clang::10.10
else
    ARCHS = arm64 arm64e
    TARGET = iphone:clang:11.2:10.00

SYSROOT = $(THEOS)/sdks/iPhoneOS11.2.sdk

    ftt_FRAMEWORKS = UIKit
    ftt_CODESIGN_FLAGS = -Sent.plist
endif

include $(THEOS)/makefiles/common.mk

TOOL_NAME = ftt
ftt_FILES = main.m
ftt_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tool.mk
