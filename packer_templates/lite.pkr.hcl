// external variables
variable "rootfs_uuid" {
  type      = string
  sensitive = false
}
variable "bootfs_id" {
  type      = string
  sensitive = false
}
variable "partition_id" {
  type      = string
  sensitive = false
}
variable "dynamic_checksum" {
  type      = string
  sensitive = false
  default   = "none"
}

// the pi image has a direct upstream source, the other images are sourced
// from Makefile targets, hence the "dynamic_checksum" use.
source "arm-image" "pi" {
  image_type      = "raspberrypi"
  iso_checksum    = "sha256:34987327503fac1076e53f3584f95ca5f41a6a790943f1979262d58d62b04175"
  iso_url         = "https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2022-04-07/2022-04-04-raspios-bullseye-armhf-lite.img.xz"
  output_filename = "images/lite/pi.img"
}
source "arm-image" "rock64" {
  image_mounts    = ["/newboot", "/IMD", "/"]
  iso_checksum    = var.dynamic_checksum
  iso_url         = "./images/upstream/rock64.img.xz"
  output_filename = "images/lite/rock64.img"
}
source "arm-image" "sheeva" {
  image_mounts    = ["/boot", "/boot/IMD", "/"]
  iso_checksum    = var.dynamic_checksum
  iso_url         = "./images/upstream/sheeva.img.xz"
  output_filename = "images/lite/sheeva.img"
}

locals {
  envblock = [
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    "TZ=UCT",
    "DEBIAN_FRONTEND=noninteractive",
    "LANG=C",
    "rootfs_uuid=${var.rootfs_uuid}",
    "bootfs_id=${var.bootfs_id}",
    "partition_id=${var.partition_id}",
  ]
  cmdexec = "/bin/chmod +x {{ .Path }} ; {{ .Vars }} {{ .Path }}"
}

build {
  sources = [
    "source.arm-image.pi",
    "source.arm-image.rock64",
    "source.arm-image.sheeva",
  ]

  // pre-prep to make provisioning work for pi, sheeva
  provisioner "shell" {
    only             = ["arm-image.pi"]
    environment_vars = local.envblock
    execute_command  = local.cmdexec
    inline           = ["mv /etc/ld.so.preload /etc/ld.so.preload.dist"]
    skip_clean       = true
  }
  provisioner "shell" {
    only             = ["arm-image.sheeva"]
    environment_vars = local.envblock
    execute_command  = local.cmdexec
    inline           = [
      "chmod 0755 /",
      "chown 0:0 /",
      "/debootstrap/debootstrap --second-stage --merged-usr",
      // set root password to nosoup4u (sheevaplug image default)
      "usermod -p '$6$fFo1kfYxV7aTJbir$LpccRu/YSjF/7Ih2NOBhmlcZumM3lhQsbvUXIdkwyuzTVJdTgf5rlOKRRUwUwyqwFxCHQV1Tsio1El0jWNbea.' root",
    ]
    skip_clean       = true
  }

  // main provisioning
  provisioner "shell" {
    environment_vars = local.envblock
    execute_command  = local.cmdexec
    inline           = ["mkdir -p /tmp/packer-files"]
    skip_clean       = true
  }
  provisioner "file" {
    destination = "/tmp/packer-files"
    source      = "files/lite/"
  }
  provisioner "shell" {
    environment_vars = local.envblock
    execute_command  = local.cmdexec
    scripts          = [
      "./scripts/lite/0_init.sh",
      "./scripts/lite/network-setup.sh",
    ]
  }

  // call the manifest post-processor so that we can...
  post-processor "manifest" {}

  // modify the pi image partitions here.
  post-processor "shell-local" {
    only             = ["arm-image.pi"]
    environment_vars = local.envblock
    scripts          = ["./scripts/lite/HOST_mangle_partitions.sh"]
  }
}
