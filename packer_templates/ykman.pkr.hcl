// external variables
variable "dynamic_checksum" {
  type      = string
  sensitive = false
  default   = "none"
}

source "arm-image" "pi" {
  image_type        = "raspberrypi"
  iso_checksum      = var.dynamic_checksum
  iso_url           = "./images/xfce/pi.img.xz"
  output_filename   = "./images/ykman/pi.img"
}

build {
  sources = ["source.arm-image.pi"]

  provisioner "shell-local" {
    inline          = ["p=\"$(pwd)\"", "mkdir -p \"$${p}/files/ykman/cache\"", "(cd \"$${p}/vendor/misc-scripts\" && git archive HEAD -o \"$${p}/files/ykman/cache/misc-scripts.tar\")", "(cd \"$${p}/vendor\" && tar cf \"$${p}/files/ykman/cache/keymat.tar\" keymat)"]
  }

  provisioner "shell" {
    environment_vars = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"]
    execute_command  = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    inline           = ["mkdir -p /tmp/packer-files"]
  }

  provisioner "file" {
    destination = "/tmp/packer-files"
    source      = "files/ykman/"
  }

  provisioner "shell" {
    environment_vars = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "TZ=UCT"]
    execute_command  = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    scripts          = ["./scripts/ykman/0_init.sh"]
  }

}
