// external variables
variable "rock64_bootfs_uuid" {
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
variable "espressobin_imdfs_id" {
  type      = string
  sensitive = false
}

source "arm-image" "rock64" {
  image_mounts    = ["/"]
  iso_checksum    = "sha256:e14af9ec9243f3831fc19ca7cdb6428fd96c84b96661b951cb389c6d9316d6c4"
  iso_url         = "https://armbian.lv.auroradev.org/dl/rock64/archive/Armbian_23.5.1_Rock64_bookworm_current_6.1.30_minimal.img.xz"
  output_filename = "images/upstream/rock64.img"
  image_arch      = "arm64"
}

source "arm-image" "espressobin" {
  image_mounts    = ["/"]
  iso_checksum    = "sha256:e53bce3ac60d371a58302db002cad51c56a18372c887dee66ca65fb753d677d6"
  iso_url         = "https://mirrors.jevincanders.net/armbian/dl/espressobin/archive/Armbian_23.5.1_Espressobin_bookworm_current_5.15.113.img.xz"
  output_filename = "images/upstream/espressobin.img"
  image_arch      = "arm64"
}

build {
  sources = [ "source.arm-image.rock64", "source.arm-image.espressobin" ]

  provisioner "shell" {
    environment_vars = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"]
    execute_command  = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    inline           = [
      "mkdir /newboot",
      "mkdir /IMD",
      "[ -e /etc/profile.d/armbian-check-first-login.sh ] && rm /etc/profile.d/armbian-check-first-login.sh",
    ]
  }

  post-processor "manifest" {}

  post-processor "shell-local" {
    environment_vars = [
      "ROCK64_BOOTFS_UUID=${var.rock64_bootfs_uuid}",
      "ROCK64_IMDFS_ID=${var.rock64_imdfs_id}",
      "ESPRESSOBIN_BOOTFS_UUID=${var.espressobin_bootfs_uuid}",
      "ESPRESSOBIN_IMDFS_ID=${var.espressobin_imdfs_id}",
    ]
    scripts          = ["./scripts/armbian-mod/HOST_create_bootfs.sh"]
  }
}
