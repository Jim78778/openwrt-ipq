define Device/swaiot_cpe_s10
  # 使用 FIT Image
  $(call Device/FitImage)

  # NAND + UBI
  $(call Device/UbiFit)

  DEVICE_VENDOR := Swaiot
  DEVICE_MODEL := CPE-S10
  DEVICE_VARIANT := NAND

  SOC := ipq807x
  DEVICE_DTS := ipq8071-s10

  # NAND 参数
  BLOCKSIZE := 128k
  PAGESIZE := 2048

  # kernel 放进 UBI（关键）
  KERNEL_IN_UBI := 1

  # 明确 kernel 构建方式（关键）
  KERNEL := kernel-bin | libdeflate-gzip | fit gzip \
        $(KDIR)/image-$(DEVICE_DTS).dtb

  # 只生成 UBI factory + sysupgrade
  IMAGES := factory.ubi sysupgrade.bin

  IMAGE/factory.ubi := ubi
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata

  # 设备默认包
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
