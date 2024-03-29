// external variables
variable "pi_rootfs_uuid" {
  type      = string
  sensitive = false
}
variable "pi_bootfs_id" {
  type      = string
  sensitive = false
}
variable "pi_disk_id" {
  type      = string
  sensitive = false
}
variable "rock64_bootfs_uuid" {
  type      = string
  sensitive = false
}
variable "rock64_disk_id" {
  type      = string
  sensitive = false
}
variable "rock64_imdfs_id" {
  type      = string
  sensitive = false
}
variable "espressobin_bootfs_uuid" {
  type      = string
  sensitive = false
}
variable "espressobin_disk_id" {
  type      = string
  sensitive = false
}
variable "espressobin_imdfs_id" {
  type      = string
  sensitive = false
}
variable "sheeva_disk_id" {
  type      = string
  sensitive = false
}
variable "dynamic_checksum" {
  type      = string
  sensitive = false
  default   = "none"
}
variable "arm_machtype" {
  type      = string
  sensitive = false
  default   = "arm"
}

// the pi image has a direct upstream source, the other images are sourced
// from Makefile targets, hence the "dynamic_checksum" use.
source "arm-image" "pi" {
  image_type      = "raspberrypi"
  iso_checksum    = "sha256:9bf5234efbadd2d39769486e0a20923d8526a45eba57f74cda45ef78e2b628da"
  iso_url         = "https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2022-09-26/2022-09-22-raspios-bullseye-armhf-lite.img.xz"
  output_filename = "images/lite/pi.img"
  image_arch      = "arm64"
}
source "arm-image" "rock64" {
  image_mounts    = ["/newboot", "/IMD", "/"]
  iso_checksum    = var.dynamic_checksum
  iso_url         = "./images/upstream/rock64.img.xz"
  output_filename = "images/lite/rock64.img"
  image_arch      = "arm64"
  target_image_size = 2147483648
}
source "arm-image" "sheeva" {
  image_mounts    = ["/boot", "/IMD", "/"]
  iso_checksum    = var.dynamic_checksum
  iso_url         = "./images/upstream/sheeva.img.xz"
  output_filename = "images/lite/sheeva.img"
  image_arch      = var.arm_machtype
}
source "arm-image" "espressobin" {
  image_mounts    = ["/newboot", "/IMD", "/"]
  iso_checksum    = var.dynamic_checksum
  iso_url         = "./images/upstream/espressobin.img.xz"
  output_filename = "images/lite/espressobin.img"
  image_arch      = "arm64"
}

locals {
  envblock = [
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    "TZ=UCT",
    "DEBIAN_FRONTEND=noninteractive",
    "LANG=C",
    "pi_rootfs_uuid=${var.pi_rootfs_uuid}",
    "pi_bootfs_id=${var.pi_bootfs_id}",
    "pi_disk_id=${var.pi_disk_id}",
    "rock64_bootfs_uuid=${var.rock64_bootfs_uuid}",
    "rock64_disk_id=${var.rock64_disk_id}",
    "rock64_imdfs_id=${var.rock64_imdfs_id}",
    "sheeva_disk_id=${var.sheeva_disk_id}",
    "espressobin_bootfs_uuid=${var.espressobin_bootfs_uuid}",
    "espressobin_imdfs_id=${var.espressobin_imdfs_id}",
    "espressobin_disk_id=${var.espressobin_disk_id}",
  ]
  cmdexec = "/bin/chmod +x {{ .Path }} ; {{ .Vars }} {{ .Path }}"
}

build {
  sources = [
    "source.arm-image.pi",
    "source.arm-image.rock64",
    "source.arm-image.sheeva",
    "source.arm-image.espressobin",
  ]

  // pre-prep to make provisioning work for pi, sheeva
  provisioner "shell" {
    only             = ["arm-image.pi"]
    environment_vars = local.envblock
    execute_command  = local.cmdexec
    inline           = ["mv /etc/ld.so.preload /etc/ld.so.preload.dist"]
    skip_clean       = true
  }

  // sheeva actually has a step to *install* all the cross-debootstrap packages...
  provisioner "shell" {
    only             = [ "arm-image.sheeva" ]
    environment_vars = local.envblock
    execute_command  = local.cmdexec
    inline           = [
      "chmod 0755 /",
      "chown 0:0 /",
      "/debootstrap/debootstrap --second-stage --merged-usr",
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

  // rock64, espressobin has a special step to shuffle /boot over to the new boot partition.
  provisioner "shell" {
    only = ["arm-image.rock64", "arm-image.espressobin"]
    environment_vars = local.envblock
    execute_command = local.cmdexec
    inline = [
      "rsync -a /boot/ /newboot/",
      "rm -rf /boot/*",
    ]
  }

  // the root password is separate so I can tag images as a shortcut (and set their root pw)
  provisioner "shell" {
    only = [
      "arm-image.sheeva",
    ]
    environment_vars = local.envblock
    execute_command = local.cmdexec
    inline = [
      // set root password to nosoup4u (sheevaplug image default)
      "usermod -p '$6$fFo1kfYxV7aTJbir$LpccRu/YSjF/7Ih2NOBhmlcZumM3lhQsbvUXIdkwyuzTVJdTgf5rlOKRRUwUwyqwFxCHQV1Tsio1El0jWNbea.' root",
    ]
  }

  // call the manifest post-processor so that we can...
  post-processor "manifest" {}

  // modify image partitions, ids here.
  post-processor "shell-local" {
    only             = [
      "arm-image.pi",
      "arm-image.rock64",
      "arm-image.sheeva",
      "arm-image.espressobin",
    ]
    environment_vars = local.envblock
    scripts          = ["./scripts/lite/HOST_mangle_partitions.sh"]
  }
}
