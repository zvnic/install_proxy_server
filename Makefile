# Variables
USER = proxyuser
PASS = proxypass
HTTP_PORT ?= 3128
SOCKS_PORT ?= 1080
IP := $(shell curl -s ifconfig.me || echo "YOUR_SERVER_IP")

# Default target
.PHONY: all
all: install setup start firewall credentials

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

# Clean Docker environment
.PHONY: clean-docker
clean-docker:
	@echo "Cleaning Docker environment..."
	-@cd proxy-server && docker-compose down --remove-orphans 2>/dev/null || true
	-@docker rm -f dante_proxy squid_proxy 2>/dev/null || true
	-@docker rmi -f proxy-server_dante 2>/dev/null || true
	-@docker system prune -af --volumes --force || true

# Setup configuration files and passwords
.PHONY: setup
setup:
	@echo "Setting up configuration files..."
	@mkdir -p proxy-server
	@echo "Creating files..."
	@cat > proxy-server/docker-compose.yml << EOF
version: '3.3'
services:
  squid:
    image: ubuntu/squid:latest
    container_name: squid_proxy
    ports:
      - "$(HTTP_PORT):3128"
    volumes:
      - ./squid.conf:/etc/squid/squid.conf
      - ./squid.passwd:/etc/squid/passwd
    environment:
      - TZ=UTC
    restart: unless-stopped
  dante:
    build:
      context: .
      dockerfile: Dockerfile.dante
    container_name: dante_proxy
    ports:
      - "$(SOCKS_PORT):1080"
    volumes:
      - ./danted.conf:/etc/danted.conf
    restart: unless-stopped
EOF
	@cat > proxy-server/Dockerfile.dante << EOF
FROM vimagick/dante

# Установка необходимых пакетов
RUN apt-get update && \\
    apt-get install -y --no-install-recommends \\
    libpam-pwdfile passwd && \\
    apt-get clean && \\
    rm -rf /var/lib/apt/lists/*

# Создание пользователя proxyuser с паролем proxypass
RUN useradd -m -s /bin/bash $(USER) && \\
    echo "$(USER):$(PASS)" | chpasswd

# Экспорт порта
EXPOSE 1080

CMD ["/usr/sbin/sockd"]
EOF
	@cat > proxy-server/squid.conf << EOF
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Proxy Authentication
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all
http_port 3128
EOF
	@cat > proxy-server/danted.conf << EOF
logoutput: stderr
internal: 0.0.0.0 port = 1080
external: eth0
socksmethod: username
user.privileged: root
user.unprivileged: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: connect disconnect error
}
EOF
	@cd proxy-server && htpasswd -bc squid.passwd $(USER) $(PASS)

# Start the services
.PHONY: start
start:
	@echo "Starting proxy services..."
	@cd proxy-server && docker-compose up -d --build

# Configure firewall
.PHONY: firewall
firewall:
	@echo "Configuring firewall..."
	@sudo ufw allow $(HTTP_PORT)
	@sudo ufw allow $(SOCKS_PORT)
	@sudo ufw reload

# Generate credentials file
.PHONY: credentials
credentials:
	@echo "Generating credentials file..."
	@echo "http://$(USER):$(PASS)@$(IP):$(HTTP_PORT)" > proxy_credentials.txt
	@echo "socks5://$(USER):$(PASS)@$(IP):$(SOCKS_PORT)" >> proxy_credentials.txt
	@echo "Credentials saved to proxy_credentials.txt"

# Check proxy status
.PHONY: status
status:
	@echo "Checking proxy status..."
	@echo "Docker containers:"
	@docker ps | grep -E "squid_proxy|dante_proxy" || echo "No proxy containers found"
	@echo "\nSquid proxy logs:"
	@docker logs squid_proxy 2>&1 | tail -n 10 || echo "Failed to get Squid logs"
	@echo "\nDante proxy logs:"
	@docker logs dante_proxy 2>&1 | tail -n 10 || echo "Failed to get Dante logs"
	@echo "\nTesting connections:"
	@echo "HTTP proxy: "
	@curl -s --max-time 5 --proxy http://$(USER):$(PASS)@localhost:$(HTTP_PORT) https://api.ipify.org || echo "Failed to connect to HTTP proxy"
	@echo "\nSOCKS proxy: "
	@curl -s --max-time 5 --socks5-hostname socks5://$(USER):$(PASS)@localhost:$(SOCKS_PORT) https://api.ipify.org || echo "Failed to connect to SOCKS proxy"

# Clean up
.PHONY: clean
clean: clean-docker
	@echo "Cleaning up..."
	-@sudo ufw delete allow $(HTTP_PORT) || true
	-@sudo ufw delete allow $(SOCKS_PORT) || true
	-@sudo ufw reload
	-@rm -rf proxy-server
	-@rm -f proxy_credentials.txt

# Prompt for ports
.PHONY: prompt
prompt:
	$(eval HTTP_PORT = $(shell read -p "Enter HTTP proxy port [3128]: " port && echo $${port:-3128}))
	$(eval SOCKS_PORT = $(shell read -p "Enter SOCKS5 proxy port [1080]: " port && echo $${port:-1080}))

# Full repair of the setup with check
.PHONY: repair
repair: clean install setup start firewall credentials
	@echo "Repair completed. Checking if services are running..."
	@sleep 3
	@$(MAKE) status
