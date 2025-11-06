# pi5_setup

[![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi%205-red?logo=raspberrypi)]()
[![Arch](https://img.shields.io/badge/OS-Arch%20Linux-blue?logo=archlinux)]()
[![Arch Type](https://img.shields.io/badge/arch-aarch64%20(ARM64)-green?logo=linux)]()
[![Kernel](https://img.shields.io/badge/kernel-Linux--rpi--custom-lightgrey?logo=raspberrypi)]()
[![Storage](https://img.shields.io/badge/boot-NVMe%20SSD%20%2B%20SD%20Card-yellow?logo=sandisk)]()
[![Mode](https://img.shields.io/badge/mode-Headless-orange?logo=gnometerminal)]()
[![DevOps](https://img.shields.io/badge/workflow-Data%20Science%20DevOps-brightgreen?logo=jupyter)]()

---

### 🧠 Overview
- Setup scripts to install **Arch Linux ARM** and **custom Linux RPI headers/kernel** from a **headless Raspberry Pi 5** running **Pi OS Lite** booting from SD card 128GB. 
- Install Arch and Linux RPI on an **SD card** with `deploy_arch_sd.sh`  
- Install Arch and Linux RPI with **NVMe SSD boot (PCIe Gen 2)** using `deploy_arch_nvme.sh`  
- Scripts link to a **dotfiles repo** for a uniform **Data Science DevOps** environment  
- After install, **set locale manually** to mitigate chroot locale setup issues  
  - Locale instructions are included in the comment blocks at the top of each install script  

**Tags:**  
`linux-rpi` • `aarch64` • `ARM64` • `pi5` • `nvme boot` • `custom kernel and headers` • `headless setup`

