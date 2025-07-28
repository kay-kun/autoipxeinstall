# 🧰 PXE Server Setup Script for Ubuntu 24.04

This project provides an **interactive** and **automatable** shell script to install and configure a **PXE Boot Server** on **Ubuntu 24.04**.  
It supports **UEFI** and **Legacy BIOS** booting via **TFTP** and **HTTP**, with optional local **NFS** and **SMB** servers.

---

## ✅ Features

- Boot support for:
  - **x86_64 UEFI**
  - **Legacy BIOS**
- **HTTP boot** via NGINX (on port `65100`)
- **TFTP server** for iPXE binaries
- **WIMBOOT** support for Windows PE / installation media
- Optional:
  - Local **NFS** server exporting `/pxeboot`
  - Local **SMB** server sharing `/pxeboot` (`ipxe` / `ipxe`)
- Fully **interactive prompts** or **non-interactive CLI parameters**
- Clean and user-friendly output

---

## 🚀 Quick Start

```
sudo bash pxe-setup.sh --local --serverip=xxx.xxx.xxx.xxx
```

This will:

- Install all required PXE components  
- Serve boot files via TFTP and HTTP  
- Enable local NFS and SMB services  
- Share `/pxeboot` via NFS and SMB  
- Compile iPXE and generate boot menus  

---

## 🛠️ Usage

### 🔧 CLI Options

| Option         | Description                                 |
|----------------|---------------------------------------------|
| `--local`      | Enable local NFS and SMB server setup       |
| `--serverip=…` | PXE server IP for TFTP & HTTP               |
| `--nfsip=…`    | NFS server IP (required if `--local` unused)|
| `--smbip=…`    | SMB server IP (required if `--local` unused)|

### 🧪 Example (External NFS/SMB)

```
sudo bash pxe-setup.sh --serverip=xxx.xxx.xxx.xxx --nfsip=xxx.xxx.xxx.xxx --smbip=xxx.xxx.xxx.xxx
```

---

## 📁 Directory Structure

| Path                    | Description                        |
|-------------------------|------------------------------------|
| `/pxeboot/config/`      | iPXE menu definitions              |
| `/pxeboot/firmware/`    | iPXE binaries, wimboot, etc.       |
| `/pxeboot/os-images/`   | Storage for ISOs, installers, etc. |

---

## 🔐 SMB Share Access

If **local SMB** is enabled, a user is created:

- **Username:** `ipxe`  
- **Password:** `ipxe`  
- **Share:** `\\<server_ip>\pxeboot`  

---

## 📜 Dependencies

The script automatically installs:

- `nginx`, `tftpd-hpa`, `build-essential`, `git`,  
  `uuid-dev`, `liblzma-dev`, `wget`, `isolinux`

If `--local` is used:

- `nfs-kernel-server`, `samba`

---

## 📦 To Do / Ideas

- [ ] ARM64 iPXE build support  
- [ ] Dockerized PXE server variant  

---

## 📄 License

**MIT** – Feel free to fork, use, and contribute!
