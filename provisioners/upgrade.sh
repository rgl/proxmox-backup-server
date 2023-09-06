#!/bin/bash
set -euxo pipefail

# configure apt for non-interactive mode.
export DEBIAN_FRONTEND=noninteractive

# switch to the non-enterprise repository.
# see https://pbs.proxmox.com/docs/installation.html#proxmox-backup-no-subscription-repository
dpkg-divert --divert /etc/apt/sources.list.d/pbs-enterprise.list.distrib.disabled --rename --add /etc/apt/sources.list.d/pbs-enterprise.list
echo "deb http://download.proxmox.com/debian/pbs $(. /etc/os-release && echo "$VERSION_CODENAME") pbs-no-subscription" >/etc/apt/sources.list.d/pbs.list

# switch the apt mirror from us to nl.
sed -i -E 's,ftp\.us\.debian,ftp.nl.debian,' /etc/apt/sources.list

# upgrade.
apt-get update
apt-get dist-upgrade -y
