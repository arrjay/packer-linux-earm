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

source "arm-image" "pi" {
  image_type        = "raspberrypi"
  iso_checksum      = var.dynamic_checksum
  iso_url           = "./images/standard/pi.img.xz"
  output_filename   = "./images/xfce/pi.img"
  target_image_size = 6442450944
  image_arch        = var.arm_machtype
}

source "arm-image" "rock64" {
  image_mounts      = ["/boot", "/IMD", "/"]
  iso_checksum      = var.dynamic_checksum
  iso_url           = "./images/standard/rock64.img.xz"
  output_filename   = "images/xfce/rock64.img"
  target_image_size = 6442450944
  image_arch        = "arm64"
}

build {
  sources = ["source.arm-image.pi", "source.arm-image.rock64"]

  provisioner "shell" {
    environment_vars = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"]
    execute_command  = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    inline           = ["mkdir -p /tmp/packer-files"]
  }

  provisioner "file" {
    destination = "/tmp/packer-files"
    source      = "files/xfce/"
  }

  provisioner "shell" {
    environment_vars = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "TZ=UCT"]
    execute_command  = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    scripts          = ["./scripts/xfce/0_init.sh"]
  }

}
