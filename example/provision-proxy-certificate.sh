#!/bin/bash
set -eux

ip=$1
domain=$(hostname --fqdn)
dn=$(hostname)

mkdir -p /vagrant/shared
pushd /vagrant/shared

# create a self-signed certificate.
if [ ! -f $domain-crt.pem ]; then
    openssl genrsa \
        -out $domain-key.pem \
        2048 \
        2>/dev/null
    chmod 400 $domain-key.pem
    openssl req -new \
        -sha256 \
        -subj "/CN=$domain" \
        -key $domain-key.pem \
        -out $domain-csr.pem
    openssl x509 -req -sha256 \
        -signkey $domain-key.pem \
        -extensions a \
        -extfile <(echo "[a]
            subjectAltName=DNS:$domain,IP:$ip
            extendedKeyUsage=critical,serverAuth
            ") \
        -days 365 \
        -in  $domain-csr.pem \
        -out $domain-crt.pem
    openssl x509 \
        -in $domain-crt.pem \
        -outform der \
        -out $domain-crt.der
    # dump the certificate contents (for logging purposes).
    #openssl x509 -noout -text -in $domain-crt.pem
fi

## trust the certificate.
#install $domain-crt.pem /usr/local/share/ca-certificates/$domain.crt
#update-ca-certificates

# configure proxmox-backup-proxy to use the certificate.
# see https://pbs.proxmox.com/docs/sysadmin.html#manually-change-certificate-over-the-command-line
# see https://pbs.proxmox.com/docs/api-viewer/index.html#/ping
install $domain-key.pem /etc/proxmox-backup/proxy.key
install $domain-crt.pem /etc/proxmox-backup/proxy.pem
systemctl restart proxmox-backup-proxy
# dump the TLS connection details and certificate validation result.
(printf 'GET /api2/json/ping HTTP/1.0\r\n\r\n'; sleep .1) | openssl s_client -CAfile $domain-crt.pem -connect $domain:8007 -servername $domain
