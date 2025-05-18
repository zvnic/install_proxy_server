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
	@echo 'version: "3.8"' > proxy-server/docker-compose.yml
	@echo '' >> proxy-server/docker-compose.yml
	@echo 'services:' >> proxy-server/docker-compose.yml
	@echo '  squid:' >> proxy-server/docker-compose.yml
	@echo '    image: ubuntu/squid:latest' >> proxy-server/docker-compose.yml
	@echo '    container_name: squid_proxy' >> proxy-server/docker-compose.yml
	@echo '    ports:' >> proxy-server/docker-compose.yml
	@echo '      - "$${HTTP_PORT:-3128}:3128"' >> proxy-server/docker-compose.yml
	@echo '    volumes:' >> proxy-server/docker-compose.yml
	@echo '      - ./squid.conf:/etc/squid/squid.conf' >> proxy-server/docker-compose.yml
	@echo '      - ./credentials/squid.passwd:/etc/squid/passwd:ro' >> proxy-server/docker-compose.yml
	@echo '      - ./cache:/var/cache/squid' >> proxy-server/docker-compose.yml
	@echo '    environment:' >> proxy-server/docker-compose.yml
	@echo '      - TZ=UTC' >> proxy-server/docker-compose.yml
	@echo '      - HTTP_PORT=$${HTTP_PORT:-3128}' >> proxy-server/docker-compose.yml
	@echo '    restart: unless-stopped' >> proxy-server/docker-compose.yml
	@echo '    networks:' >> proxy-server/docker-compose.yml
	@echo '      - proxy_network' >> proxy-server/docker-compose.yml
	@echo '    command: >' >> proxy-server/docker-compose.yml
	@echo '      /bin/sh -c "' >> proxy-server/docker-compose.yml
	@echo '        sed \"s/^http_port .*/http_port $${HTTP_PORT:-3128}/\" /etc/squid/squid.conf > /tmp/squid.conf &&' >> proxy-server/docker-compose.yml
	@echo '        mv /tmp/squid.conf /etc/squid/squid.conf &&' >> proxy-server/docker-compose.yml
	@echo '        squid -N -f /etc/squid/squid.conf"' >> proxy-server/docker-compose.yml
	@echo '    healthcheck:' >> proxy-server/docker-compose.yml
	@echo '      test: ["CMD", "squidclient", "-h", "localhost", "cache_object://localhost/counters"]' >> proxy-server/docker-compose.yml
	@echo '      interval: 30s' >> proxy-server/docker-compose.yml
	@echo '      timeout: 10s' >> proxy-server/docker-compose.yml
	@echo '      retries: 3' >> proxy-server/docker-compose.yml
	@echo '    env_file:' >> proxy-server/docker-compose.yml
	@echo '      - ../.env' >> proxy-server/docker-compose.yml
	@echo '' >> proxy-server/docker-compose.yml
	@echo '  dante:' >> proxy-server/docker-compose.yml
	@echo '    image: vimagick/dante:latest' >> proxy-server/docker-compose.yml
	@echo '    container_name: dante_proxy' >> proxy-server/docker-compose.yml
	@echo '    ports:' >> proxy-server/docker-compose.yml
	@echo '      - "$${SOCKS_PORT:-1080}:1080"' >> proxy-server/docker-compose.yml
	@echo '    volumes:' >> proxy-server/docker-compose.yml
	@echo '      - ./sockd.conf:/etc/sockd.conf' >> proxy-server/docker-compose.yml
	@echo '      - ./credentials/dante.passwd:/etc/dante.passwd:ro' >> proxy-server/docker-compose.yml
	@echo '    environment:' >> proxy-server/docker-compose.yml
	@echo '      - TZ=UTC' >> proxy-server/docker-compose.yml
	@echo '      - SOCKS_PORT=$${SOCKS_PORT:-1080}' >> proxy-server/docker-compose.yml
	@echo '    restart: unless-stopped' >> proxy-server/docker-compose.yml
	@echo '    networks:' >> proxy-server/docker-compose.yml
	@echo '      - proxy_network' >> proxy-server/docker-compose.yml
	@echo '    command: >' >> proxy-server/docker-compose.yml
	@echo '      /bin/sh -c "' >> proxy-server/docker-compose.yml
	@echo '        sed \"s/port = .*/port = $${SOCKS_PORT:-1080}/\" /etc/sockd.conf > /tmp/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        cat /tmp/sockd.conf > /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        sockd -f /etc/sockd.conf"' >> proxy-server/docker-compose.yml
	@echo '    healthcheck:' >> proxy-server/docker-compose.yml
	@echo '      test: ["CMD", "nc", "-z", "localhost", "1080"]' >> proxy-server/docker-compose.yml
	@echo '      interval: 30s' >> proxy-server/docker-compose.yml
	@echo '      timeout: 10s' >> proxy-server/docker-compose.yml
	@echo '      retries: 3' >> proxy-server/docker-compose.yml
	@echo '    env_file:' >> proxy-server/docker-compose.yml
	@echo '      - ../.env' >> proxy-server/docker-compose.yml
	@echo '' >> proxy-server/docker-compose.yml
	@echo 'networks:' >> proxy-server/docker-compose.yml
	@echo '  proxy_network:' >> proxy-server/docker-compose.yml
	@echo '    driver: bridge' >> proxy-server/docker-compose.yml
	@echo 'http_port 3128' > proxy-server/squid.conf
	@echo 'auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd' >> proxy-server/squid.conf
	@echo 'auth_param basic realm Proxy Authentication' >> proxy-server/squid.conf
	@echo 'acl authenticated proxy_auth REQUIRED' >> proxy-server/squid.conf
	@echo 'http_access allow authenticated' >> proxy-server/squid.conf
	@echo 'http_access deny all' >> proxy-server/squid.conf
	@echo 'cache_mem 256 MB' >> proxy-server/squid.conf
	@echo 'maximum_object_size 1024 MB' >> proxy-server/squid.conf
	@echo 'cache_dir ufs /var/cache/squid 100 16 256' >> proxy-server/squid.conf
	@echo 'coredump_dir /var/cache/squid' >> proxy-server/squid.conf
	@echo 'access_log /var/log/squid/access.log' >> proxy-server/squid.conf
	@echo 'cache_log /var/log/squid/cache.log' >> proxy-server/squid.conf
	@echo 'pid_filename /run/squid.pid' >> proxy-server/squid.conf
	@echo 'logoutput: stderr' > proxy-server/sockd.conf
	@echo 'internal: 0.0.0.0 port = 1080' >> proxy-server/sockd.conf
	@echo 'external: eth0' >> proxy-server/sockd.conf
	@echo 'socksmethod: username' >> proxy-server/sockd.conf
	@echo 'user.privileged: root' >> proxy-server/sockd.conf
	@echo 'user.notprivileged: nobody' >> proxy-server/sockd.conf
	@echo 'client pass {' >> proxy-server/sockd.conf
	@echo '    from: 0.0.0.0/0 to: 0.0.0.0/0' >> proxy-server/sockd.conf
	@echo '    log: error connect disconnect' >> proxy-server/sockd.conf
	@echo '}' >> proxy-server/sockd.conf
	@echo 'socks pass {' >> proxy-server/sockd.conf
	@echo '    from: 0.0.0.0/0 to: 0.0.0.0/0' >> proxy-server/sockd.conf
	@echo '    command: bind connect udpassociate' >> proxy-server/sockd.conf
	@echo '    log: error connect disconnect' >> proxy-server/sockd.conf
	@echo '    socksmethod: username' >> proxy-server/sockd.conf
	@echo '}' >> proxy-server/sockd.conf
	@chmod 777 proxy-server/cache
	@chmod 644 proxy-server/squid.conf
	@chmod 644 proxy-server/sockd.conf
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
	@if [ -f proxy-server/docker-compose.yml ]; then \
		docker-compose -f proxy-server/docker-compose.yml down; \
	fi
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
	@if [ -f proxy-server/docker-compose.yml ]; then \
		docker-compose -f proxy-server/docker-compose.yml logs -f; \
	else \
		echo "Прокси-серверы не установлены"; \
	fi

# Restart
.PHONY: restart
restart:
	@echo "$(GREEN)Перезапуск прокси-серверов...$(NC)"
	@if [ -f proxy-server/docker-compose.yml ]; then \
		docker-compose -f proxy-server/docker-compose.yml restart; \
		echo "$(GREEN)Прокси-серверы перезапущены$(NC)"; \
	else \
		echo "Прокси-серверы не установлены"; \
	fi

# Show current configuration
.PHONY: show-config
show-config:
	@echo "$(GREEN)Текущая конфигурация:$(NC)"
	@cat .env 2>/dev/null || echo "Конфигурация не найдена"
