terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "~> 0.136"  # укажите актуальную версию
    }
    tls = {
      source = "hashicorp/tls"
      version = "~> 4.0.6"
    }
    local = {
      source = "hashicorp/local"
      version = "~> 2.5.2"
    }
  }
}

variable "YC_TOKEN" {
  description = "Yandex Cloud token"
  type = string
}

variable "YC_CLOUD_ID" {
  description = "Yandex Cloud cloud id"
  type = string
}

variable "YC_FOLDER_ID" {
  description = "Yandex Cloud folder id"
  type = string
}

variable "YC_COMPUTE_DEFAULT_ZONE" {
  description = "Yandex Cloud compute default zone"
  type = string
}

provider "yandex" {
  token = var.YC_TOKEN
  cloud_id = var.YC_CLOUD_ID
  folder_id = var.YC_FOLDER_ID
  zone = var.YC_COMPUTE_DEFAULT_ZONE
}

# Генерация SSH-ключей и запись их в файлы
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits = 2048
}

resource "local_file" "private_key" {
  content = tls_private_key.ssh_key.private_key_pem
  filename = "${path.module}/ipiris"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content = tls_private_key.ssh_key.public_key_openssh
  filename = "${path.module}/ipiris.pub"
}

# Создание сети и подсети
resource "yandex_vpc_network" "network" {
  name = "jmix-bookstore-network"
}

resource "yandex_vpc_subnet" "subnet" {
  name = "jmix-bookstore-subnet"
  network_id = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.0.0.0/24"]
}

# Получение образа Ubuntu 22.04 LTS
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
  folder_id = "standard-images"
}

# Формирование cloud-init конфигурации
locals {
  cloud_init = <<EOF
#cloud-config
users:
  - name: ipiris
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ${tls_private_key.ssh_key.public_key_openssh}
packages:
  - docker.io
runcmd:
  - systemctl start docker
  - systemctl enable docker
  - docker pull jmix/jmix-bookstore
  - docker run -d --restart unless-stopped -p 80:8080 jmix/jmix-bookstore
EOF
}

# Создание виртуальной машины
resource "yandex_compute_instance" "vm" {
  name = "jmix-bookstore-vm"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size = 20
      type = "network-ssd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat = true
  }

  metadata = {
    user-data = local.cloud_init
  }
}

# Выходные переменные
output "ssh_connection" {
  description = "Строка для подключения к виртуальному серверу по SSH."
  value       = "ssh -i ${path.module}/ipiris ipiris@${yandex_compute_instance.vm.network_interface[0].nat_ip_address}"
}

output "web_app_url" {
  description = "Строка для открытия веб-приложения в браузере."
  value       = "http://${yandex_compute_instance.vm.network_interface[0].nat_ip_address}"
}
