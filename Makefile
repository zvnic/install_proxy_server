# Variables
USER ?= proxyuser
PASS ?= proxypass
HTTP_PORT ?= 3128
SOCKS_PORT ?= 1080
IP := $(shell curl -s ifconfig.me || echo "YOUR_SERVER_IP")

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

# Setup configuration files and passwords
.PHONY: setup
setup: create-users
	@echo "Setting up configuration files..."
	@mkdir -p proxy-server
	@cd proxy-server && \
		echo "version: '3.8'\n\
services:\n\
  squid:\n\
    image: ubuntu/squid:latest\n\
    container_name: squid_proxy\n\
    ports:\n\
      - \"$(HTTP_PORT):3128\"\n\
    volumes:\n\
      - ./squid.conf:/etc/squid/squid.conf\n\
      - ./squid.passwd:/etc/squid/passwd\n\
    environment:\n\
      - TZ=UTC\n\
    restart: unless-stopped\n\
    networks:\n\
      - proxy_network\n\
  dante:\n\
    image: vimagick/dante:latest\n\
    container_name: dante_proxy\n\
    ports:\n\
      - \"$(SOCKS_PORT):1080\"\n\
    volumes:\n\
      - ./sockd.conf:/etc/sockd.conf\n\
      - ./dante.passwd:/etc/dante.passwd\n\
    environment:\n\
      - TZ=UTC\n\
    restart: unless-stopped\n\
    networks:\n\
      - proxy_network\n\
networks:\n\
  proxy_network:\n\
    driver: bridge" > docker-compose.yml
	@cd proxy-server && \
		echo "auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd\n\
auth_param basic realm Proxy Authentication\n\
acl authenticated proxy_auth REQUIRED\n\
http_access allow authenticated\n\
http_access deny all\n\
http_port 3128" > squid.conf
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
}" > sockd.conf
	@cd proxy-server && docker-compose up -d
	@echo "http://$(USER):$(PASS)@localhost:$(HTTP_PORT)" > proxy_credentials.txt
	@echo "socks5://$(USER):$(PASS)@localhost:$(SOCKS_PORT)" >> proxy_credentials.txt
	@echo "Прокси-серверы запущены. Данные для доступа сохранены в proxy_credentials.txt"

# Create users
.PHONY: create-users
create-users:
	@mkdir -p proxy-server/credentials
	@htpasswd -bc proxy-server/credentials/squid.passwd $(USER) $(PASS)
	@echo "$(USER):$(PASS)" > proxy-server/credentials/dante.passwd
	@chmod 600 proxy-server/credentials/*.passwd

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

# Prompt for ports
.PHONY: prompt
prompt:
	@read -p "Enter HTTP proxy port [$(HTTP_PORT)]: " http_port; \
	HTTP_PORT=$${http_port:-$(HTTP_PORT)}; \
	read -p "Enter SOCKS5 proxy port [$(SOCKS_PORT)]: " socks_port; \
	SOCKS_PORT=$${socks_port:-$(SOCKS_PORT)}; \
	echo "HTTP_PORT=$$HTTP_PORT" > .env; \
	echo "SOCKS_PORT=$$SOCKS_PORT" >> .env; \
	echo "Порты обновлены: HTTP=$$HTTP_PORT, SOCKS5=$$SOCKS_PORT"
