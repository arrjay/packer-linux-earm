// external variables
variable "rk64_bootfs_uuid" {
  type      = string
  sensitive = false
}

source "arm-image" "rock64" {
  image_mounts    = ["/"]
  iso_checksum    = "sha256:a4c277913dc1a160a10dc956677e6ec0faa4a3cca964b66b1dd03f829cbeac40"
  iso_url         = "https://mirrors.aliyun.com/armbian-releases/rock64/archive/Armbian_23.5.1_Rock64_jammy_current_6.1.30_minimal.img.xz"
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
    environment_vars = ["RK64_BOOTFS_UUID=${var.rk64_bootfs_uuid}"]
    scripts          = ["./scripts/armbian-mod/HOST_create_bootfs.sh"]
  }
}
