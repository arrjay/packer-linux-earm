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
  image_size = 3221225472
}

source "arm-image" "pi" {
  image_type        = "raspberrypi"
  iso_checksum      = var.dynamic_checksum
  iso_url           = "./images/lite/pi.img.xz"
  output_filename   = "images/netdata/pi.img"
  target_image_size = local.image_size
  image_arch        = "arm64"
}
source "arm-image" "sheeva" {
  image_mounts      = ["/boot", "/boot/IMD", "/"]
  iso_checksum      = var.dynamic_checksum
  iso_url           = "./images/lite/sheeva.img.xz"
  output_filename   = "images/netdata/sheeva.img"
  target_image_size = local.image_size
  image_arch        = var.arm_machtype
}
source "arm-image" "rock64" {
  image_mounts      = ["/boot", "/boot/IMD", "/"]
  iso_checksum      = var.dynamic_checksum
  iso_url           = "./images/lite/rock64.img.xz"
  output_filename   = "images/netdata/rock64.img"
  target_image_size = local.image_size
  image_arch        = "arm64"
}

build {
  sources = ["source.arm-image.pi", "source.arm-image.sheeva", "source.arm-image.rock64"]

  provisioner "shell" {
    environment_vars = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "TZ=UCT"]
    execute_command  = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    scripts          = ["./scripts/netdata/0_init.sh"]
  }

}
