DEBUG = 0
ARCHS = armv7 arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = ftt
ftt_FILES = main.m
ftt_FRAMEWORKS = UIKit
ftt_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tool.mk
