source "arm-image" "rock64" {
  image_mounts    = ["/"]
  iso_checksum    = "sha256:f5edb2c031774e081ab408e632cece3f48c19c80b96bb619f0da0206230be609"
  iso_url         = "https://armbian.chi.auroradev.org/dl/rock64/archive/Armbian_22.05.4_Rock64_jammy_current_5.15.48.img.xz"
  output_filename = "images/upstream/rock64.img"
}

build {
  sources = ["source.arm-image.rock64"]

  post-processor "manifest" {}

  post-processor "shell-local" {
    scripts = ["./scripts/armbian-mod/HOST_create_bootfs.sh"]
  }
}
