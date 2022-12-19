// external variables
variable "dynamic_checksum" {
  type      = string
  sensitive = false
  default   = "none"
}

source "arm-image" "pi" {
  image_type        = "raspberrypi"
  iso_checksum      = var.dynamic_checksum
  iso_url           = "./images/netdata/pi.img.xz"
  output_filename   = "images/pijuice/pi.img"
}

build {
  sources = ["source.arm-image.pi"]

  provisioner "shell" {
    environment_vars = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "TZ=UCT"]
    execute_command  = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    scripts          = ["./scripts/pijuice/0_init.sh"]
  }

}
