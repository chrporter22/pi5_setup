#!/bin/bash

# =====================================================
# Build and install brcmfmac Wi-Fi module inside chroot
# =====================================================

set -e

log_broadcom_build() {
    local log_file="broadcom_build.log"
    local user_name="${1:-unknown}"
    local timestamp="$(date +'%Y-%m-%d %H:%M:%S')"
    local kernel_version="$(uname -r)"

    echo "[$timestamp] brcmfmac build by: $user_name | kernel: $kernel_version" >> "$log_file"
}

log_broadcom_build "$(whoami)"

# Clone Raspberry Pi kernel source
git clone --depth=1 https://github.com/raspberrypi/linux /usr/src/rpi-wifi-src
cd /usr/src/rpi-wifi-src

# Clean and prep kernel source
make mrproper

# Check if reference .config exists
if [ -f /usr/lib/modules/6.12.40-2-rpi/build/.config ]; then
    cp /usr/lib/modules/6.12.40-2-rpi/build/.config .config
    make oldconfig
else
    echo "No reference .config found; generating default config"
    make defconfig
fi

make modules_prepare

# Build brcmfmac module
make M=drivers/net/wireless/broadcom/brcm80211/brcmfmac

# Install module
mkdir -p /lib/modules/6.12.40-2-rpi/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac
cp drivers/net/wireless/broadcom/brcm80211/brcmfmac/brcmfmac.ko \
   /lib/modules/6.12.40-2-rpi/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac/

depmod -a
modprobe brcmfmac || echo "Module will load after reboot"

echo "brcmfmac module successfully built and installed"
