#!/bin/bash
set -euo pipefail

echo "==> DIY script start"

OPENWRT_DIR="${OPENWRT_DIR:-$(pwd)}"
DIYPATH="$OPENWRT_DIR/package/diypath"
DL_DIR="$OPENWRT_DIR/dl"

mkdir -p "$DIYPATH" "$DL_DIR"

###############################################################################
echo "==> [0/7] 修复递归依赖问题"
###############################################################################

CONFIG_FILE="$OPENWRT_DIR/.config"

if [ -f "$CONFIG_FILE" ]; then
    echo "检查并修复递归依赖问题..."
    
    # 备份原始配置
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
    
    # 修复1: 禁用 sqm-scripts-nss (递归依赖的核心)
    echo "禁用 sqm-scripts-nss 以打破递归循环..."
    sed -i '/^CONFIG_PACKAGE_sqm-scripts-nss=/d' "$CONFIG_FILE" 2>/dev/null || true
    echo "# CONFIG_PACKAGE_sqm-scripts-nss is not set" >> "$CONFIG_FILE"
    
    # 修复2: 切换到 iptables-legacy (避免 iptables-nft 的依赖问题)
    echo "切换到 iptables-legacy..."
    sed -i '/^CONFIG_PACKAGE_iptables-nft=/d' "$CONFIG_FILE" 2>/dev/null || true
    sed -i '/^CONFIG_PACKAGE_iptables-zz-legacy=/d' "$CONFIG_FILE" 2>/dev/null || true
    echo "# CONFIG_PACKAGE_iptables-nft is not set" >> "$CONFIG_FILE"
    echo "CONFIG_PACKAGE_iptables=y" >> "$CONFIG_FILE"
    echo "CONFIG_PACKAGE_iptables-mod-conntrack-extra=y" >> "$CONFIG_FILE"
    
    # 修复3: 禁用其他可能导致循环的包
    echo "禁用其他可能导致递归依赖的包..."
    for pkg in iptasn perl-net-dns-sec; do
        sed -i "/^CONFIG_PACKAGE_${pkg}=/d" "$CONFIG_FILE" 2>/dev/null || true
        echo "# CONFIG_PACKAGE_${pkg} is not set" >> "$CONFIG_FILE"
    done
    
    echo "✅ 递归依赖修复完成"
else
    echo "⚠️  .config 不存在，跳过递归依赖修复"
fi

###############################################################################
echo "==> [1/7] 合并 ci.config 配置"
###############################################################################

CI_CONFIG="$OPENWRT_DIR/ci.config"
CURRENT_CONFIG="$OPENWRT_DIR/.config"

if [ -f "$CI_CONFIG" ] && [ -f "$CURRENT_CONFIG" ]; then
    echo "检测到 ci.config 和 .config，开始合并配置..."
    
    # 备份当前配置
    cp "$CURRENT_CONFIG" "${CURRENT_CONFIG}.pre-merge"
    
    echo "应用 ci.config 到当前配置（覆盖策略）..."
    
    # 只处理 CONFIG_ 开头的有效配置行
    while IFS= read -r line; do
        # 跳过注释和空行
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^# ]] && continue
        
        # 只处理 CONFIG_ 开头的配置
        if [[ "$line" =~ ^(CONFIG_[A-Za-z0-9_]+)=(.*)$ ]]; then
            config_name="${BASH_REMATCH[1]}"
            config_value="${BASH_REMATCH[2]}"
            
            # 删除现有设置
            sed -i "/^$config_name=/d" "$CURRENT_CONFIG" 2>/dev/null || true
            sed -i "/^# $config_name is not set/d" "$CURRENT_CONFIG" 2>/dev/null || true
            
            # 添加新设置
            if [[ "$config_value" == "n" ]]; then
                echo "# $config_name is not set" >> "$CURRENT_CONFIG"
            else
                echo "$line" >> "$CURRENT_CONFIG"
            fi
        fi
    done < "$CI_CONFIG"
    
    # 排序配置，保持文件整洁
    echo "排序配置..."
    TEMP_FILE=$(mktemp)
    grep -vE '^CONFIG_' "$CURRENT_CONFIG" > "$TEMP_FILE"
    grep -E '^CONFIG_' "$CURRENT_CONFIG" | sort -u >> "$TEMP_FILE"
    mv "$TEMP_FILE" "$CURRENT_CONFIG"
    
    echo "✅ 配置合并完成（备份: ${CURRENT_CONFIG}.pre-merge）"
elif [ -f "$CI_CONFIG" ]; then
    echo "没有现有 .config，直接使用 ci.config"
    cp "$CI_CONFIG" "$CURRENT_CONFIG"
    echo "✅ 配置初始化完成"
else
    echo "⚠️  ci.config 不存在，跳过配置合并"
fi

###############################################################################
echo "==> [2/7] Preload NSS Packages source"
###############################################################################

cd "$DL_DIR"

