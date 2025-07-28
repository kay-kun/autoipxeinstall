#!/bin/bash
set -e

# -------------------------------
# Colors for output
# -------------------------------
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

# -------------------------------
# Root check
# -------------------------------
if [[ "$EUID" -ne 0 ]]; then
  echo -e "${RED}This script must be run as root. Use sudo.${NC}"
  exit 1
fi

# -------------------------------
# Ubuntu version check
# -------------------------------
UBUNTU_VERSION=$(lsb_release -rs)
if [[ "$UBUNTU_VERSION" != "24.04" ]]; then
  echo -e "${RED}This script is intended for Ubuntu 24.04 only.${NC}"
  exit 1
fi

# -------------------------------
# Default values and CLI args
# -------------------------------
LOCAL_SERVICES=false

for arg in "$@"; do
  case $arg in
    --serverip=*)
      SERVER_IP="${arg#*=}"
      shift
      ;;
    --nfsip=*)
      NFS_IP="${arg#*=}"
      shift
      ;;
    --smbip=*)
      SMB_IP="${arg#*=}"
      shift
      ;;
    --local)
      LOCAL_SERVICES=true
      shift
      ;;
    *)
      echo -e "${YELLOW}Unknown parameter: $arg${NC}"
      ;;
  esac
done

# -------------------------------
# IP collection
# -------------------------------
if $LOCAL_SERVICES; then
  [[ -z "$SERVER_IP" ]] && read -rp "Enter server IP (for PXE/TFTP/NFS/SMB): " SERVER_IP
  NFS_IP="$SERVER_IP"
  SMB_IP="$SERVER_IP"
else
  [[ -z "$SERVER_IP" ]] && read -rp "Enter PXE server IP (for HTTP/TFTP): " SERVER_IP
  [[ -z "$NFS_IP" ]] && read -rp "Enter NFS server IP: " NFS_IP
  [[ -z "$SMB_IP" ]] && read -rp "Enter SMB server IP: " SMB_IP
fi

echo -e "${GREEN}Using the following configuration:${NC}"
echo "  PXE server IP : $SERVER_IP"
echo "  NFS server IP : $NFS_IP"
echo "  SMB server IP : $SMB_IP"

# -------------------------------
# Package installation
# -------------------------------
echo -e "${YELLOW}Installing required packages...${NC}"
apt update -qq
apt install -y -qq nginx nano build-essential liblzma-dev git isolinux tftpd-hpa wget uuid-dev

# Install NFS and Samba if selected
if $LOCAL_SERVICES; then
  echo -e "${YELLOW}Installing local NFS and Samba servers...${NC}"
  apt install -y -qq nfs-kernel-server samba
fi

# -------------------------------
# Directory setup
# -------------------------------
echo -e "${YELLOW}Preparing directory structure...${NC}"
mkdir -p /pxeboot/{config,firmware,os-images}

