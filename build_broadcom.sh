# Build and install brcmfmac Wi-Fi module inside chroot
set -e

g_broadcom_build() {
    local log_file="/var/log/broadcom_build.log"
    local user_name="${1:-unknown}"
    local timestamp="$(date +'%Y-%m-%d %H:%M:%S')"
    local kernel_version="$(uname -r)"

    echo "[$timestamp] brcmfmac build by: $user_name | kernel: $kernel_version" >> "$log_file"

log_broadcom_build "$(whoami)"


git clone --depth=1 https://github.com/raspberrypi/linux /usr/src/rpi-wifi-src
cd /usr/src/rpi-wifi-src

make mrproper
cp /usr/lib/modules/$(uname -r)/build/.config .config
make oldconfig
make modules_prepare

make M=drivers/net/wireless/broadcom/brcm80211/brcmfmac

mkdir -p /lib/modules/$(uname -r)/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac
cp drivers/net/wireless/broadcom/brcm80211/brcmfmac/brcmfmac.ko \
   /lib/modules/$(uname -r)/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac/

depmod -a
modprobe brcmfmac || echo "Module will load after reboot"

echo "brcmfmac module successfully built and installed"
