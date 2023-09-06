packer {
  required_plugins {
    # see https://github.com/hashicorp/packer-plugin-qemu
    qemu = {
      version = "1.0.9"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "vagrant_box" {
  type = string
}

variable "cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2 * 1024
}

variable "disk_size" {
  type    = number
  default = 20 * 1024
}

variable "iso_url" {
  type    = string
  default = "http://download.proxmox.com/iso/proxmox-backup-server_3.0-1.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:8974070f90225bbeba78721c685905e8f42f5463b3592f181689f76d1a579154"
}

variable "apt_cache_host" {
  type    = string
  default = env("APT_CACHE_HOST")
}

variable "apt_cache_port" {
  type    = string
  default = env("APT_CACHE_PORT")
}

variable "output_base_dir" {
  type    = string
  default = env("PACKER_OUTPUT_BASE_DIR")
}

variable "step_country" {
  type    = string
  default = "United S<wait>t<wait>a<wait>t<wait>e<wait>s<wait><enter><wait>"
}

variable "step_email" {
  type    = string
  default = "pbs@example.com"
}

variable "step_hostname" {
  type    = string
  default = "pbs.example.com"
}

variable "step_keyboard_layout" {
  type    = string
  default = ""
}

variable "step_timezone" {
  type    = string
  default = ""
}

variable "shell_provisioner_scripts" {
  type = list(string)
  default = [
    "provisioners/apt_proxy.sh",
    "provisioners/upgrade.sh",
    "provisioners/network.sh",
    "provisioners/localisation-pt.sh",
    "provisioners/reboot.sh",
    "provisioners/provision.sh",
  ]
}

source "qemu" "proxmox-backup-server-amd64" {
  accelerator  = "kvm"
  machine_type = "q35"
  efi_boot     = true
  cpus         = var.cpus
  memory       = var.memory
  qemuargs = [
    ["-cpu", "host"],
  ]
  headless            = true
  use_default_display = false
  net_device          = "virtio-net"
  http_directory      = "."
  format              = "qcow2"
  disk_size           = var.disk_size
  disk_interface      = "virtio-scsi"
  disk_cache          = "unsafe"
  disk_discard        = "unmap"
  iso_url             = var.iso_url
  iso_checksum        = var.iso_checksum
  ssh_username        = "root"
  ssh_password        = "vagrant"
  ssh_timeout         = "60m"
  boot_wait           = "10s"
  boot_command = [
    "<enter>",
    "<wait3m>",
    "<enter><wait>",
    "<enter><wait>",
    "${var.step_country}<tab><wait>",
    "${var.step_timezone}<tab><wait>",
    "${var.step_keyboard_layout}<tab><wait>",
    "<tab><wait>",
    "<enter><wait5>",
    "vagrant<tab><wait>",
    "vagrant<tab><wait>",
    "${var.step_email}<tab><wait>",
    "<tab><wait>",
    "<enter><wait5>",
    "${var.step_hostname}<tab><wait>",
    "<tab><wait>",
    "<tab><wait>",
    "<tab><wait>",
    "<tab><wait>",
    "<tab><wait>",
    "<enter><wait5>",
    "<enter><wait5>",
  ]
  shutdown_command = "poweroff"
}

build {
  sources = [
    "source.qemu.proxmox-backup-server-amd64",
  ]

  provisioner "shell" {
    expect_disconnect = true
    environment_vars = [
      "apt_cache_host=${var.apt_cache_host}",
      "apt_cache_port=${var.apt_cache_port}",
    ]
    scripts = var.shell_provisioner_scripts
  }

  post-processor "vagrant" {
    output               = var.vagrant_box
    vagrantfile_template = "Vagrantfile.template"
  }
}
