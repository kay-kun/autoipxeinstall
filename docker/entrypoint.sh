#!/bin/bash
set -e

# Ensure PXE directory structure exists
mkdir -p /pxeboot/{config,firmware,os-images}

echo "[INFO] Starting PXE Server Setup..."

SERVER_IP="${SERVER_IP:-10.0.0.1}"
NFS_IP="${NFS_IP:-10.0.0.1}"
SMB_IP="${SMB_IP:-10.0.0.1}"

echo "[INFO] Using SERVER_IP=$SERVER_IP"

service nginx start
service tftpd-hpa restart

if [ ! -f "/pxeboot/firmware/ipxe.pxe" ]; then
  echo "[INFO] Compiling iPXE..."
  cd /tmp
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

  make bin/ipxe.pxe bin/undionly.kpxe bin-x86_64-efi/ipxe.efi bin-x86_64-efi/snponly.efi EMBED=bootconfig.ipxe
  cp bin/* /pxeboot/firmware/
  wget -O /pxeboot/firmware/wimboot https://ipxe.org/wimboot
fi

if [ ! -f "/pxeboot/config/boot_legacy.ipxe" ]; then
cat <<EOF > /pxeboot/config/boot_legacy.ipxe
#!ipxe
set server_ip $SERVER_IP
menu PXE Boot Menu (BIOS)
item local_disk Boot from Local HDD/SSD
item reboot Reboot System
choose --default local_disk --timeout 5000 selected && goto \${selected}
:local_disk
sanboot --no-describe --drive 0x80
exit
:reboot
reboot
EOF
fi

if [ ! -f "/pxeboot/config/boot_uefi.ipxe" ]; then
cat <<EOF > /pxeboot/config/boot_uefi.ipxe
#!ipxe
set server_ip $SERVER_IP
menu PXE Boot Menu (UEFI)
item local_disk Boot from Local HDD/SSD
item reboot Reboot System
choose --default local_disk --timeout 5000 selected && goto \${selected}
:local_disk
sanboot --no-describe --drive 0x80
exit
:reboot
reboot
EOF
fi

echo "[INFO] PXE container ready and running."
tail -f /dev/null
