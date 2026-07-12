# QNByPass - 去哪儿旅行越狱屏蔽 Tweak
# 适用于：Dopamine (rootless) + RootHide
# 目标App：com.qunar.iphoneclient

# Theos 安装路径（GitHub Actions 中自动配置）
# export THEOS=/opt/theos

TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = QunariPhone_Cook_CM
THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
TARGET_IPHONEOS_DEPLOYMENT_VERSION = 14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = QNByPass

QNByPass_FILES = Tweak.xm
QNByPass_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
QNByPass_FRAMEWORKS = UIKit Foundation
QNByPass_PRIVATE_FRAMEWORKS = AppSupport

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 QunariPhone_Cook_CM || true"
