# pi5_setup
[![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi%205-red?logo=raspberrypi)]()
[![Arch](https://img.shields.io/badge/OS-Arch%20Linux-blue?logo=archlinux)]()
[![Arch Type](https://img.shields.io/badge/arch-aarch64%20(ARM64)-green?logo=linux)]()
[![Kernel](https://img.shields.io/badge/kernel-Linux--rpi-lightgrey?logo=raspberrypi)]()
[![Storage](https://img.shields.io/badge/boot-NVMe%20SSD%20%2B%20SD%20Card-yellow?logo=sandisk)]()
[![Mode](https://img.shields.io/badge/mode-Headless-orange?logo=gnometerminal)]()
[![DevOps](https://img.shields.io/badge/workflow-Data%20Science%20DevOps-brightgreen?logo=jupyter)]()

---

### Hosting & Use Case Summary | Key Highlights
- **Edge-Optimized ML Workflow Architecture** – Performs PCA-based drift detection locally, minimizing cloud dependencies.  
- **Low Power, High Flexibility** – Runs efficiently on Raspberry Pi 5 hardware.  
- **Full DevOps Integration** – Combines Python ML logic, Node.js backend, and React frontend under a single Dockerized architecture.  
- **Portable & Reproducible | Infrastructure as Code** – Fully automated setup via `deploy_arch_nvme.sh` or `deploy_arch_sd.sh` scripts.  
- **Scalable Prototype** – Ideal for IoT and WiFi Mesh data drift monitoring, federated learning nodes, or lightweight data science research clusters.

### Overview
- Setup scripts to install **Arch Linux ARM** and **custom Linux RPI headers/kernel** from a **headless Raspberry Pi 5** running **Pi OS Lite** booting from SD card 128GB. 
- Install Arch and Linux RPI on an **SD card** with `deploy_arch_sd.sh`  
- Install Arch and Linux RPI with **NVMe SSD boot (PCIe Gen 2)** using `deploy_arch_nvme.sh`  
- Scripts link to a **dotfiles repo** for a uniform **Data Science DevOps** environment  
- After install, **set locale manually** to mitigate chroot locale setup issues  
  - Locale instructions are included in the comment blocks at the top of each install script  
**Tags:**  
`linux-rpi` • `aarch64` • `ARM64` • `pi5` • `nvme boot` • `custom kernel and headers` • `headless setup`

**Reference:**
- [kernel info](https://archlinuxarm.org/packages/aarch64/linux-rpi)
- [Guide](https://kiljan.org/2023/11/24/arch-linux-arm-on-a-raspberry-pi-5-model-b/)
---

### First Boot Setup Instructions (NVMe SSD)
Follow these steps to prepare, install, and boot Arch Linux ARM with a custom `linux-rpi` kernel on your Raspberry Pi 5.

---
### STEP 1 – Flash SD Card with Raspberry Pi Imager
1. Format SD cards over 32 GB to **FAT32**.
2. Use the latest **64-bit Raspberry Pi OS Lite** (`.img.xz`) image.
3. In **Raspberry Pi Imager**:
   - Select **Raspberry Pi OS Lite (64-bit)**
   - Choose your SD card as the target device
   - Click **Flash**
   - Set custom password

---

### STEP 2 – Enable SSH (Headless Access)
After flashing completes:
1. Open the **boot** partition of the SD card in your file explorer.
2. Create an empty file named `ssh` (no file extension) in the **root** of the partition.

---

### STEP 3 – Insert SD Card and Boot the Pi
- Insert the SD card into your **Raspberry Pi 5**.  
- Connect an **Ethernet cable** to your router.  
- Power on the Pi.  
- It should automatically connect and allow SSH login via  
  `user@raspberrypi.local`.

---

### STEP 4 – Find the Pi’s IP Address
- Open your router’s **Connected Devices** or **DHCP Clients** page.  
- Locate the **Raspberry Pi 5** entry to see its IP address.  
- Alternatively, from another device:  
  ```bash
  ping raspberrypi.local

### STEP 5 - SSH into the Pi
- From your laptop or PC:
    ```bash
    sudo ssh user@raspberrypi.local

### STEP 6 - Run the Full Setup Script
- Prepare the target NVMe SSD:
- Format using Raspberry Pi Imager.
- Insert NVMe drive via PCIe adapter.
- Verify hardware detection:
    ```bash
    lsblk
- Install required tools
    ```bash
    sudo apt install git vim -y
- Clone the setup repository:
    ```bash
    git clone https://github.com/chrporter22/pi5_setup.git
    cd pi5_setup
- Create a .env file with:
    ```bash
    WIFI_SSID="your_wifi_name"
    WIFI_PASS="your_wifi_password"
    WIFI_COUNTRY="US"
    PI_PASSWORD="your_pi_password"
- Run the NVMe install script:
    ```bash
    sudo bash deploy_arch_nvme.sh

### STEP 7 - Locale & SSH Key Cleanup
- If you see SSH fingerprint warnings:
    ```bash
    rm ~/.ssh/known_hosts
- Once inside Arch Linux ARM on your Pi 5:
    + Test package manager:
        ```bash
        sudo pacman -Su
- Edit locales:
    ```bash
    sudo nvim /etc/locale.gen
- Uncomment:
    ```bash
    en_US.UTF-8 UTF-8
- Generate and apply locale:
    ```bash
    sudo locale-gen
    echo 'LANG=en_US.UTF-8' | sudo tee /etc/locale.conf
**Setting locale fixes Nerd Fonts and Neovim dashboard previews inside tmux.**
### STEP 8 – Enable NVMe Boot (EEPROM)
- If you want your Pi 5 to boot directly from NVMe (BOOT_ORDER=0xf416):
- Boot into Raspberry Pi OS Lite (64-bit) from the SD card.
    ```bash
    sudo rpi-eeprom-config --edit
- Modify:
    ```bash
    BOOT_ORDER=0xf416
    PCIE_PROBE=1

[Guide](https://kiljan.org/2023/11/24/arch-linux-arm-on-a-raspberry-pi-5-model-b/)


