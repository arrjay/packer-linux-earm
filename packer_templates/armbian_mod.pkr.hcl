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
  qemu_binary     = "qemu-aarch64-static"
}

build {
  sources = ["source.arm-image.rock64"]

  provisioner "shell" {
    environment_vars = ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"]
    execute_command  = "/bin/chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    inline           = ["mkdir /newboot", "mkdir /IMD"]
  }

  post-processor "manifest" {}

  post-processor "shell-local" {
    environment_vars = ["RK64_BOOTFS_UUID=${var.rk64_bootfs_uuid}"]
    scripts          = ["./scripts/armbian-mod/HOST_create_bootfs.sh"]
  }
}