# -------------------------------
# NGINX configuration
# -------------------------------
echo -e "${YELLOW}Configuring nginx...${NC}"
cat <<EOF > /etc/nginx/sites-available/ipxe
server {
    listen 65100 default_server;
    listen [::]:65100 default_server;

    server_name _;

    root /pxeboot;
    index index.html;

    location / {
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/ipxe /etc/nginx/sites-enabled/ipxe
systemctl restart nginx

# -------------------------------
# iPXE clone & build
# -------------------------------
echo -e "${YELLOW}Downloading and compiling iPXE...${NC}"
cd /tmp
rm -rf ipxe
git clone https://github.com/ipxe/ipxe.git
cd ipxe/src

cat <<EOF > bootconfig.ipxe
#!ipxe

dhcp

iseq \${platform} efi && goto uefi || goto legacy

:legacy
chain http://$SERVER_IP:65100/config/boot_legacy.ipxe
goto end

:uefi
chain http://$SERVER_IP:65100/config/boot_uefi.ipxe

:end
EOF

make -s \
  bin/ipxe.pxe \
  bin/undionly.kpxe \
  bin-x86_64-efi/ipxe.efi \
  bin-x86_64-efi/snponly.efi \
  EMBED=bootconfig.ipxe

cp bin/ipxe.pxe \
   bin/undionly.kpxe \
   bin-x86_64-efi/ipxe.efi \
   bin-x86_64-efi/snponly.efi \
   /pxeboot/firmware/

# -------------------------------
# iPXE menus
# -------------------------------
echo -e "${YELLOW}Creating iPXE boot menus...${NC}"
cat <<EOF > /pxeboot/config/boot_legacy.ipxe
#!ipxe
set server_ip $SERVER_IP
set nfs_ip $NFS_IP
set smb_ip $SMB_IP
set root_path /pxeboot

menu PXE Boot Menu (BIOS)
item local_disk Boot from Local HDD/SSD
item local_usb  Boot from Local USB
item local_cd   Boot from Local CD
item reboot     Reboot System
item shutdown   Shutdown System

choose --default local_disk --timeout 5000 selected && goto \${selected}

:local_disk
sanboot --no-describe --drive 0x80
exit

:local_usb
sanboot --no-describe --drive 0x81
exit

:local_cd
sanboot --no-describe --drive 0x82
exit

:reboot
reboot

:shutdown
poweroff
EOF

cat <<EOF > /pxeboot/config/boot_uefi.ipxe
#!ipxe
set server_ip $SERVER_IP
set nfs_ip $NFS_IP
set smb_ip $SMB_IP
set root_path /pxeboot

menu PXE Boot Menu (UEFI x86_64)
item local_disk Boot from Local HDD/SSD
item local_usb  Boot from Local USB
item local_cd   Boot from Local CD
item reboot     Reboot System
item shutdown   Shutdown System

choose --default local_disk --timeout 5000 selected && goto \${selected}

:local_disk
sanboot --no-describe --drive 0x80
exit

:local_usb
sanboot --no-describe --drive 0x81
exit

:local_cd
sanboot --no-describe --drive 0x82
exit

:reboot
reboot

:shutdown
poweroff
EOF

# -------------------------------
# Wimboot binary
# -------------------------------
echo -e "${YELLOW}Downloading wimboot binary...${NC}"
wget -q -O /pxeboot/firmware/wimboot https://ipxe.org/wimboot

# -------------------------------
# TFTP configuration
# -------------------------------
echo -e "${YELLOW}Configuring TFTP server...${NC}"
cat <<EOF > /etc/default/tftpd-hpa
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/pxeboot/firmware"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="--secure --create"
EOF

chown -R tftp:tftp /pxeboot/firmware
chmod -R 777 /pxeboot/firmware
systemctl daemon-reexec
systemctl restart tftpd-hpa
systemctl enable tftpd-hpa

# -------------------------------
# NFS/Samba setup (if local)
# -------------------------------
if $LOCAL_SERVICES; then
  echo -e "${YELLOW}Setting up local NFS and Samba shares...${NC}"

  # NFS export
  echo "/pxeboot *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
  exportfs -a
  systemctl restart nfs-kernel-server
  systemctl enable nfs-kernel-server

  # Samba config
  cat <<EOF >> /etc/samba/smb.conf

[pxeboot]
   path = /pxeboot
   browseable = yes
   read only = no
   guest ok = yes
   force user = nobody
EOF

  systemctl restart smbd
  systemctl enable smbd

  # Create Samba user
  echo -e "ipxe\nipxe" | smbpasswd -s -a ipxe || true
fi

# -------------------------------
# Done
# -------------------------------
echo -e "${GREEN}✓ PXE server setup completed.${NC}"
echo -e "${GREEN}✓ Boot files ready, TFTP/Nginx running.${NC}"
$LOCAL_SERVICES && echo -e "${GREEN}✓ Local NFS/SMB server is configured.${NC}"