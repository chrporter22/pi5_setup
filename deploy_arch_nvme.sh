#!/bin/bash
##############################################
# FIRST BOOT SETUP INSTRUCTIONS (NMVE SSD)
##############################################

# -- STEP 1: Flash SD Card with Raspberry Pi Imager
# Format SD cards over 32 GB to FAT32 format
# Use latest 64 bit Raspberry Pi OS Lite (.img.xz)
#  - Select the Raspberry Pi OS image
#  - Select device (your SD card) and flash

# -- STEP 2: Enable SSH (headless access) --
# After flashing completes:
#  - Open the boot partition of the SD card in File Explorer
#  - Add an empty file named `ssh` (no file extension) to root of the partition

# -- STEP 3: Insert SD Card and Boot Pi --
# - Insert the card into your Raspberry Pi 5
# - Connect ethernet cable to router & power on
# - It should auto-connect via Ethernet and allow SSH logins to `user@raspberrypi.local`

# -- STEP 4: Connection via Ethernet (headless setup) --
#  - Access Router Connected Device Page and locate Raspberry Pi5 IP address or grep for
#  IPv4

# -- STEP 5: SSH into the Pi from your laptop --
# Run in terminal: ssh user@raspberrypi.local
# Default password is: raspberry (unless changed under customization settings during os
# flash)

# -- STEP 6: Run Full Setup Script --
# Format target M.2 NVME SSD with Raspberry Pi Imager
# Insert NVME via pcie
# Check hardware with 'lsblk' to review available
# Install git and vim
# git clone https://github.com/chrporter22/pi5_setup.git
# cd pi5_setup
# Create an .env file for repo setup:
# Add WIFI_SSID, WIFI_PASS, WIFI_Country, and PI_PASSWORD
# Run sudo bash deploy_arch_nvme.sh script

# -- STEP 7: Remove Previous SSH Keys (if needed) | Set locale manually at first boot 
# User may need to delete ssh/known_hosts if fingerprint error for ssh tunnel
# Remove previous fingerprint ids /root/.ssh/known_hosts
# Test pacman -Su
# 'sudo nvim /etc/locale.gen'
# Find this line and uncomment it (remove the #):
# en_US.UTF-8 UTF-8
# 2. Generate locales
# Run: 'sudo locale-gen'
# 3. Set system-wide locale
# Create or edit /etc/locale.conf:
# 'sudo nano /etc/locale.conf'
# Add: 'LANG=en_US.UTF-8'
# Locale fixes nerdfont and icon error in tmux

# --- Additional Information ---
# If you're trying to set EEPROM to boot from NVMe (BOOT_ORDER=0xf416):
# This must be done from a running Raspberry Pi — not in chroot.
# Boot into Raspberry Pi (from SD card), then run:
# 'sudo pacman -S rpi-eeprom'
# 'sudo rpi-eeprom-config --edit'
#
# 'BOOT_ORDER=0xf416'
# 'PCIE_PROBE=1'

set -e

# === Load secrets from .env if available ===
if [[ -f ".env" ]]; then
  source .env
else
  echo "Missing .env file. Please create one with your Wi-Fi and user credentials."
  exit 1
fi

# === CONFIG (For NVMe install, booting from SD) ===
SD_DEV="/dev/nvme0n1"
BOOT_PART="${SD_DEV}p1"
SWAP_PART="${SD_DEV}p2"
ROOT_PART="${SD_DEV}p3"
MOUNTPOINT="/mnt"
DOWNLOADDIR=/tmp/pi

HOSTNAME="rpi-arch"
USERNAME="pi5_nvme"
DOTFILES_REPO="https://github.com/chrporter22/dotfiles.git"

echo "WARNING: This will wipe the current OS on the NVME SSD ($SD_DEV) and install Arch Linux."
read -p "Proceed with NVME install? (y/N): " CONFIRM
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
echo "Partitioning NVME for Arch Linux..."

# Wipe all previous partition data (optional, careful if live!)
sgdisk -Z $SD_DEV

# Create partitions
sgdisk -n 1:0:+256M -t 1:0700 -c 1:"boot" $SD_DEV
sgdisk -n 2:0:+4G -t 2:8200 -c 2:"swap" $SD_DEV
sgdisk -n 3:0:0 -t 3:8300 -c 3:"root" $SD_DEV

# Format boot partition
mkfs.vfat -F32 ${SD_DEV}p1

# Format swap (if not in use)
if mount | grep -q "${SD_DEV}p2"; then
  echo "Unmounting active swap partition before formatting..."
  sudo swapoff ${SD_DEV}p2 || true
  sudo umount ${SD_DEV}p2 || true
fi

# Format for swap
sudo mkswap ${SD_DEV}p2

# Format root partition as ext4
mkfs.ext4 -L root ${SD_DEV}p3

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

