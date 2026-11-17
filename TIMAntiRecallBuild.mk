DEBUG ?= 0
FINALPACKAGE ?= 1
ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:16.5
# An injection contract, NOT a Theos packaging scheme.
override THEOS_PACKAGE_SCHEME :=
LIBRARIES =
