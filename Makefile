include $(TOPDIR)/rules.mk

PKG_NAME:=openwrt-xray-geodata-cut
PKG_VERSION:=751dc61c067193aaf71155bc637c92d60b520af6
PKG_RELEASE:=1

PKG_LICENSE:=MPLv2
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=yichya <mail@yichya.dev>

PKG_SOURCE:=xray-geodata-cut-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/yichya/xray-geodata-cut/tar.gz/${PKG_VERSION}?
PKG_HASH:=a5add837f9c949e3168c30d8698e9414beb1bd545720982104d945d64bf7f24f
PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1

GO_PKG:=github.com/yichya/xray-geodata-cut

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/../feeds/packages/lang/golang/golang-package.mk

define Package/$(PKG_NAME)
	SECTION:=Custom
	CATEGORY:=Extra packages
	TITLE:=openwrt-xray-geodata-cut
	PROVIDES:=xray-geodata
	DEPENDS:=$(GO_ARCH_DEPENDS)
endef

define Package/$(PKG_NAME)/description
	Slim geodata files when compiling OpenWrt with Xray
endef

define Package/$(PKG_NAME)/config
menu "openwrt-xray-geodata-cut Configuration"
        depends on PACKAGE_$(PKG_NAME)

config PACKAGE_OPENWRT_XRAY_GEODATA_CUT_FETCH_VIA_PROXYCHAINS
        bool "Fetch data files using proxychains (not recommended)"
        default n

config PACKAGE_OPENWRT_XRAY_GEODATA_CUT_ENABLE_GOPROXY_IO
        bool "Use goproxy.io to speed up module fetching (recommended for some network situations)"
        default n

config PACKAGE_OPENWRT_XRAY_GEODATA_CUT_GEOSITE
	bool "Trim GeoSite"
	default n

config PACKAGE_OPENWRT_XRAY_GEODATA_CUT_GEOSITE_KEEP
	string "Codes to keep in geosite.dat"
	depends on PACKAGE_OPENWRT_XRAY_GEODATA_CUT_GEOSITE
	default "cn,geolocation-!cn,category-ads"

config PACKAGE_OPENWRT_XRAY_GEODATA_CUT_GEOIP
	bool "Trim GeoIP"
	default n

config PACKAGE_OPENWRT_XRAY_GEODATA_CUT_GEOIP_KEEP
	string "Codes to keep in geoip.dat"
	depends on PACKAGE_OPENWRT_XRAY_GEODATA_CUT_GEOIP
	default "cn,private"

config PACKAGE_OPENWRT_XRAY_GEODATA_CUT_TRIM_IPV6
	bool "Trim IPv6 ranges in geoip.dat"
	depends on PACKAGE_OPENWRT_XRAY_GEODATA_CUT_GEOIP
	default n

endmenu
endef

PROXYCHAINS:=
ifdef CONFIG_PACKAGE_OPENWRT_XRAY_GEODATA_CUT_FETCH_VIA_PROXYCHAINS
        PROXYCHAINS:=proxychains
endif

USE_GOPROXY:=
ifdef CONFIG_PACKAGE_OPENWRT_XRAY_GEODATA_CUT_ENABLE_GOPROXY_IO
        USE_GOPROXY:=GOPROXY=https://goproxy.io,direct
endif

TRIM_IPV6:=
ifdef CONFIG_PACKAGE_OPENWRT_XRAY_GEODATA_CUT_TRIM_IPV6
	TRIM_IPV6:=-trimipv6
endif

MAKE_PATH:=$(GO_PKG_WORK_DIR_NAME)/build/src/$(GO_PKG)
MAKE_VARS += $(GO_PKG_VARS)

define Build/Patch
	$(CP) $(PKG_BUILD_DIR)/../xray-geodata-cut-$(PKG_VERSION)/* $(PKG_BUILD_DIR)
endef

define Build/Compile
	cd $(PKG_BUILD_DIR); $(GO_HOST_PKG_VARS) $(USE_GOPROXY) CGO_ENABLED=0 go build -trimpath -ldflags "-s -w" -o $(PKG_INSTALL_DIR)/bin/xray-geodata-cut .
ifdef CONFIG_PACKAGE_OPENWRT_XRAY_GEODATA_CUT_GEOIP
	$(PROXYCHAINS) wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O $(PKG_BUILD_DIR)/geoip_in.dat
	$(PKG_INSTALL_DIR)/bin/xray-geodata-cut -type geoip -in $(PKG_BUILD_DIR)/geoip_in.dat $(TRIM_IPV6) -keep $(CONFIG_PACKAGE_OPENWRT_XRAY_GEODATA_CUT_GEOIP_KEEP) -out $(PKG_BUILD_DIR)/geoip.dat
else
	$(PROXYCHAINS) wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O $(PKG_BUILD_DIR)/geoip.dat
endif
ifdef CONFIG_PACKAGE_OPENWRT_XRAY_GEODATA_CUT_GEOSITE
	$(PROXYCHAINS) wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O $(PKG_BUILD_DIR)/geosite_in.dat
	$(PKG_INSTALL_DIR)/bin/xray-geodata-cut -type geosite -in $(PKG_BUILD_DIR)/geosite_in.dat -keep $(CONFIG_PACKAGE_OPENWRT_XRAY_GEODATA_CUT_GEOSITE_KEEP) -out $(PKG_BUILD_DIR)/geosite.dat
else
	$(PROXYCHAINS) wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O $(PKG_BUILD_DIR)/geosite.dat
endif
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/share/xray
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/geoip.dat $(1)/usr/share/xray/	
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/geosite.dat $(1)/usr/share/xray/	
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
