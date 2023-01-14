// external variables
variable "dynamic_checksum" {
  type      = string
  sensitive = false
  default   = "none"
}

locals {
  image_size = 4294967296
}

source "arm-image" "pi" {
  image_type        = "raspberrypi"
  iso_checksum      = var.dynamic_checksum
  iso_url           = "./images/lite/pi.img.xz"
  output_filename   = "images/avahi-build/pi.img"
  target_image_size = local.image_size
}

source "arm-image" "rock64" {
  image_mounts      = ["/boot", "/boot/IMD", "/"]
  iso_checksum      = var.dynamic_checksum
  iso_url           = "./images/lite/rock64.img.xz"
  output_filename   = "images/avahi-build/rock64.img"
  qemu_binary       = "qemu-aarch64-static"
  target_image_size = local.image_size
}

source "arm-image" "sheeva" {
  image_mounts      = ["/boot", "/boot/IMD", "/"]
  iso_checksum      = var.dynamic_checksum
  iso_url           = "./images/lite/sheeva.img.xz"
  output_filename   = "images/avahi-build/sheeva.img"
  target_image_size = local.image_size
}

build {
  sources = ["source.arm-image.pi", "source.arm-image.sheeva", "source.arm-image.rock64"]

  provisioner "file" {
    destination = "/tmp/packer-files"
    source      = "files/avahi-build/"
  }

  provisioner "shell" {
    environment_vars = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "TZ=UCT"]
    execute_command  = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    scripts          = ["./scripts/avahi-build/0_init.sh"]
  }

  provisioner "file" {
    direction   = "download"
    destination = "files/avahi-build/cache/avahi_debs.tar"
    source      = "/usr/src/avahi_debs.tar"
  }

}
