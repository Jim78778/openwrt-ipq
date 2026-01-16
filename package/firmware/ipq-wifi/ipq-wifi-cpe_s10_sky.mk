# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk

PKG_NAME:=ipq-wifi-cpe_s10_sky
PKG_DESCRIPTION:=Board-specific WiFi data for Skyworth CPE S10-SKY
PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=firmware
  CATEGORY:=Firmware
  TITLE:=$(PKG_DESCRIPTION)
endef

define Build/Compile
    true
endef

define Package/$(PKG_NAME)/install
    $(INSTALL_DIR) $(1)/lib/firmware/ath11k
    $(INSTALL_DATA) ./files/board-cpe_s10_sky/board-2.bin $(1)/lib/firmware/ath11k/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
