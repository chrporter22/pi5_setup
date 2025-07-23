#!/bin/bash
##############################################
# FIRST BOOT SETUP INSTRUCTIONS (SD CARD)
##############################################

# -- STEP 1: Flash SD Card with Raspberry Pi Imager
# Format SD cards over 32 GB to FAT32 format
# Use latest 64 bit Raspberry Pi OS Lite (.img.xz)
# Insert the microSD card
#  - Select the Raspberry Pi OS image
#  - Select device (your SD card) and flash

# -- STEP 2: Enable SSH (headless access) --
# After flashing completes:
#  - Open the boot partition of the SD card in File Explorer
#  - Add an empty file named `ssh` (no file extension) to root of the partition

# -- STEP 3: Insert SD Card and Boot Pi --
# - Insert the card into your Raspberry Pi 5
# - Connect ethernet cable to router & power on
# - It should auto-connect via Ethernet and allow SSH logins to `pi@raspberrypi.local`

# -- STEP 4: Connection via Ethernet (headless setup) --
#  - Access Router Connected Device Page and locate Raspberry Pi5 IP address or grep for
#  IPv4

# -- STEP 5: SSH into the Pi from your laptop --
# Run in terminal: ssh pi@raspberrypi.local
# Default password is: raspberry (unless changed under customization settings during os
# flash)

# -- STEP 6: Run Full Setup Script --
# Install git and vim
# git clone https://github.com/chrporter22/pi5_setup.git
# cd pi5_setup
# Create an .env file for repo setup:
# Add SSID, WIFI password, and user password 
# Run bash deploy_arch_sd.sh script

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
BOOT_PART="${SD_DEV}p3"
SWAP_PART="${SD_DEV}p4"
ROOT_PART="${SD_DEV}p5"
MOUNTPOINT="/mnt"

HOSTNAME="rpi-arch"
USERNAME="pi5_sd"
DOTFILES_REPO="https://github.com/chrporter22/dotfiles.git"

echo "WARNING: This will wipe the current OS on the SD card ($SD_DEV) and install Arch Linux."
read -p "Proceed with SD install? (y/N): " CONFIRM
[[ "$CONFIRM" != "y" ]] && echo "Aborting." && exit 1

# === 1. Install essentials on Raspberry Pi OS Lite ===
sudo apt update
PACKAGES=(git curl wget unzip libarchive-tools arch-install-scripts stow parted)
for pkg in "${PACKAGES[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo "$pkg already installed"
    else
        echo "Installing $pkg..."
        sudo apt install -y "$pkg"
    fi
done
 # === 2. Partition SD: Arch BOOT + SWAP (4GB) + ROOT ===
echo "Partitioning SD card for Arch Linux..."

# Wipe all previous partition data (optional, careful if live!)
sgdisk -Z $SD_DEV

# Create new Arch-specific partitions
sgdisk -n 4:0:+256M -t 4:0700 -c 3:"ARCH_BOOT" $SD_DEV   # Arch Boot
sgdisk -n 5:0:+4G    -t 5:8200 -c 4:"ARCH_SWAP" $SD_DEV   # Swap
sgdisk -n 6:0:0      -t 6:8300 -c 5:"ARCH_ROOT" $SD_DEV   # Root

# Format boot partition
mkfs.vfat -F32 ${SD_DEV}p3

# Format swap (if not in use)
if mount | grep -q "${SD_DEV}p4"; then
  echo "Unmounting active swap partition before formatting..."
  sudo swapoff ${SD_DEV}p4 || true
  sudo umount ${SD_DEV}p4 || true
fi
sudo mkswap ${SD_DEV}p4

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
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc

echo "$HOSTNAME" > /etc/hostname

# Hosts file
cat > /etc/hosts <<HOSTS
127.0.0.1       localhost
::1             localhost
127.0.1.1       ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

pacman-key --init && pacman-key --populate archlinuxarm
pacman -Syu --noconfirm linux-rpi linux-rpi-headers git stow sudo networkmanager iwd base-devel

useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PI_PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
systemctl enable NetworkManager

# Enable fstab & swap
echo "$BOOT_PART /boot vfat defaults 0 1" >> /etc/fstab
echo "$SWAP_PART none swap sw 0 0" >> /etc/fstab
echo "$ROOT_PART / ext4 defaults 0 2" >> /etc/fstab
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

