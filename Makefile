include $(THEOS)/makefiles/common.mk

TOOL_NAME = ftt
$(TOOL_NAME)_FILES = main.m
$(TOOL_NAME)_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tool.mk