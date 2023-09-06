SHELL=bash
.SHELLFLAGS=-euo pipefail -c

VAR_FILE :=
VAR_FILE_OPTION := $(addprefix -var-file=,$(VAR_FILE))

help:
	@echo type of one:
	@echo 	make build-libvirt
	@echo 	make build-proxmox

build-libvirt: proxmox-backup-server-amd64-libvirt.box
build-proxmox: proxmox-backup-server-amd64-proxmox.box

proxmox-backup-server-amd64-libvirt.box: provisioners/*.sh proxmox-backup-server.pkr.hcl Vagrantfile.template $(VAR_FILE)
	rm -f $@
	CHECKPOINT_DISABLE=1 \
	PACKER_LOG=1 \
	PACKER_LOG_PATH=$@.init.log \
		packer init proxmox-backup-server.pkr.hcl
	PACKER_OUTPUT_BASE_DIR=$${PACKER_OUTPUT_BASE_DIR:-.} \
	PACKER_KEY_INTERVAL=10ms \
	CHECKPOINT_DISABLE=1 \
	PACKER_LOG=1 \
	PACKER_LOG_PATH=$@.log \
	PKR_VAR_vagrant_box=$@ \
		packer build -only=qemu.proxmox-backup-server-amd64 -on-error=abort -timestamp-ui $(VAR_FILE_OPTION) proxmox-backup-server.pkr.hcl
	@./box-metadata.sh libvirt proxmox-backup-server-amd64 $@

proxmox-backup-server-amd64-proxmox.box: provisioners/*.sh proxmox-backup-server.pkr.hcl Vagrantfile.template $(VAR_FILE)
	rm -f $@
	PACKER_OUTPUT_BASE_DIR=$${PACKER_OUTPUT_BASE_DIR:-.} \
	PACKER_KEY_INTERVAL=10ms \
	CHECKPOINT_DISABLE=1 \
	PACKER_LOG=1 \
	PACKER_LOG_PATH=$@.log \
	PKR_VAR_vagrant_box=$@ \
		packer build -only=proxmox-iso.proxmox-backup-server-amd64 -on-error=abort -timestamp-ui $(VAR_FILE_OPTION) proxmox-backup-server.pkr.hcl

clean:
	rm -rf packer_cache $${PACKER_OUTPUT_BASE_DIR:-.}/output-proxmox-backup-server*

.PHONY: help build-libvirt build-proxmox clean
