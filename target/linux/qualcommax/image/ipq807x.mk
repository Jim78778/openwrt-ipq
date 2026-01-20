DEVICE_VARS += NETGEAR_BOARD_ID NETGEAR_HW_ID TPLINK_SUPPORT_STRING

define Build/asus-fake-ramdisk
	rm -rf $(KDIR)/tmp/fakerd
	dd if=/dev/zero bs=32 count=1 > $(KDIR)/tmp/fakerd
	$(info KERNEL_INITRAMFS is $(KERNEL_INITRAMFS))
endef

define Build/asus-fake-rootfs
	$(eval comp=$(word 1,$(1)))
	$(eval filepath=$(word 2,$(1)))
	$(eval filecont=$(word 3,$(1)))
	rm -rf $(KDIR)/tmp/fakefs $(KDIR)/tmp/fakehsqs
	mkdir -p $(KDIR)/tmp/fakefs/$$(dirname $(filepath))
	echo '$(filecont)' > $(KDIR)/tmp/fakefs/$(filepath)
	$(STAGING_DIR_HOST)/bin/mksquashfs4 $(KDIR)/tmp/fakefs $(KDIR)/tmp/fakehsqs -comp $(comp) \
		-b 4096 -no-exports -no-sparse -no-xattrs -all-root -noappend \
		$(wordlist 4,$(words $(1)),$(1))
endef

define Build/asus-trx
	$(STAGING_DIR_HOST)/bin/asusuimage $(wordlist 1,$(words $(1)),$(1)) -i $@ -o $@.new
	mv $@.new $@
endef

define Build/wax6xx-netgear-tar
	mkdir $@.tmp
	mv $@ $@.tmp/nand-ipq807x-apps.img
	md5sum $@.tmp/nand-ipq807x-apps.img | cut -c 1-32 > $@.tmp/nand-ipq807x-apps.md5sum
	echo $(DEVICE_MODEL) > $@.tmp/metadata.txt
	echo $(DEVICE_MODEL)"_V99.9.9.9" > $@.tmp/version
	tar -C $@.tmp/ -cf $@ .
	rm -rf $@.tmp
endef

define Device/swaiot_cpe_s10
  # ===== 基础 Image 能力 =====
  $(call Device/FitImage)
  $(call Device/UbiFit)

  DEVICE_VENDOR := Swaiot
  DEVICE_MODEL := CPE-S10
  DEVICE_VARIANT := NAND

  SOC := ipq8071
  DEVICE_DTS := ipq8071-s10

  # ===== NAND 真实参数（IPQ807x 通用稳定值）=====
  BLOCKSIZE := 128k
  PAGESIZE := 2048

  # ====== 核心：必须声明最终固件 ======
  IMAGES := factory.bin sysupgrade.bin

  # ===== factory.bin（U-Boot 可刷）=====
  # QSDK 风格，最稳，支持原厂 u-boot web / tftp / fastboot
  IMAGE/factory.bin := append-ubi | qsdk-ipq-factory-nand

  # ===== sysupgrade.bin（OpenWrt 内升级）=====
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata

  # ===== 设备专属包 =====
  DEVICE_PACKAGES := \
        kmod-usb3 \
        kmod-mhi-bus \
        kmod-mhi-net \
        kmod-mhi-wwan-ctrl \
        qmodem \
        luci-proto-qmi \
        uqmi \
        kmod-usb-net-rndis \
        kmod-usb-net-cdc-ether

endef

TARGET_DEVICES += swaiot_cpe_s10

