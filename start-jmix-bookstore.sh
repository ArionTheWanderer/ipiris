#!/bin/bash
set -euo pipefail

# Проверка: наличие  зависимостей
if ! command -v yc &>/dev/null; then
  echo "Ошибка: Yandex Cloud CLI не установлен. Установить - https://cloud.yandex.ru/docs/cli/quickstart."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Ошибка: утилита jq не установлена. Установить - sudo apt install jq."
  exit 1
fi

# Переменные для названия сети, подсети, зоны и ВМ
NETWORK_NAME="jmix-bookstore-network"
SUBNET_NAME="jmix-bookstore-subnet"
INSTANCE_NAME="jmix-bookstore-vm"
ZONE="ru-central1-b"

# Получение folder-id из конфигурации yc
FOLDER_ID=$(yc config get folder-id)

# Имена SSH-ключей
SSH_KEY_NAME="ipiris"
PRIVATE_KEY="${SSH_KEY_NAME}"
PUBLIC_KEY="${SSH_KEY_NAME}.pub"

# Файл для cloud-init
CLOUD_CONFIG_FILE="cloud-config.yml"

# Проверка: если SSH-ключей не существует, то создать новые
if [ ! -f "$PRIVATE_KEY" ] || [ ! -f "$PUBLIC_KEY" ]; then
  echo "Генерирую пару SSH-ключей ($PRIVATE_KEY и $PUBLIC_KEY)..."
  ssh-keygen -t rsa -f "$SSH_KEY_NAME" -N ""
fi

# Создание сети
yc vpc network create \
  --name "$NETWORK_NAME" \
  --folder-id "$FOLDER_ID"

# Создание подсети
yc vpc subnet create \
  --name "$SUBNET_NAME" \
  --zone "$ZONE" \
  --network-name "$NETWORK_NAME" \
  --range "10.0.0.0/24" \
  --folder-id "$FOLDER_ID"

# Формирование cloud-init конфигурации
# Содержимое cloud-config файла создаёт пользователя ipiris, устанавливает docker и запускает контейнер
PUBLIC_KEY_CONTENT=$(cat "$PUBLIC_KEY")
cat > "$CLOUD_CONFIG_FILE" <<EOF
#cloud-config
users:
  - name: ipiris
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ${PUBLIC_KEY_CONTENT}
packages:
  - docker.io
runcmd:
  - systemctl start docker
  - systemctl enable docker
  - docker pull jmix/jmix-bookstore
  - docker run -d --restart unless-stopped -p 80:8080 jmix/jmix-bookstore
EOF

# Создание виртуальной машины
INSTANCE_ID=$(yc compute instance create \
  --name "$INSTANCE_NAME" \
  --zone "$ZONE" \
  --network-interface subnet-name="$SUBNET_NAME",nat-ip-version=ipv4 \
  --cores 2 \
  --memory 4GB \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,size=20,type=network-ssd \
  --metadata-from-file user-data="$CLOUD_CONFIG_FILE" \
  --format json | jq -r '.id')

# Ожидание запуска машины
echo "Ожидаем завершения начальной настройки (cloud-init)..."
sleep 30

# Получение публичного IP-адреса машины
PUBLIC_IP=$(yc compute instance get "$INSTANCE_ID" --format json | jq -r '.network_interfaces[0].primary_v4_address.address')
if [ -z "$PUBLIC_IP" ]; then
  echo "Не удалось получить публичный IP-адрес виртуальной машины."
  exit 1
fi

echo "Публичный IP машины: $PUBLIC_IP"

# Вывод инструкций для пользователя
echo ""
echo "=================================================================="
echo "Для подключения к виртуальному серверу выполните команду:"
echo "ssh -i $(pwd)/$PRIVATE_KEY ipiris@$PUBLIC_IP"
echo ""
echo "Для доступа к веб-приложению откройте в браузере:"
echo "http://$PUBLIC_IP"
echo "=================================================================="
