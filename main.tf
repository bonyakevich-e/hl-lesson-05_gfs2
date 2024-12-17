# получаем id образа ubuntu 24.04
data "yandex_compute_image" "ubuntu2404" {
  family = "ubuntu-2404-lts-oslogin"
}

# получаем id дефолтной network
data "yandex_vpc_network" "default" {
  name = "default"
}

# создаем дополнительный диск, который используется как iscsi share
resource "yandex_compute_disk" "shared_disk" {
  name = "shared-disk"
  type = "network-hdd"
  size = "5"
}

# создаем подсеть
resource "yandex_vpc_subnet" "subnet01" {
  name           = "subnet01"
  network_id     = data.yandex_vpc_network.default.network_id
  v4_cidr_blocks = ["10.16.0.0/24"]
}

# создаем сервер iscsi
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

# создаем инстансы для будущего кластера
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

# создаем inventory файл для Ansible
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

# создаем Ansible playbook
resource "local_file" "playbook_yml" {
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

# создаем скрипт, который выполняет настройку iscsi сервера
resource "local_file" "setup_iscsi_target" {
  filename        = "./iscsi_target.bash"
  file_permission = "0644"
  content = templatefile("iscsi_target.bash.tmpl", {
    iqn_base     = var.iqn_base,
    nodes        = yandex_compute_instance.cluster_instances[*],
    cluster_name = var.cluster_instance_name
  })

}

resource "null_resource" "ansible" {
  provisioner "local-exec" {
    command = "ansible-playbook -i ${local_file.inventory.filename} ${local_file.playbook_yml.filename}"
  }
}

output "internal_ip_address_nginx0" {
  value = yandex_compute_instance.iscsi.network_interface.0.ip_address
}

output "external_ip_address_nginx" {
  value = yandex_compute_instance.iscsi.network_interface.0.nat_ip_address
}
