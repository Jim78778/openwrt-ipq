include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

define Device/swaiot_cpe_s10
	$(call Device/FitImage)
	$(call Device/UbiFit)

	DEVICE_VENDOR := Swaiot
	DEVICE_MODEL := CPE-S10
	SOC := ipq8071

	DEVICE_DTS := ipq8071-s10
	# ⚠️ 只有在 DTS 中真实存在时才保留
	# DEVICE_DTS_CONFIG := config@ac02

	BLOCKSIZE := 128k
	PAGESIZE := 2048

	IMAGES += factory.bin sysupgrade.bin
	IMAGE/factory.bin := append-ubi | qsdk-ipq-factory-nand
	IMAGE/sysupgrade.bin := append-ubi | qsdk-ipq-nand

	DEVICE_PACKAGES := \
		base-files \
		busybox \
		kmod-usb3 \
		kmod-mhi-bus \
		kmod-mhi-wwan-mbim \
		kmod-mhi-wwan-ctrl \
		qmodem
endef

TARGET_DEVICES += swaiot_cpe_s10


TARGET_DEVICES := swaiot_cpe_s10
