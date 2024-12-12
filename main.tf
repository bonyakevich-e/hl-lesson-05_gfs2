
data "yandex_compute_image" "ubuntu2404" {
  # получаем id образа ubuntu 24.04
  family = "ubuntu-2404-lts-oslogin"
}

data "yandex_vpc_network" "default" {
  # получаем id дефолтной network
  name = "default"
}

resource "yandex_compute_disk" "shared_disk" {
  name = "shared-disk"
  type = "network-hdd"
  size = "5"
}

resource "yandex_vpc_subnet" "subnet01" {
  name           = "subnet01"
  network_id     = data.yandex_vpc_network.default.network_id
  v4_cidr_blocks = ["10.16.0.0/24"]
}

resource "yandex_compute_instance" "iscsi" {
  name     = "iscsi"
  hostname = "iscsi"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      name     = "boot-disk-iscsi"
      image_id = data.yandex_compute_image.ubuntu2404.id
    }
  }

  secondary_disk {
    disk_id     = yandex_compute_disk.shared_disk.id
    device_name = "shared_disk"
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet01.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}

resource "yandex_compute_instance" "cluster_instances" {
  count    = var.cluster_size
  name     = "${var.cluster_instance_name}${count.index + 1}"
  hostname = "${var.cluster_instance_name}${count.index + 1}"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      name     = "boot-disk-${var.cluster_instance_name}${count.index + 1}"
      image_id = data.yandex_compute_image.ubuntu2404.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet01.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }



}

resource "local_file" "inventory" {
  filename        = "./hosts"
  file_permission = "0644"
  content         = <<EOT
[iscsi_group]
%{for vm in yandex_compute_instance.iscsi.*~}
${vm.hostname} ansible_host=${vm.network_interface.0.nat_ip_address} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
%{endfor}
[cluster]
%{for vm in yandex_compute_instance.cluster_instances.*~}
${vm.hostname} ansible_host=${vm.network_interface.0.nat_ip_address} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
%{endfor~}
EOT
}

resource "local_file" "init_yml" {
  filename        = "./playbook.yml"
  file_permission = "0644"
  content = templatefile("playbook.tmpl.yml", {
    remote_user  = var.system_user,
    cluster_name = var.cluster_instance_name,
    cluster_size = var.cluster_size,
    iscsi        = yandex_compute_instance.iscsi,
    nodes        = yandex_compute_instance.cluster_instances[*]
    iqn_base     = var.iqn_base,
    vg_name      = var.vg_name,
    lv_name      = var.lv_name,
    fs_name      = var.fs_name
  })
}

resource "local_file" "setup_iscsi_target" {
  filename        = "./iscsi_target.bash"
  file_permission = "0644"
  content = templatefile("iscsi_target.bash.tmpl", {
    iqn_base     = var.iqn_base,
    nodes        = yandex_compute_instance.cluster_instances[*],
    cluster_name = var.cluster_instance_name
  })

}

/* resource "ansible_playbook" "nginx_provision" {
  playbook = "playbook.yml"

  name   = yandex_compute_instance.nginx.name
  groups = ["nginx"]

  limit = [yandex_compute_instance.nginx.name]

  extra_vars = {
    ansible_host                 = yandex_compute_instance.nginx.network_interface.0.nat_ip_address,
    ansible_user                 = "ubuntu",
    ansible_ssh_private_key_file = "~/.ssh/id_ed25519",
    ansible_ssh_common_args      = "-o StrictHostKeyChecking=no",
    nginx_external_ip            = yandex_compute_instance.nginx.network_interface.0.nat_ip_address,
    backend01_internal_ip        = yandex_compute_instance.backend01.network_interface.0.ip_address
  }

  replayable = true
  verbosity  = 3 # set the verbosity level of the debug output for this playbook
}

resource "ansible_playbook" "backend01_provision" {
  playbook = "playbook.yml"

  name   = yandex_compute_instance.backend01.name
  groups = ["backend"]

  limit = [yandex_compute_instance.backend01.name]

  extra_vars = {
    ansible_host                 = yandex_compute_instance.backend01.network_interface.0.nat_ip_address,
    ansible_user                 = "ubuntu",
    ansible_ssh_private_key_file = "~/.ssh/id_ed25519",
    ansible_ssh_common_args      = "-o StrictHostKeyChecking=no"
  }

  replayable = true
  verbosity  = 3 # set the verbosity level of the debug output for this playbook
}
 */

output "internal_ip_address_nginx0" {
  value = yandex_compute_instance.iscsi.network_interface.0.ip_address
}

output "external_ip_address_nginx" {
  value = yandex_compute_instance.iscsi.network_interface.0.nat_ip_address
}