rm -rf ${MOUNTPOINT}/boot/*

mkdir -p ${DOWNLOADDIR}/linux-rpi
pushd ${DOWNLOADDIR}/linux-rpi
curl -JLO http://mirror.archlinuxarm.org/aarch64/core/linux-rpi-6.12.43-1-aarch64.pkg.tar.xz
tar xf *
cp -rf boot/* ${MOUNTPOINT}/boot/
popd

cp ${DOWNLOADDIR}/linux-rpi/*.pkg.tar.xz ${MOUNTPOINT}/root/

# === 4. Setup inside Arch chroot ===
arch-chroot $MOUNTPOINT /bin/bash <<EOF
set -e

ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc

# Enable en_US.UTF-8 locale
# sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
# locale-gen
#
# echo "LANG=en_US.UTF-8" > /etc/locale.conf
# export LANG=en_US.UTF-8
# export LC_ALL=en_US.UTF-8

# echo "Server = https://nj.us.mirror.archlinuxarm.org/\$arch/\$repo" >> /etc/pacman.d/mirrorlist
# sed -i '/^
#
# \[options\]
#
# /a DisableSandbox\nDisableDownloadTimeout' /etc/pacman.conf
# echo "Added 'DisableSandbox' and 'DisableDownloadTimeout' to [options] in pacman.conf"

echo "$HOSTNAME" > /etc/hostname

# Hosts file
cat > /etc/hosts <<HOSTS
127.0.0.1       localhost
::1             localhost
127.0.1.1       ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

pacman-key --init && pacman-key --populate archlinuxarm
pacman -R linux-aarch64 --noconfirm
pacman -R uboot-raspberrypi --noconfirm

rm -rf /boot/*
pacman -Syu --noconfirm --overwrite '/boot/*' \
  linux-rpi \
  linux-rpi-headers \
  raspberrypi-bootloader \
  dosfstools \
  bc ncurses wget git stow sudo \
  networkmanager iwd base-devel

useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PI_PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

systemctl enable NetworkManager

# === Install OpenSSH ===
pacman -S --noconfirm openssh

# === Generate host keys ===
ssh-keygen -A

# === Create sshd_config if missing ===
if [[ ! -f /etc/ssh/sshd_config ]]; then
  cat > /etc/ssh/sshd_config <<CONFIG
Port 22
PermitRootLogin no
PasswordAuthentication yes
UsePAM yes
Subsystem sftp /usr/lib/ssh/sftp-server
CONFIG
fi

# === Enable sshd manually by creating symlink ===
ln -sf /usr/lib/systemd/system/sshd.service /etc/systemd/system/multi-user.target.wants/sshd.service

# === Touch a flag file if needed ===
touch /boot/ssh

# Set Wi-Fi country for regulatory domain
echo "REGDOMAIN=$WIFI_COUNTRY" > /etc/default/regulatory-domain

mkdir -p /etc/systemd/system/wireless-regdom.service.d
cat > /etc/systemd/system/wireless-regdom.service.d/env.conf <<ENV
[Service]
Environment=REGDOMAIN=$WIFI_COUNTRY
ENV

cat > /etc/systemd/system/wireless-regdom.service <<SERVICE
[Unit]
Description=Set regulatory domain for wireless

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'iw reg set \$REGDOMAIN'

[Install]
WantedBy=multi-user.target
SERVICE

systemctl enable wireless-regdom.service

# Enable fstab & swap | Get the UUID of the boot partition
BOOT_UUID=$(blkid -s UUID -o value /dev/nvme0n1p1)
BOOT_LINE="UUID=${BOOT_UUID} /boot vfat defaults 0 1"
grep -q "$BOOT_UUID" /etc/fstab || echo "$BOOT_LINE" >> /etc/fstab

# Get the UUID of the swap partition
SWAP_UUID=$(blkid -s UUID -o value /dev/nvme0n1p2)
SWAP_LINE="UUID=${SWAP_UUID} none swap sw 0 0"
grep -q "$SWAP_UUID" /etc/fstab || echo "$SWAP_LINE" >> /etc/fstab

# Get the UUID of the root partition
ROOT_UUID=$(blkid -s UUID -o value /dev/nvme0n1p3)
ROOT_LINE="UUID=${ROOT_UUID} /ext4 defaults 0 2"
grep -q "$ROOT_UUID" /etc/fstab || echo "$ROOT_LINE" >> /etc/fstab

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
chown root:root /etc/NetworkManager/system-connections/wifi.nmconnection

# Dotfiles setup
cd /home/$USERNAME
git clone $DOTFILES_REPO dotfiles
cd dotfiles
# stow */
chown -R $USERNAME:$USERNAME /home/$USERNAME
sudo -u $USERNAME bash ./data_sci_install.sh

# Kernel Info Display
echo "Kernel version inside chroot:"
uname -a
echo "=== Kernel Info ==="
echo "Version: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Compiled On: $(uname -v)"
sync
EOF