if [ ! -d nss-packages ]; then
  echo "==> Clone qosmio/nss-packages (public)"
  git clone --depth=1 https://github.com/qosmio/nss-packages.git
else
  echo "==> nss-packages already exists"
fi

# 精简 NSS：只保留 WWAN + WiFi
echo "==> [2.1/7] Prune NSS packages (keep only WWAN + WiFi)"
cd nss-packages
find . -maxdepth 1 -type d ! -name '.' ! -name 'wwan' ! -name 'wifi' -exec rm -rf {} +
cd ..

if [ ! -f nss-packages-preload.tar.gz ]; then
  echo "==> Creating tarball nss-packages-preload.tar.gz"
  tar -czf nss-packages-preload.tar.gz nss-packages
else
  echo "==> Tarball already exists"
fi

ls -lh nss-packages-preload.tar.gz

###############################################################################
echo "==> [3/7] Force OpenWrt NSS feed use local tarball"
###############################################################################

NSS_FEED="package/feeds/nss_packages"

if [ -d "$OPENWRT_DIR/$NSS_FEED" ]; then
  echo "==> Patching nss_packages Makefiles to use local tarball"
  find "$OPENWRT_DIR/$NSS_FEED" -name 'Makefile*' -print0 | while IFS= read -r -d '' MK; do
    sed -i \
      -e 's/^PKG_SOURCE_PROTO:=.*/# &/' \
      -e "s|^PKG_SOURCE_URL:=.*|PKG_SOURCE_URL:=file://$DL_DIR|" \
      -e 's/^PKG_SOURCE_VERSION:=.*/# &/' \
      "$MK"

    grep -q '^PKG_SOURCE:=' "$MK" || \
      sed -i "1i PKG_SOURCE:=nss-packages-preload.tar.gz\nPKG_HASH:=skip\n" "$MK"
  done

  # 修复 OpenWrt 递归依赖问题（select → depends on）
  echo "==> [3.1/7] Fix recursive dependency for kmod-tls"
  sed -i 's/select PACKAGE_kmod-tls/depends on PACKAGE_kmod-tls/g' "$OPENWRT_DIR/package/libs/openssl/Config.in"

else
  echo "WARNING: NSS feed dir not found"
fi

###############################################################################
echo "==> [4/7] DIYPATH link"
###############################################################################

ln -snf "$DL_DIR/nss-packages" "$DIYPATH/nss-packages"
echo "==> DIYPATH created: $DIYPATH/nss-packages -> $DL_DIR/nss-packages"

###############################################################################
echo "==> [5/7] Optional clean"
###############################################################################

# 如果需要清理 NSS 包缓存，取消注释
# make -C "$OPENWRT_DIR" package/nss_packages/clean

###############################################################################
echo "==> [6/7] 配置验证和总结"
###############################################################################

if [ -f "$CONFIG_FILE" ]; then
    echo "=== 配置验证 ==="
    
    # 检查 NSS 配置
    nss_enabled=$(grep -c "^CONFIG_PACKAGE_kmod-qca-nss-drv=y" "$CONFIG_FILE" || true)
    if [ "$nss_enabled" -gt 0 ]; then
        echo "✅ NSS 驱动已启用"
    else
        echo "⚠️  NSS 驱动未启用"
    fi
    
    # 检查 mac80211 配置
    mac80211_enabled=$(grep -c "^CONFIG_PACKAGE_kmod-mac80211=y" "$CONFIG_FILE" || true)
    if [ "$mac80211_enabled" -gt 0 ]; then
        echo "✅ mac80211 无线驱动已启用"
    else
        echo "ℹ️  mac80211 无线驱动未启用"
    fi
    
    # 检查目标设备
    target_config=$(grep "^CONFIG_TARGET_" "$CONFIG_FILE" | head -3 || true)
    if [ -n "$target_config" ]; then
        echo "✅ 目标设备配置:"
        echo "$target_config"
    fi
    
    echo ""
    echo "=== 配置统计 ==="
    echo "总配置行数: $(wc -l < "$CONFIG_FILE")"
    echo "启用的包: $(grep -c '^CONFIG_PACKAGE.*=y' "$CONFIG_FILE" || echo 0)"
    echo "禁用的包: $(grep -c '^# CONFIG_PACKAGE.*is not set' "$CONFIG_FILE" || echo 0)"
    
else
    echo "WARNING: .config not found, skip config verification"
fi

###############################################################################
echo "==> [7/7] Done"
###############################################################################

echo ""
echo "========================================"
echo "DIY 脚本执行完成!"
echo "========================================"
echo "已执行的操作:"
echo "1. 修复递归依赖问题"
echo "2. 合并 ci.config 配置"
echo "3. 精简 NSS 包 (WWAN + WiFi only)"
echo "4. 配置 NSS feed 使用本地 tarball"
echo "5. 创建 DIYPATH 链接"
echo "========================================"
