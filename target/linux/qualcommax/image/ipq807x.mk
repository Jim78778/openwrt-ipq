define Device/swaiot_cpe_s10
	$(call Device/FitImage)
	$(call Device/UbiFit)

	DEVICE_VENDOR := Swaiot
	DEVICE_MODEL := CPE-S10
	SOC := ipq8071

	DEVICE_DTS := ipq8071-s10
	BLOCKSIZE := 128k
	PAGESIZE := 2048

	DEVICE_PACKAGES := \
		kmod-usb3 \
		kmod-mhi-bus \
		kmod-mhi-wwan-mbim \
		kmod-mhi-wwan-ctrl \
		qmodem
endef

TARGET_DEVICES += swaiot_cpe_s10
