define Device/swaiot_cpe_s10
  $(call Device/UbiFit)

  DEVICE_VENDOR := Swaiot
  DEVICE_MODEL := CPE-S10
  DEVICE_VARIANT := NAND

  SOC := ipq8071
  DEVICE_DTS := ipq8071-s10

  BLOCKSIZE := 128k
  PAGESIZE := 2048

  IMAGES := factory.bin sysupgrade.bin

  IMAGE/factory.bin := qsdk-ipq-factory-nand
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata

  DEVICE_PACKAGES := \
        kmod-usb3 \
        kmod-mhi-bus \
        kmod-mhi-net \
        kmod-mhi-wwan-ctrl \
        kmod-mhi-wwan-mbim \
        luci-proto-qmi \
        uqmi
endef

TARGET_DEVICES += swaiot_cpe_s10
