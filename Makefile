TARGET = iphone:11.2:9.2 

include $(THEOS)/makefiles/common.mk

TOOL_NAME = ftt
ftt_FILES = main.m
ftt_FRAMEWORKS = UIKit
ftt_CODESIGN_FLAGS = -Sent.plist -Icom.ipadkid.ftt
ftt_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tool.mk
