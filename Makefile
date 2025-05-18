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

# Setup configuration files and passwords
.PHONY: setup
setup: config create-users
	@echo "$(GREEN)Настройка конфигурационных файлов...$(NC)"
	@mkdir -p proxy-server/cache
	@mkdir -p proxy-server/credentials
	@touch proxy-server/squid.conf
	@touch proxy-server/sockd.conf
	@chmod 777 proxy-server/cache
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
