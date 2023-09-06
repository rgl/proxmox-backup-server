#!/bin/bash
set -eux

ip=$1
fqdn=$(hostname --fqdn)

# configure apt for non-interactive mode.
export DEBIAN_FRONTEND=noninteractive

# make sure the local apt cache is up to date.
while true; do
    apt-get update && break || sleep 5
done

# extend the main partition to the end of the disk and extend the
# pbs/root logical volume to use all the free space.
apt-get install -y cloud-guest-utils
lvdisplay
if growpart /dev/[vs]da 3; then
    pvresize /dev/[vs]da3
    lvextend --extents +100%FREE /dev/pbs/root
    resize2fs /dev/pbs/root
fi

# configure the network for NATting.
cat >/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
    address $ip
    netmask 255.255.255.0
EOF
sed -i -E "s,^[^ ]+( .*pbs.*)\$,$ip\1," /etc/hosts
sed 's,\\,\\\\,g' >/etc/issue <<'EOF'

  _ __  _ __ _____  ___ __ ___   _____  __
 | '_ \| '__/ _ \ \/ / '_ ` _ \ / _ \ \/ /
 | |_) | | | (_) >  <| | | | | | (_) >  <
 | .__/|_|  \___/_/\_\_| |_| |_|\___/_/\_\
 | |   | |              | |
 |_|   | |__   __ _  ___| | ___   _ _ __
       | '_ \ / _` |/ __| |/ / | | | '_ \
       | |_) | (_| | (__|   <| |_| | |_) |
       |_.__/ \__,_|\___|_|\_\\__,_| .__/
                                   | |
            ___  ___ _ ____   _____|_|__
           / __|/ _ \ '__\ \ / / _ \ '__|
           \__ \  __/ |   \ V /  __/ |
           |___/\___|_|    \_/ \___|_|

EOF
cat >>/etc/issue <<EOF
    https://$ip:8007/
    https://$fqdn:8007/

EOF
ifup eth1
killall agetty | true # force them to re-display the issue file.

# disable the "You do not have a valid subscription for this server. Please visit www.proxmox.com to get a list of available options."
# message that appears each time you logon the web-ui.
# NB this file is restored when you (re)install the pbs-manager package.
echo 'Proxmox.Utils.checked_command = function(o) { o(); };' >>/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# install vim.
apt-get install -y --no-install-recommends vim
cat >/etc/vim/vimrc.local <<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
EOF

# configure the shell.
cat >/etc/profile.d/login.sh <<'EOF'
[[ "$-" != *i* ]] && return
export EDITOR=vim
export PAGER=less
alias l='ls -lF --color'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
EOF

cat >/etc/inputrc <<'EOF'
set input-meta on
set output-meta on
set show-all-if-ambiguous on
set completion-ignore-case on
"\e[A": history-search-backward
"\e[B": history-search-forward
"\eOD": backward-word
"\eOC": forward-word
EOF

# configure the motd.
# NB this was generated at http://patorjk.com/software/taag/#p=display&f=Big&t=proxmox%0A%20%20%20%20%20%20backup%0A%20%20%20%20%20%20%20%20%20%20server.
#    it could also be generated with figlet.org.
cat >/etc/motd <<'EOF'

  _ __  _ __ _____  ___ __ ___   _____  __
 | '_ \| '__/ _ \ \/ / '_ ` _ \ / _ \ \/ /
 | |_) | | | (_) >  <| | | | | | (_) >  <
 | .__/|_|  \___/_/\_\_| |_| |_|\___/_/\_\
 | |   | |              | |
 |_|   | |__   __ _  ___| | ___   _ _ __
       | '_ \ / _` |/ __| |/ / | | | '_ \
       | |_) | (_| | (__|   <| |_| | |_) |
       |_.__/ \__,_|\___|_|\_\\__,_| .__/
                                   | |
            ___  ___ _ ____   _____|_|__
           / __|/ _ \ '__\ \ / / _ \ '__|
           \__ \  __/ |   \ V /  __/ |
           |___/\___|_|    \_/ \___|_|

EOF

# provision datastore.
datastore_name='store1'
datastore_pve_namespace='pve'
proxmox-backup-manager datastore create $datastore_name /backup/$datastore_name

# create the datastore pve namespace.
# see https://pbs.proxmox.com/docs/api-viewer/index.html#/admin/datastore/{store}/namespace
# NB use curl --trace-ascii - to dump the whole request/response to stdout.
# NB for some reason, there is no proxmox-backup-manager namespace command to
#    manage the namespaces.
apt-get install -y jq
export CURL_CA_BUNDLE=/etc/proxmox-backup/proxy.pem
api_auth_json="$(curl -sS https://$fqdn:8007/api2/json/access/ticket --data-urlencode 'username=root@pam' --data-urlencode 'password=vagrant')"
api_auth_cookie="PBSAuthCookie=$(jq -r .data.ticket <<<"$api_auth_json")"
api_auth_header="CSRFPreventionToken: $(jq -r .data.CSRFPreventionToken <<<"$api_auth_json")"
curl \
    --silent \
    --show-error \
    --cookie "$api_auth_cookie" \
    --header "$api_auth_header" \
    --request POST \
    --data-urlencode "name=$datastore_pve_namespace" \
    "https://$fqdn:8007/api2/json/admin/datastore/$datastore_name/namespace" \
    | jq

# show stores.
proxmox-backup-manager datastore list

# show versions.
uname -a
lvm version
cat /etc/os-release
cat /etc/debian_version
cat /etc/machine-id
lsblk -x KNAME -o KNAME,SIZE,TRAN,SUBSYSTEMS,FSTYPE,UUID,LABEL,MODEL,SERIAL
proxmox-backup-manager versions
proxmox-backup-client version

# show the proxmox server backup web address.
cat <<EOF
access the proxmox server backup web interface at:
    https://$ip:8007/
    https://$fqdn:8007/
EOF
