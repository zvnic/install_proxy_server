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
RED = \033[0;31m
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
	@echo '      - "$${HTTP_PORT:-3128}:$${HTTP_PORT:-3128}"' >> proxy-server/docker-compose.yml
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
	@echo '        echo \"http_port $${HTTP_PORT:-3128}\" > /etc/squid/squid.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd\" >> /etc/squid/squid.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"auth_param basic realm Proxy Authentication\" >> /etc/squid/squid.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"acl authenticated proxy_auth REQUIRED\" >> /etc/squid/squid.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"http_access allow authenticated\" >> /etc/squid/squid.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"http_access deny all\" >> /etc/squid/squid.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"cache_mem 256 MB\" >> /etc/squid/squid.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"maximum_object_size 1024 MB\" >> /etc/squid/squid.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"cache_dir ufs /var/cache/squid 100 16 256\" >> /etc/squid/squid.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"coredump_dir /var/cache/squid\" >> /etc/squid/squid.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"access_log /var/log/squid/access.log\" >> /etc/squid/squid.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"cache_log /var/log/squid/cache.log\" >> /etc/squid/squid.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"pid_filename /run/squid.pid\" >> /etc/squid/squid.conf &&' >> proxy-server/docker-compose.yml
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
	@echo '      - "$${SOCKS_PORT:-1080}:$${SOCKS_PORT:-1080}"' >> proxy-server/docker-compose.yml
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
	@echo '        echo \"logoutput: stderr\" > /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"internal: 0.0.0.0 port = $${SOCKS_PORT:-1080}\" >> /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"external: eth0\" >> /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"socksmethod: username\" >> /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"user.privileged: root\" >> /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"user.notprivileged: nobody\" >> /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"client pass {\" >> /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"    from: 0.0.0.0/0 to: 0.0.0.0/0\" >> /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"    log: error connect disconnect\" >> /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"}\" >> /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"socks pass {\" >> /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"    from: 0.0.0.0/0 to: 0.0.0.0/0\" >> /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"    command: bind connect udpassociate\" >> /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"    log: error connect disconnect\" >> /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"    socksmethod: username\" >> /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
	@echo '        echo \"}\" >> /etc/sockd.conf &&' >> proxy-server/docker-compose.yml
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

# Test proxy connection
.PHONY: test-proxy
test-proxy:
	@echo "$(GREEN)Проверка подключения к SOCKS5 прокси...$(NC)"
	@if [ -f .env ]; then \
		. .env; \
		echo "Используем порт: $$SOCKS_PORT"; \
		echo "Используем пользователя: $$USER"; \
		echo "Проверяем подключение..."; \
		curl --socks5-hostname localhost:$$SOCKS_PORT --proxy-user $$USER:$$PASS http://ifconfig.me 2>/dev/null || { echo "$(RED)Ошибка подключения к прокси$(NC)"; exit 1; }; \
		echo "$(GREEN)Прокси работает корректно$(NC)"; \
	else \
		echo "$(RED)Файл конфигурации не найден. Сначала выполните make config$(NC)"; \
		exit 1; \
	fi
