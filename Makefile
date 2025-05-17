#!/bin/bash

# Очистка Docker
echo "Очистка Docker..."
docker-compose down --remove-orphans 2>/dev/null || true
docker rm -f dante_proxy squid_proxy 2>/dev/null || true
docker rmi -f proxy-server_dante 2>/dev/null || true
docker system prune -af --volumes

# Создание необходимых директорий и файлов
echo "Создание файлов конфигурации..."
mkdir -p proxy-server
cd proxy-server

# Создаем debug-контейнер для определения местоположения sockd
echo "Проверка местоположения sockd в Ubuntu 20.04..."

cat > debug-dockerfile << 'EOF'
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y dante-server
CMD ["bash", "-c", "echo 'Files from package:' && dpkg -L dante-server | grep -i bin && echo 'Find sockd:' && find / -name sockd -type f 2>/dev/null && echo 'Which sockd:' && which sockd || echo 'Sockd not in PATH'"]
EOF

docker build -t sockd-debug -f debug-dockerfile .
docker run --rm sockd-debug

# На основе результатов отладки создаем Dockerfile
echo "Создаем Dockerfile с правильным путем к sockd..."
cat > Dockerfile << 'EOF'
FROM ubuntu:20.04
RUN apt-get update && \
    apt-get install -y dante-server && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
COPY sockd.conf /etc/sockd.conf
COPY dante.passwd /etc/dante.passwd
RUN chmod 644 /etc/dante.passwd
EXPOSE 1080
# Используем запуск через bash для поиска sockd в разных местах
CMD ["bash", "-c", "if [ -f /usr/bin/sockd ]; then /usr/bin/sockd -f /etc/sockd.conf; elif [ -f /usr/sbin/sockd ]; then /usr/sbin/sockd -f /etc/sockd.conf; else echo 'sockd не найден!' && find / -name sockd -type f; fi"]
EOF

# Создаем docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.3'
services:
  squid:
    image: ubuntu/squid:latest
    container_name: squid_proxy
    ports:
      - "58601:3128"
    volumes:
      - ./squid.conf:/etc/squid/squid.conf
      - ./squid.passwd:/etc/squid/passwd
    environment:
      - TZ=UTC
    restart: unless-stopped
    
  dante:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: dante_proxy
    ports:
      - "58602:1080"
    environment:
      - TZ=UTC
    restart: unless-stopped
EOF

# Создаем squid.conf
cat > squid.conf << 'EOF'
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Proxy Authentication
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all
http_port 3128
EOF

# Создаем sockd.conf
cat > sockd.conf << 'EOF'
logoutput: stderr
internal: 0.0.0.0 port = 1080
external: eth0
method: username
user.privileged: nobody
user.unprivileged: nobody
clientmethod: none
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error iooperation
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: connect disconnect error iooperation
    protocol: socks5
}
EOF

# Создаем пароли
echo "Создание файлов с паролями..."
htpasswd -bc squid.passwd proxyuser proxypass
echo "proxyuser:proxypass" > dante.passwd
chmod 644 dante.passwd

# Конфигурация Firewall
echo "Настройка Firewall..."
ufw allow 58601/tcp
ufw allow 58602/tcp
ufw reload

# Запуск сервисов
echo "Запуск прокси-серверов..."
docker-compose up -d --build

# Создание файла с учетными данными
echo "Создание файла с учетными данными..."
SERVER_IP=$(curl -s ifconfig.me || echo "YOUR_SERVER_IP")
echo "http://proxyuser:proxypass@$SERVER_IP:58601" > ../proxy_credentials.txt
echo "socks5://proxyuser:proxypass@$SERVER_IP:58602" >> ../proxy_credentials.txt
echo "Учетные данные сохранены в proxy_credentials.txt"

cd ..
echo "Установка завершена!"
