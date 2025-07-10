#!/bin/bash
##############################################
# 0. FIRST BOOT SETUP INSTRUCTIONS (SD CARD)
##############################################

# -- STEP 1: Download Raspberry Pi OS Lite Image --
# From your Windows machine, download the latest Raspberry Pi OS Lite (.img.xz) from:
# https://www.raspberrypi.com/software/operating-systems/

# -- STEP 2: Flash SD Card with Rufus --
# Insert the 64GB microSD card
# Open Rufus (https://rufus.ie)
#  - Select the Raspberry Pi OS image
#  - Use 'DD' image mode when prompted
#  - Select device (your SD card) and flash

# -- STEP 3: Enable SSH (headless access) --
# After flashing completes:
#  - Open the boot partition of the SD card in File Explorer
#  - Add an empty file named `ssh` (no file extension) to root of the partition

# -- STEP 4: Configure Wi-Fi (headless setup) --
# In the same boot partition:
#  - Create a file named `wpa_supplicant.conf` with the following contents:

#   (Replace "WiFiSSID" and "WiFiPassword" appropriately)

country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="WiFiSSID"
    psk="WiFiPassword"
    key_mgmt=WPA-PSK
}

# Save that file to the SD card root.

# -- STEP 5: Insert SD Card and Boot Pi --
# - Insert the card into your Raspberry Pi 5
# - Power it on
# - It should auto-connect to Wi-Fi and allow SSH logins to `pi@raspberrypi.local`

# -- STEP 6: SSH into the Pi from your laptop --
# Run in terminal: ssh pi@raspberrypi.local
# Default password is: raspberry

# -- STEP 7: Run Full Setup Script --
# Clone your setup repo:
# git clone https://github.com/chrporter22/pi5_setup.git
# cd pi5_setup

set -e

# === Load secrets from .env if available ===
if [[ -f ".env" ]]; then
  source .env
else
  echo "Missing .env file. Please create one with your Wi-Fi and user credentials."
  exit 1
fi

# === CONFIG ===
SD_DEV="/dev/mmcblk0"
BOOT_PART="${SD_DEV}p1"
SWAP_PART="${SD_DEV}p2"
ROOT_PART="${SD_DEV}p3"
MOUNTPOINT="/mnt/arch"

HOSTNAME="rpi-arch"
USERNAME="pi"
DOTFILES_REPO="https://github.com/chrporter22/dotfiles.git"

echo "WARNING: This will wipe the current OS on the SD card ($SD_DEV) and install Arch Linux."
read -p "Proceed with SD install? (y/N): " CONFIRM
[[ "$CONFIRM" != "y" ]] && echo "Aborting." && exit 1

# === 1. Install essentials on Raspberry Pi OS Lite ===
sudo apt update
PACKAGES=(git curl wget unzip bsdtar arch-install-scripts stow parted)
for pkg in "${PACKAGES[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo "$pkg already installed"
    else
        echo "Installing $pkg..."
        sudo apt install -y "$pkg"
    fi
done

# === 2. Partition SD: BOOT + SWAP (4GB) + ROOT ===
echo "Partitioning SD card..."
sgdisk -Z $SD_DEV
sgdisk -n 1:0:+256M -t 1:0700 -c 1:"BOOT" $SD_DEV
sgdisk -n 2:0:+4G    -t 2:8200 -c 2:"SWAP" $SD_DEV
sgdisk -n 3:0:0      -t 3:8300 -c 3:"ROOT" $SD_DEV

mkfs.vfat -F32 $BOOT_PART
mkswap $SWAP_PART
mkfs.ext4 $ROOT_PART

# === 3. Mount and Bootstrap Arch ===
mkdir -p $MOUNTPOINT
mount $ROOT_PART $MOUNTPOINT
mkdir -p $MOUNTPOINT/boot
mount $BOOT_PART $MOUNTPOINT/boot

echo "Validating mounts..."
mount | grep "$MOUNTPOINT" || { echo "Mount failed. Aborting."; exit 1; }
echo "Mounts confirmed"

curl -LO http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz
bsdtar -xpf ArchLinuxARM-rpi-aarch64-latest.tar.gz -C $MOUNTPOINT
rm ArchLinuxARM-rpi-aarch64-latest.tar.gz

# === 4. Chroot prep ===
mount --bind /dev  $MOUNTPOINT/dev
mount --bind /proc $MOUNTPOINT/proc
mount --bind /sys  $MOUNTPOINT/sys
cp /etc/resolv.conf $MOUNTPOINT/etc/

# === 5. Setup inside Arch chroot ===
arch-chroot $MOUNTPOINT /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
echo "$HOSTNAME" > /etc/hostname

pacman-key --init && pacman-key --populate archlinuxarm
pacman -Syu --noconfirm linux-rpi linux-rpi-headers git stow sudo networkmanager iwd base-devel

useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PI_PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
systemctl enable NetworkManager

# Enable swap
echo "$SWAP_PART none swap sw 0 0" >> /etc/fstab
swapon $SWAP_PART

# Wi-Fi config (NetworkManager)
cat > /etc/NetworkManager/system-connections/wifi.nmconnection <<WIFI
[connection]
id=wifi
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=$WIFI_SSID

[wifi-security]
key-mgmt=wpa-psk
psk=$WIFI_PASS

[ipv4]
method=auto
[ipv6]
method=auto
WIFI

chmod 600 /etc/NetworkManager/system-connections/wifi.nmconnection

# Dotfiles setup
cd /home/$USERNAME
git clone $DOTFILES_REPO dotfiles
cd dotfiles
# stow */
chown -R $USERNAME:$USERNAME /home/$USERNAME
sudo -u $USERNAME bash ./data_sci_install.sh
EOF

# === 6. Final Cleanup ===
umount -R $MOUNTPOINT
echo "Arch Linux installed to SD! Reboot your Pi to enter your new dev/data sci setup!"


# === 6.1 Reboot function ===
prompt_reboot() {
    echo -e "\nInstallation successful. Reboot now? (Y/n)"
    read -r reboot
    if [[ $reboot == "Y" || $reboot == "y" ]]; then
        reboot
    fi
}


# Call function
prompt_reboot

