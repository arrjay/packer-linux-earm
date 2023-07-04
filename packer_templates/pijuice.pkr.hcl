// external variables
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

locals {
  image_size = 4294967296
}

source "arm-image" "pi" {
  image_type        = "raspberrypi"
  iso_checksum      = var.dynamic_checksum
  iso_url           = "./images/lite/pi.img.xz"
  output_filename   = "images/pijuice/pi.img"
  target_image_size = local.image_size
  image_arch        = "arm64"
}

source "arm-image" "rock64" {
  image_mounts      = ["/boot", "/IMD", "/"]
  iso_checksum      = var.dynamic_checksum
  iso_url           = "./images/lite/rock64.img.xz"
  output_filename   = "images/pijuice/rock64.img"
  qemu_binary       = "qemu-aarch64-static"
  target_image_size = local.image_size
  image_arch        = "arm64"
}

source "arm-image" "sheeva" {
  image_mounts      = ["/boot", "/IMD", "/"]
  iso_checksum      = var.dynamic_checksum
  iso_url           = "./images/lite/sheeva.img.xz"
  output_filename   = "images/pijuice/sheeva.img"
  target_image_size = local.image_size
  image_arch        = var.arm_machtype
}

source "arm-image" "espressobin" {
  image_mounts      = ["/boot", "/IMD", "/"]
  iso_checksum      = var.dynamic_checksum
  iso_url           = "./images/lite/espressobin.img.xz"
  output_filename   = "images/pijuice/espressobin.img"
  target_image_size = local.image_size
  image_arch        = "arm64"
}

build {
  sources = ["source.arm-image.pi", "source.arm-image.sheeva", "source.arm-image.rock64", "source.arm-image.espressobin"]

  provisioner "file" {
    destination = "/tmp/rules.patch"
    source      = "files/pijuice/rules.patch"
  }

  provisioner "shell" {
    environment_vars = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "TZ=UCT"]
    execute_command  = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    scripts          = ["./scripts/pijuice/0_init.sh"]
  }

  provisioner "file" {
    direction   = "download"
    destination = "files/pijuice/cache/nut_debs.tar"
    source      = "/usr/src/nut_debs.tar"
  }

}
