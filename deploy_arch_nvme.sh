#!/bin/bash
##############################################
# FIRST BOOT SETUP INSTRUCTIONS (NVME SSD)
##############################################

# -- STEP 1: Flash SD Card with Raspberry Pi Imager
# Format SD cards over 32 GB to FAT32 format
# Use latest 64 bit Raspberry Pi OS Lite (.img.xz)
# Insert the microSD card
#  - Select device (your SD card) and flash

# -- STEP 2: Enable SSH (headless access) --
# After flashing completes:
#  - Open the boot partition of the SD card in File Explorer
#  - Add an empty file named `ssh` (no file extension) to root of the partition

# -- STEP 3: Configure Wi-Fi (headless setup) --
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

# -- STEP 4: Insert SD Card and Boot Pi --
# - Insert the card into your Raspberry Pi 5
# - Power it on
# - It should auto-connect to Wi-Fi and allow SSH logins to `pi@raspberrypi.local`

# -- STEP 5: SSH into the Pi from your laptop --
# Run in terminal: ssh pi@raspberrypi.local
# Default password is: raspberry (unless changed with customization setting during os
# flash)

# -- STEP 6: Run Full Setup Script --
# Create an .env file for arch password & clone your setup repo:
# git clone https://github.com/chrporter22/pi5_setup.git
# cd pi5_setup
# With 'vi' create an '.env' file with WIFI, WIFI Password, and user password variables for reference
# Run sh deploy_arch_sd.sh script


set -e


# === Load secrets from .env if available ===
if [[ -f ".env" ]]; then
  source .env
else
  echo "Missing .env file. Please create one with your Wi-Fi and user credentials."
  exit 1
fi


# === CONFIG ===
DOTFILES_REPO="https://github.com/chrporter22/dotfiles.git"
NVME_DEV="/dev/nvme0n1"
MOUNTPOINT="/mnt"
HOSTNAME="rpi-arch"
USERNAME="pi5_nvme"


# === 1. Install essentials on Pi OS Lite ===
sudo apt update


# List of required packages
PACKAGES=(git curl wget unzip bsdtar arch-install-scripts stow parted)


# Check and install missing packages
for pkg in "${PACKAGES[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        echo "$pkg is already installed"
    else
        echo "Installing $pkg..."
        sudo apt install -y "$pkg"
    fi
done


# === 2. Partition NVMe: EFI + SWAP + ROOT ===
sgdisk -Z $NVME_DEV  # Zap existing partitions

# Partition 1: 512MB EFI System
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" $NVME_DEV

# Partition 2: 16GB Swap
sgdisk -n 2:0:+16G -t 2:8200 -c 2:"SWAP" $NVME_DEV

# Partition 3: Use remaining space for Root filesystem
sgdisk -n 3:0:0 -t 3:8300 -c 3:"ROOT" $NVME_DEV

# === 2.1 Format partitions ===
mkfs.vfat -F32 "${NVME_DEV}p1"
mkswap "${NVME_DEV}p2"
mkfs.ext4 "${NVME_DEV}p3"


# === 3. Mount and Bootstrap Arch ===
mkdir -p $MOUNTPOINT
mount "${NVME_DEV}p3" $MOUNTPOINT  # ROOT is now p3
mkdir -p $MOUNTPOINT/boot
mount "${NVME_DEV}p1" $MOUNTPOINT/boot  # EFI

# === 3.1 Validate mounts ===
echo "Validating NVMe mounts..."
sleep 1
echo "Mounted devices under $MOUNTPOINT:"
mount | grep "$MOUNTPOINT" || { echo "Error: Required partitions not mounted correctly. Aborting."; exit 1; }
echo "Mount validation passed."

# === 3.2 Proceed with Arch bootstrap ===
curl -LO http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz
bsdtar -xpf ArchLinuxARM-rpi-aarch64-latest.tar.gz -C $MOUNTPOINT


# === 4. Chroot prep ===
mount --bind /dev $MOUNTPOINT/dev
mount --bind /proc $MOUNTPOINT/proc
mount --bind /sys $MOUNTPOINT/sys
cp /etc/resolv.conf $MOUNTPOINT/etc/


# === 5. chroot Setup ===
arch-chroot $MOUNTPOINT /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc
echo "$HOSTNAME" > /etc/hostname

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

# Coral TPU support
# echo "dtoverlay=pineboards-hat-ai" >> /boot/config.txt
# pacman -S --noconfirm libedgetpu
EOF


# === 6. Ensure NVMe Boot Priority ===
ensure_nvme_boot_enabled() {
  CONFIG_FILE="/boot/firmware/config.txt"
  [[ ! -f $CONFIG_FILE ]] && CONFIG_FILE="/boot/config.txt"

  if [[ -f "$CONFIG_FILE" ]]; then
    echo "Config file found at: $CONFIG_FILE"

    if ! grep -q "PROGRAM_USB_BOOT_MODE=1" "$CONFIG_FILE"; then
      echo "Adding PROGRAM_USB_BOOT_MODE=1..."
      echo "PROGRAM_USB_BOOT_MODE=1" | sudo tee -a "$CONFIG_FILE"
    else
      echo "PROGRAM_USB_BOOT_MODE already set"
    fi

    if ! grep -q "boot_order=0xf416" "$CONFIG_FILE"; then
      echo "Setting boot_order=0xf416 for NVMe priority..."
      echo "boot_order=0xf416" | sudo tee -a "$CONFIG_FILE"
    else
      echo "boot_order=0xf416 already set"
    fi
  else
    echo "Could not find config.txt!"
    return 1
  fi
}


# === 6.1 Ensure NVMe Boot Priority ===
ensure_nvme_boot_enabled


# === 7. Final Bootloader Sync ===
cp -r $MOUNTPOINT/boot/* /boot/
umount -R $MOUNTPOINT
echo "Pi5 bootstrapped with Arch, NVMe, swap, Wi-Fi, and your dev stack!"


# === 8. Reboot function ===
prompt_reboot() {
    echo -e "\nInstallation successful. Reboot now? (Y/n)"
    read -r reboot
    if [[ $reboot == "Y" || $reboot == "y" ]]; then
        reboot
    fi
}

# === 8.1 Call function ===
prompt_reboot
