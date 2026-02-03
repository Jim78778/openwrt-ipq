#!/bin/bash
set -euo pipefail

echo "==> DIY script start"

OPENWRT_DIR="${OPENWRT_DIR:-$(pwd)}"
DIYPATH="$OPENWRT_DIR/package/diypath"
DL_DIR="$OPENWRT_DIR/dl"
CONFIG_FILE="$OPENWRT_DIR/.config"

mkdir -p "$DIYPATH" "$DL_DIR"

###############################################################################
echo "==> [0/8] 基础 sanity check"
###############################################################################

cd "$OPENWRT_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ .config 不存在，CI 流程错误"
    exit 1
fi

###############################################################################
echo "==> [1/8] 修复递归 / 影子依赖（核心）"
###############################################################################

cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"

# 1.1 禁用 sqm-scripts-nss（递归依赖元凶）
sed -i '/^CONFIG_PACKAGE_sqm-scripts-nss=/d' "$CONFIG_FILE" || true
echo "# CONFIG_PACKAGE_sqm-scripts-nss is not set" >> "$CONFIG_FILE"

# 1.2 使用 iptables-legacy
sed -i '/^CONFIG_PACKAGE_iptables-nft=/d' "$CONFIG_FILE" || true
echo "# CONFIG_PACKAGE_iptables-nft is not set" >> "$CONFIG_FILE"
echo "CONFIG_PACKAGE_iptables=y" >> "$CONFIG_FILE"

# 1.3 清理已知会拉出桌面/多媒体链的包
for pkg in \
    gst1-plugins-base \
    onionshare-cli \
    luci-app-advanced-reboot \
    iptasn \
    perl-net-dns-sec
do
    sed -i "/^CONFIG_PACKAGE_${pkg}=/d" "$CONFIG_FILE" || true
    echo "# CONFIG_PACKAGE_${pkg} is not set" >> "$CONFIG_FILE"
done

###############################################################################
echo "==> [2/8] qmodem 依赖修复（关键）"
###############################################################################

QMODEM_MK="package/feeds/qmodem/qmodem/Makefile"

if [ -f "$QMODEM_MK" ]; then
    echo "修复 qmodem 依赖定义..."

    sed -i \
      's/+kmod-mhi-wwan/+kmod-mhi-bus +kmod-mhi-net +kmod-mhi-wwan-ctrl/g' \
      "$QMODEM_MK"

    sed -i \
      's/+quectel-CM-5G//g; s/+quectel-cm//g' \
      "$QMODEM_MK"

    echo "✅ qmodem Makefile 依赖已修复"
else
    echo "⚠️ qmodem Makefile 未找到（feeds 可能未安装）"
fi

###############################################################################
echo "==> [3/8] 强制目标设备（防止 image 被跳过）"
###############################################################################

sed -i '/^CONFIG_TARGET_qualcommax/d' "$CONFIG_FILE"
echo "CONFIG_TARGET_qualcommax=y" >> "$CONFIG_FILE"
echo "CONFIG_TARGET_qualcommax_ipq807x=y" >> "$CONFIG_FILE"
echo "CONFIG_TARGET_qualcommax_ipq807x_DEVICE_swaiot_cpe_s10=y" >> "$CONFIG_FILE"


###############################################################################
echo "==> [7/8] 最终 defconfig 前校验"
###############################################################################

echo "==== 关键配置确认 ===="
grep -E \
"CONFIG_TARGET_qualcommax_ipq807x_DEVICE_swaiot_cpe_s10=y|
CONFIG_PACKAGE_qmodem=y|
CONFIG_PACKAGE_kmod-mhi" \
"$CONFIG_FILE" || true

###############################################################################
echo "==> [8/8] Done"
###############################################################################

echo "========================================"
echo "DIY 脚本执行完成（稳定版）"
echo "========================================"
