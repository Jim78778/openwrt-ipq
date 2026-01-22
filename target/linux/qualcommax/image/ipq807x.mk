define Device/swaiot_cpe_s10
  $(call Device/FitImage)
  $(call Device/UbiFit)

  DEVICE_VENDOR := Swaiot
  DEVICE_MODEL := CPE-S10
  DEVICE_VARIANT := NAND

  SOC := ipq807x
  DEVICE_DTS := ipq8074-s10

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
        uqmi \
        kmod-usb-net-rndis \
        kmod-usb-net-cdc-ether
endef

TARGET_DEVICES += swaiot_cpe_s10


TARGET_DEVICES += swaiot_cpe_s10


