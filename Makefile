# Variables
-include .env
USER ?= proxyuser
PASS ?= proxypass
HTTP_PORT ?= 3128
SOCKS_PORT ?= 1080
IP := $(shell curl -s ifconfig.me || echo "YOUR_SERVER_IP")
SHELL := /bin/bash

# Цвета для вывода
GREEN = \033[0;32m
NC = \033[0m

# Default target
.PHONY: all
all: setup

# Install dependencies
.PHONY: install
install:
	@echo "$(GREEN)Проверка и установка зависимостей...$(NC)"
	@command -v docker >/dev/null 2>&1 || { echo "Docker не установлен. Устанавливаем..."; curl -fsSL https://get.docker.com | sh; }
	@command -v docker-compose >/dev/null 2>&1 || { echo "Docker Compose не установлен. Устанавливаем..."; curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$$(uname -s)-$$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose; }
	@command -v htpasswd >/dev/null 2>&1 || { echo "htpasswd не установлен. Устанавливаем..."; apt-get update && apt-get install -y apache2-utils; }
	@command -v curl >/dev/null 2>&1 || { echo "curl не установлен. Устанавливаем..."; apt-get update && apt-get install -y curl; }
	@command -v ufw >/dev/null 2>&1 || { echo "ufw не установлен. Устанавливаем..."; apt-get update && apt-get install -y ufw; }
	@sudo systemctl enable docker
	@sudo systemctl start docker
	@sudo ufw --force enable
	@echo "$(GREEN)Все зависимости установлены$(NC)"

# Interactive configuration
.PHONY: config
config:
	@echo "$(GREEN)Настройка прокси-серверов...$(NC)"
	@read -p "Введите имя пользователя [$(USER)]: " input_user; \
	USER=$${input_user:-$(USER)}; \
	read -p "Введите пароль [$(PASS)]: " input_pass; \
	PASS=$${input_pass:-$(PASS)}; \
	read -p "Введите порт HTTP прокси [$(HTTP_PORT)]: " input_http_port; \
	HTTP_PORT=$${input_http_port:-$(HTTP_PORT)}; \
	read -p "Введите порт SOCKS5 прокси [$(SOCKS_PORT)]: " input_socks_port; \
	SOCKS_PORT=$${input_socks_port:-$(SOCKS_PORT)}; \
	echo "USER=$$USER" > .env; \
	echo "PASS=$$PASS" >> .env; \
	echo "HTTP_PORT=$$HTTP_PORT" >> .env; \
	echo "SOCKS_PORT=$$SOCKS_PORT" >> .env; \
	echo "Конфигурация сохранена в .env файл"

# Create users
.PHONY: create-users
create-users:
	@echo "$(GREEN)Создание учетных данных...$(NC)"
	@mkdir -p proxy-server/credentials
	@htpasswd -bc proxy-server/credentials/squid.passwd $(USER) $(PASS)
	@echo "$(USER):$(PASS)" > proxy-server/credentials/dante.passwd
	@chmod 600 proxy-server/credentials/dante.passwd
	@echo "$(GREEN)Учетные данные созданы$(NC)"

# Create configuration files
.PHONY: create-configs
create-configs:
	@echo "$(GREEN)Создание конфигурационных файлов...$(NC)"
	@mkdir -p proxy-server/cache
	@mkdir -p proxy-server/credentials
	@cat > proxy-server/docker-compose.yml << 'EOF'
version: "3.8"

services:
  squid:
    image: ubuntu/squid:latest
    container_name: squid_proxy
    ports:
      - "${HTTP_PORT:-3128}:3128"
    volumes:
      - ./squid.conf:/etc/squid/squid.conf
      - ./credentials/squid.passwd:/etc/squid/passwd:ro
      - ./cache:/var/cache/squid
    environment:
      - TZ=UTC
      - HTTP_PORT=${HTTP_PORT:-3128}
    restart: unless-stopped
    networks:
      - proxy_network
    command: >
      /bin/sh -c "
        sed 's/^http_port .*/http_port ${HTTP_PORT:-3128}/' /etc/squid/squid.conf > /tmp/squid.conf &&
        mv /tmp/squid.conf /etc/squid/squid.conf &&
        squid -f /etc/squid/squid.conf -NY
      "
    healthcheck:
      test: ["CMD", "squidclient", "-h", "localhost", "cache_object://localhost/counters"]
      interval: 30s
      timeout: 10s
      retries: 3
    env_file:
      - ../.env

  dante:
    image: vimagick/dante:latest
    container_name: dante_proxy
    ports:
      - "${SOCKS_PORT:-1080}:1080"
    volumes:
      - ./sockd.conf:/etc/sockd.conf
      - ./credentials/dante.passwd:/etc/dante.passwd:ro
    environment:
      - TZ=UTC
      - SOCKS_PORT=${SOCKS_PORT:-1080}
    restart: unless-stopped
    networks:
      - proxy_network
    command: >
      /bin/sh -c "
        sed 's/port = .*/port = ${SOCKS_PORT:-1080}/' /etc/sockd.conf > /tmp/sockd.conf &&
        mv /tmp/sockd.conf /etc/sockd.conf &&
        sockd -f /etc/sockd.conf
      "
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "1080"]
      interval: 30s
      timeout: 10s
      retries: 3
    env_file:
      - ../.env

networks:
  proxy_network:
    driver: bridge
EOF
	@cat > proxy-server/squid.conf << 'EOF'
http_port 3128
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Proxy Authentication
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all
cache_mem 256 MB
maximum_object_size 1024 MB
cache_dir ufs /var/cache/squid 100 16 256
coredump_dir /var/cache/squid
access_log /var/log/squid/access.log
cache_log /var/log/squid/cache.log
pid_filename /run/squid.pid
EOF
	@cat > proxy-server/sockd.conf << 'EOF'
logoutput: stderr
internal: 0.0.0.0 port = 1080
external: eth0
socksmethod: username
user.privileged: root
user.notprivileged: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: error connect disconnect
    socksmethod: username
}
EOF
	@chmod 777 proxy-server/cache
	@echo "$(GREEN)Конфигурационные файлы созданы$(NC)"

# Setup configuration files and passwords
.PHONY: setup
setup: config create-users create-configs
	@echo "$(GREEN)Запуск прокси-серверов...$(NC)"
	@docker-compose -f proxy-server/docker-compose.yml up -d
	@echo "$(GREEN)Прокси-серверы запущены$(NC)"

# Clean up
.PHONY: clean
clean:
	@echo "$(GREEN)Очистка прокси-серверов...$(NC)"
	@docker-compose -f proxy-server/docker-compose.yml down
	@sudo rm -rf proxy-server
	@echo "$(GREEN)Очистка завершена$(NC)"

# Check status
.PHONY: check
check:
	@echo "$(GREEN)Статус прокси-серверов:$(NC)"
	@docker ps --filter "name=squid_proxy|dante_proxy"

# Logs
.PHONY: logs
logs:
	@echo "$(GREEN)Логи прокси-серверов:$(NC)"
	@docker-compose -f proxy-server/docker-compose.yml logs -f

# Restart
.PHONY: restart
restart:
	@echo "$(GREEN)Перезапуск прокси-серверов...$(NC)"
	@docker-compose -f proxy-server/docker-compose.yml restart
	@echo "$(GREEN)Прокси-серверы перезапущены$(NC)"

# Show current configuration
.PHONY: show-config
show-config:
	@echo "$(GREEN)Текущая конфигурация:$(NC)"
	@cat .env 2>/dev/null || echo "Конфигурация не найдена"
