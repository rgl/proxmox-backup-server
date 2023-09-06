#!/bin/bash
set -eux

ip=$1
fqdn=$(hostname --fqdn)

# configure apt for non-interactive mode.
export DEBIAN_FRONTEND=noninteractive

# show versions.
uname -a
lvm version
cat /etc/os-release
proxmox-backup-manager versions
proxmox-backup-client version

# show block devices.
lsblk -x KNAME -o KNAME,SIZE,TRAN,SUBSYSTEMS,FSTYPE,UUID,LABEL,MODEL,SERIAL

# show disk partitions.
sfdisk -l

# show the free space.
df -h /

# show the certificate fingerprint.
proxmox-backup-manager cert info

# show the proxmox web address.
cat <<EOF
access the proxmox web interface at:
    https://$ip:8007/
    https://$fqdn:8007/
EOF
