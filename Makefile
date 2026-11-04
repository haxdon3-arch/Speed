TARGET := iphone:clang:latest:14.0
ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = SpeedHack
SpeedHack_FILES = Tweak.m
SpeedHack_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/library.mk