# === 5.a Prepare NVMe and Boot Config for PCIe Gen2+NVMe Boot ===
echo "Configuring NVMe PCIe Gen2 and setting NVMe as boot target..."

# Ensure required PCIe/NVMe dtparams are present (append only once)
CONFIG_FILE="${MOUNTPOINT}/boot/config.txt"
grep -q "^dtparam=pciex1" "$CONFIG_FILE" || echo "dtparam=pciex1" >> "$CONFIG_FILE"
# grep -q "^dtparam=pciex1_gen" "$CONFIG_FILE" || echo "dtparam=pciex1_gen=3" >> "$CONFIG_FILE"

echo "PCIe NVMe and boot order configured."

# === 5.b Firmware Injection and Post-config in chroot ===
arch-chroot "$MOUNTPOINT" /bin/bash <<'EOF'
set -e

echo "Injecting Broadcom firmware from Debian package..."

# Download the firmware package
wget -O /tmp/raspi-firmware.deb \
  http://archive.raspberrypi.org/debian/pool/main/r/raspi-firmware/raspi-firmware_1.20250430-4_all.deb

cd /tmp
ls -l /tmp/raspi-firmware.deb

ar x /tmp/raspi-firmware.deb
tar -xzf data.tar.gz

mkdir -p /boot

# === Define helper function ===
copy_file_if_not_exists() {
  local src="$1"
  local dest="$2"
  if [[ ! -f "$dest" ]]; then
    echo "Copying $src to $dest"
    cp "$src" "$dest"
  else
    echo "Skipping $src, already exists."
  fi
}

# === Copy bootloader and device tree files ===
copy_file_if_not_exists /tmp/boot/start.elf /boot/start.elf
copy_file_if_not_exists /tmp/boot/bootcode.bin /boot/bootcode.bin
copy_file_if_not_exists /tmp/boot/bcm2711-rpi-4-b.dtb /boot/bcm2711-rpi-4-b.dtb

# === Copy Broadcom Wi-Fi firmware ===
copy_file_if_not_exists /tmp/lib/firmware/brcm/brcmfmac43455-sdio.bin /lib/firmware/brcm/brcmfmac43455-sdio.bin

# Clean up extracted files only
rm -rf /tmp/control.tar.gz /tmp/data.tar.gz /tmp/debian-binary /tmp/raspi-firmware.deb /tmp/lib /tmp/boot

echo "Firmware and bootloader injection complete."

# Ensure brcmfmac module loads
echo "brcmfmac" > /etc/modules-load.d/brcmfmac.conf

# Check if the Broadcom firmware is present
if [[ ! -f /lib/firmware/brcm/brcmfmac43455-sdio.bin ]]; then
  echo "WARNING: Broadcom firmware not found. Wi-Fi may not work!"
fi

# Ensure Wi-Fi is enabled in config.txt
if ! grep -q "^dtparam=wifi=on" /boot/config.txt; then
  echo "dtparam=wifi=on" >> /boot/config.txt
fi

# Update cmdline.txt
echo "console=serial0,115200 console=tty1 root=LABEL=root rootfstype=ext4 fsck.repair=yes rootwait rw cfg80211.ieee80211_regdom=US" > /boot/cmdline.txt

echo "cmdline.txt updated successfully."
EOF

# # === 6. Validate kernels
validate_kernel_match() {
  BOOT_MOUNT="$1"   # Mounted boot partition path
  ROOT_MOUNT="$2"   # Mounted Arch root partition path

  BOOT_KERNEL=$(basename $(ls "$BOOT_MOUNT"/kernel*.img 2>/dev/null | head -n 1))
  ROOT_KERNEL_VER=$(chroot "$ROOT_MOUNT" uname -r 2>/dev/null)

  echo "Boot kernel: $BOOT_KERNEL"
  echo "Arch kernel: $ROOT_KERNEL_VER"

  if [[ -z "$BOOT_KERNEL" || -z "$ROOT_KERNEL_VER" ]]; then
    echo "Unable to detect kernel versions. Skipping validation..."
    return 0
  elif [[ "$BOOT_KERNEL" == *"$ROOT_KERNEL_VER"* ]]; then
    echo "Kernels appear compatible."
    return 0
  else
    echo "Kernel mismatch detected!"
    return 1
  fi
}

# Compare kernel versions before copying
if ! validate_kernel_match "$MOUNTPOINT/boot" "$MOUNTPOINT/root"; then
  echo "Deployment halted: kernel mismatch"
  exit 1
fi


# === 7. Final Cleanup ===
# umount -R $MOUNTPOINT
echo "Arch Linux installed to NVME! Reboot your Pi to enter your new dev/data sci setup!"


# === 7.1 Reboot function ===
# prompt_reboot() {
#     echo -e "\nInstallation successful. Reboot now? (Y/n)"
#     read -r reboot
#     if [[ $reboot == "Y" || $reboot == "y" ]]; then
#         reboot
#     fi
# }

# Call function
# prompt_reboot
