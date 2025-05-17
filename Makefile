# Variables
USER := proxyuser
PASS := proxypass
HTTP_PORT ?= 3128
SOCKS_PORT ?= 1080
IP := $(shell curl -s ifconfig.me || echo "YOUR_SERVER_IP")

# Default target
.PHONY: all
all: install setup start firewall credentials10 credentials

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
setup:
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
    image: spritsail/dante:latest\n\
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
user.privileged: nobody\n\
user.unprivileged: nobody\n\
clientmethod: none\n\
client pass {\n\
    from: 0.0.0.0/0 to: 0.0.0.0/0\n\
    log: connect disconnect error\n\
}\n\
socks pass {\n\
    from: 0.0.0.0/0 to: 0.0.0.0/0\n\
    command: bind connect udpassociate\n\
    log: connect disconnect error\n\
    protocol: socks5\n\
}" > sockd.conf
	@cd proxy-server && htpasswd -bc squid.passwd $(USER) $(PASS)
	@cd proxy-server && echo "$(USER):$(PASS)" > dante.passwd
	@cd proxy-server && chmod 644 dante.passwd
	@cd proxy-server && chown nobody:nogroup dante.passwd

# Start the services
.PHONY: start
start:
	@echo "Starting proxy services..."
	@cd proxy-server && docker-compose up -d

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

# Prompt for ports
.PHONY: prompt
prompt:
	$(eval HTTP_PORT := $(shell read -p "Enter HTTP proxy port [3128]: " port && echo $${port:-3128}))
	$(eval SOCKS_PORT := $(shell read -p "Enter SOCKS5 proxy port [1080]: " port && echo $${port:-1080}))
