# Variables
-include .env
USER ?= proxyuser
PASS ?= proxypass
HTTP_PORT ?= 3128
SOCKS_PORT ?= 1080
IP := $(shell curl -s ifconfig.me || echo "YOUR_SERVER_IP")
SHELL := /bin/bash

# Default target
.PHONY: all
all: setup

# Install dependencies
.PHONY: install
install:
	@echo "Checking and installing dependencies..."
	@command -v docker >/dev/null 2>&1 || { sudo apt update; sudo apt install -y docker.io; }
	@command -v docker-compose >/dev/null 2>&1 || sudo apt install -y docker-compose
	@command -v htpasswd >/dev/null 2>&1 || sudo apt install -y apache2-utils
	@command -v curl >/dev/null 2>&1 || sudo apt install -y curl
	@command -v ufw >/dev/null 2>&1 || sudo apt install -y ufw
	@sudo systemctl enable docker
	@sudo systemctl start docker
	@sudo ufw --force enable

# Interactive configuration
.PHONY: config
config:
	@echo "Настройка прокси-серверов..."
	@read -p "Введите имя пользователя [$(USER)]: " username; \
	USER=$${username:-$(USER)}; \
	read -p "Введите пароль [$(PASS)]: " password; \
	echo ""; \
	PASS=$${password:-$(PASS)}; \
	read -p "Введите порт HTTP прокси [$(HTTP_PORT)]: " http_port; \
	HTTP_PORT=$${http_port:-$(HTTP_PORT)}; \
	read -p "Введите порт SOCKS5 прокси [$(SOCKS_PORT)]: " socks_port; \
	SOCKS_PORT=$${socks_port:-$(SOCKS_PORT)}; \
	echo "USER=$$USER" > .env; \
	echo "PASS=$$PASS" >> .env; \
	echo "HTTP_PORT=$$HTTP_PORT" >> .env; \
	echo "SOCKS_PORT=$$SOCKS_PORT" >> .env; \
	echo "Конфигурация сохранена в .env файл"

# Create users
.PHONY: create-users
create-users:
	@mkdir -p proxy-server/credentials
	@htpasswd -bc proxy-server/credentials/squid.passwd $(USER) $(PASS)
	@echo "$(USER):$(PASS)" > proxy-server/credentials/dante.passwd
	@chmod 644 proxy-server/credentials/*.passwd

# Setup configuration files and passwords
.PHONY: setup
setup: config create-users
	@echo "Setting up configuration files..."
	@mkdir -p proxy-server
	@cd proxy-server && \
		echo 'version: "3.8"' > docker-compose.yml && \
		echo 'services:' >> docker-compose.yml && \
		echo '  squid:' >> docker-compose.yml && \
		echo '    image: ubuntu/squid:latest' >> docker-compose.yml && \
		echo '    container_name: squid_proxy' >> docker-compose.yml && \
		echo '    ports:' >> docker-compose.yml && \
		echo '      - "$(HTTP_PORT):3128"' >> docker-compose.yml && \
		echo '    volumes:' >> docker-compose.yml && \
		echo '      - ./squid.conf:/etc/squid/squid.conf' >> docker-compose.yml && \
		echo '      - ./credentials/squid.passwd:/etc/squid/passwd:ro' >> docker-compose.yml && \
		echo '    environment:' >> docker-compose.yml && \
		echo '      - TZ=UTC' >> docker-compose.yml && \
		echo '    restart: unless-stopped' >> docker-compose.yml && \
		echo '    networks:' >> docker-compose.yml && \
		echo '      - proxy_network' >> docker-compose.yml && \
		echo '  dante:' >> docker-compose.yml && \
		echo '    image: vimagick/dante:latest' >> docker-compose.yml && \
		echo '    container_name: dante_proxy' >> docker-compose.yml && \
		echo '    ports:' >> docker-compose.yml && \
		echo '      - "$(SOCKS_PORT):1080"' >> docker-compose.yml && \
		echo '    volumes:' >> docker-compose.yml && \
		echo '      - ./sockd.conf:/etc/sockd.conf' >> docker-compose.yml && \
		echo '      - ./credentials/dante.passwd:/etc/dante.passwd:ro' >> docker-compose.yml && \
		echo '    environment:' >> docker-compose.yml && \
		echo '      - TZ=UTC' >> docker-compose.yml && \
		echo '    restart: unless-stopped' >> docker-compose.yml && \
		echo '    networks:' >> docker-compose.yml && \
		echo '      - proxy_network' >> docker-compose.yml && \
		echo 'networks:' >> docker-compose.yml && \
		echo '  proxy_network:' >> docker-compose.yml && \
		echo '    driver: bridge' >> docker-compose.yml
	@cd proxy-server && \
		echo "auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd\n\
auth_param basic realm Proxy Authentication\n\
acl authenticated proxy_auth REQUIRED\n\
http_access allow authenticated\n\
http_access deny all\n\
http_port 3128\n\
cache_mem 256 MB\n\
maximum_object_size 1024 MB\n\
cache_dir ufs /var/cache/squid 100 16 256" > squid.conf
	@cd proxy-server && \
		echo "logoutput: stderr\n\
internal: 0.0.0.0 port = 1080\n\
external: eth0\n\
method: username\n\
user.privileged: root\n\
user.unprivileged: nobody\n\
clientmethod: none\n\
client pass {\n\
    from: 0.0.0.0/0 to: 0.0.0.0/0\n\
    log: connect disconnect\n\
}\n\
socks pass {\n\
    from: 0.0.0.0/0 to: 0.0.0.0/0\n\
    command: bind connect udpassociate\n\
    log: connect disconnect\n\
    user: authenticated\n\
}" > sockd.conf
	@cd proxy-server && docker-compose up -d
	@echo "http://$(USER):$(PASS)@localhost:$(HTTP_PORT)" > proxy_credentials.txt
	@echo "socks5://$(USER):$(PASS)@localhost:$(SOCKS_PORT)" >> proxy_credentials.txt
	@echo "Прокси-серверы запущены. Данные для доступа сохранены в proxy_credentials.txt"

# Clean up
.PHONY: clean
clean:
	@echo "Cleaning up..."
	@cd proxy-server && docker-compose down || true
	@sudo ufw delete allow $(HTTP_PORT) || true
	@sudo ufw delete allow $(SOCKS_PORT) || true
	@sudo ufw reload
	@rm -rf proxy-server
	@rm -f proxy_credentials.txt
	@rm -f .env
	@echo "Прокси-серверы остановлены и конфигурации удалены"

# Check status
.PHONY: check
check:
	@echo "Проверка статуса контейнеров:"
	@cd proxy-server && docker-compose ps
	@echo "\nПроверка HTTP прокси:"
	@curl -x http://$(USER):$(PASS)@localhost:$(HTTP_PORT) http://example.com -I
	@echo "\nПроверка SOCKS5 прокси:"
	@curl --socks5-hostname socks5://$(USER):$(PASS)@localhost:$(SOCKS_PORT) http://example.com -I

# Logs
.PHONY: logs
logs:
	@cd proxy-server && docker-compose logs -f

# Restart
.PHONY: restart
restart:
	@cd proxy-server && docker-compose restart
	@echo "Прокси-серверы перезапущены"

# Show current configuration
.PHONY: show-config
show-config:
	@echo "Текущая конфигурация:"
	@echo "Пользователь: $(USER)"
	@echo "HTTP порт: $(HTTP_PORT)"
	@echo "SOCKS5 порт: $(SOCKS_PORT)"
	@echo "\nДанные для доступа:"
	@cat proxy_credentials.txt 2>/dev/null || echo "Файл с данными не найден"
