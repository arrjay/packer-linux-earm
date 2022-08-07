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

source "arm-image" "pi" {
  image_type      = "raspberrypi"
  iso_checksum    = "sha256:34987327503fac1076e53f3584f95ca5f41a6a790943f1979262d58d62b04175"
  iso_url         = "https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2022-04-07/2022-04-04-raspios-bullseye-armhf-lite.img.xz"
  output_filename = "images/lite/pi.img"
}

source "arm-image" "rock64" {
  image_mounts    = ["/newboot", "/newboot/IMD", "/"]
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

build {
  sources = ["source.arm-image.pi", "source.arm-image.rock64", "source.arm-image.sheeva"]

  provisioner "shell" {
    environment_vars = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"]
    execute_command  = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    inline           = ["mv /etc/ld.so.preload /etc/ld.so.preload.dist"]
    only             = ["arm-image.pi"]
    skip_clean       = true
  }

  provisioner "shell" {
    environment_vars = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "TZ=UCT", "DEBIAN_FRONTEND=noninteractive", "LANG=C"]
    execute_command  = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    inline           = ["chmod 0755 /", "chown 0:0 /", "/debootstrap/debootstrap --second-stage --merged-usr", "# set root password to nosoup4u (sheevaplug image default)", "usermod -p '$6$fFo1kfYxV7aTJbir$LpccRu/YSjF/7Ih2NOBhmlcZumM3lhQsbvUXIdkwyuzTVJdTgf5rlOKRRUwUwyqwFxCHQV1Tsio1El0jWNbea.' root"]
    only             = ["arm-image.sheeva"]
    skip_clean       = true
  }

  provisioner "shell" {
    environment_vars = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"]
    execute_command  = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    inline           = ["mkdir -p /tmp/packer-files"]
    skip_clean       = true
  }

  provisioner "file" {
    destination = "/tmp/packer-files"
    source      = "files/lite/"
  }

  provisioner "shell" {
    environment_vars = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "rootfs_uuid=${var.rootfs_uuid}", "bootfs_id=${var.bootfs_id}", "partition_id=${var.partition_id}"]
    execute_command  = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    scripts          = ["./scripts/lite/0_init.sh", "./scripts/lite/network-setup.sh"]
  }

  post-processor "manifest" {}

  post-processor "shell-local" {
    environment_vars = ["rootfs_uuid=${var.rootfs_uuid}", "bootfs_id=${var.bootfs_id}", "partition_id=${var.partition_id}"]
    only             = ["arm-image.pi"]
    scripts          = ["./scripts/lite/HOST_mangle_partitions.sh"]
  }
}
