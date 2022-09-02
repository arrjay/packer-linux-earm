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
  output_filename   = "images/standard/pi.img"
  target_image_size = 4831838208
}

source "arm-image" "rock64" {
  image_mounts    = ["/boot", "/boot/IMD", "/"]
  iso_checksum    = var.dynamic_checksum
  iso_url         = "./images/netdata/rock64.img.xz"
  output_filename = "images/standard/rock64.img"
  qemu_binary     = "qemu-aarch64-static"
  target_image_size = 4831838208
}

source "arm-image" "sheeva" {
  image_mounts      = ["/boot", "/boot/IMD", "/"]
  iso_checksum      = var.dynamic_checksum
  iso_url           = "./images/netdata/sheeva.img.xz"
  output_filename   = "images/standard/sheeva.img"
  target_image_size = 3221225472
}

locals {
  envblock = [
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    "TZ=UCT",
    "DEBIAN_FRONTEND=noninteractive",
    "LANG=C",
    "XT_CGROUP_DKMS_VERSION=0.1",
    "UPSTREAM_KVER=4.19.132",
  ]
  cmdexec = "/bin/chmod +x {{ .Path }} ; {{ .Vars }} {{ .Path }}"
}

build {
  sources = ["source.arm-image.pi", "source.arm-image.sheeva", "source.arm-image.rock64"]

  provisioner "shell-local" {
    inline          = [
      "bash -exc 'p=$(pwd) && rm -f $p/files/standard/cache/imd/install.run && pushd vendor/imd && make OUTPUTDIR=$p/files/standard/cache/imd/ && popd'",
      "mkdir -p $p/files/standard/cache/etc/skel",
      "cp vendor/dotfiles/bashrc $p/files/standard/cache/etc/skel/.bashrc",
      "cp -R vendor/dotfiles/bash.d $p/files/standard/cache/etc/skel/.bash.d"
    ]
  }

  provisioner "shell" {
    environment_vars = local.envblock
    execute_command  = local.cmdexec
    inline           = ["mkdir -p /tmp/packer-files"]
  }

  provisioner "file" {
    destination = "/tmp/packer-files"
    source      = "files/standard/"
  }

  provisioner "shell" {
    environment_vars = local.envblock
    execute_command  = local.cmdexec
    scripts          = [
      "./scripts/standard/0_init.sh",
      "./scripts/standard/packages.sh",
      "./scripts/standard/xt_cgroup.sh",
      "./scripts/standard/rescue-initrd.sh",
      "./scripts/standard/install-dterm.sh",
      "./scripts/standard/ssm.sh",
      "./scripts/standard/ups.sh",
      "./scripts/standard/pdns.sh",
      "./scripts/standard/miniupnpd.sh",
      "./scripts/standard/tang.sh",
      "./scripts/standard/recursor.sh",
      "./scripts/standard/dnsfilter.sh",
      "./scripts/standard/ucarp.sh",
      "./scripts/standard/login-config.sh"
    ]
  }

  provisioner "shell" {
    environment_vars = local.envblock
    execute_command  = local.cmdexec
    inline           = [
      "rm -rf /tmp/packer-files",
      "df -m"
    ]
  }

}
