# Standalone library only. TrollFools chooses the target App; no package/stage/install.
include TIMAntiRecallBuild.mk
include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = TIMAntiRecall
TIMAntiRecall_FILES = $(wildcard Sources/*.m Hooks/*.m)
TIMAntiRecall_FILES += $(wildcard Sources/*.swift)
TIMAntiRecall_SWIFTFLAGS = -swift-version 5 -parse-as-library
TIMAntiRecall_SWIFT_BRIDGING_HEADER = Headers/TIMAntiRecallSwift-Bridging.h
TIMAntiRecall_CFLAGS = -fobjc-arc -Wall -Wextra -I./Headers -I./Sources
TIMAntiRecall_FRAMEWORKS = UIKit Foundation CoreFoundation
TIMAntiRecall_LIBRARIES =
TIMAntiRecall_INSTALL_PATH = @rpath
TIMAntiRecall_INSTALL = 0
TIMANTIRECALL_VERSION ?= 0.10
TIMAntiRecall_LDFLAGS = -Wl,-current_version,$(TIMANTIRECALL_VERSION) -Wl,-compatibility_version,0.0

include $(THEOS_MAKE_PATH)/library.mk

after-all::
	mkdir -p reports/universal
	cp "$(THEOS_OBJ_DIR)/TIMAntiRecall.dylib" reports/universal/TIMAntiRecall.dylib
