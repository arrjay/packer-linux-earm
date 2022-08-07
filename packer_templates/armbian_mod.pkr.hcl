source "arm-image" "rock64" {
  image_mounts    = ["/"]
  iso_checksum    = "sha256:f5edb2c031774e081ab408e632cece3f48c19c80b96bb619f0da0206230be609"
  iso_url         = "https://armbian.chi.auroradev.org/dl/rock64/archive/Armbian_22.05.4_Rock64_jammy_current_5.15.48.img.xz"
  output_filename = "images/upstream/rock64.img"
}

build {
  sources = ["source.arm-image.rock64"]

  provisioner "shell" {
    environment_vars = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"]
    execute_command  = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    inline           = ["mkdir /newboot", "mkdir /IMD"]
    skip_clean       = true
  }

  post-processor "manifest" {}

  post-processor "shell-local" {
    scripts = ["./scripts/armbian-mod/HOST_create_bootfs.sh"]
  }
}
