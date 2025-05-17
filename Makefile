# Makefile для настройки прокси-серверов

# Переменные
USER = proxyuser
PASS = proxypass
HTTP_PORT = 58601
SOCKS_PORT = 58602

# Основная цель
all: clean install setup start firewall credentials

# Установка зависимостей
install:
	@echo "Установка зависимостей..."
	@command -v docker >/dev/null 2>&1 || sudo apt install -y docker.io
	@command -v docker-compose >/dev/null 2>&1 || sudo apt install -y docker-compose
	@command -v htpasswd >/dev/null 2>&1 || sudo apt install -y apache2-utils
	@command -v curl >/dev/null 2>&1 || sudo apt install -y curl
	@command -v ufw >/dev/null 2>&1 || sudo apt install -y ufw

# Очистка окружения Docker
clean:
	@echo "Очистка..."
	-@cd proxy-server && docker-compose down --remove-orphans 2>/dev/null || true
	-@docker rm -f dante_proxy squid_proxy 2>/dev/null || true
	-@docker rmi -f proxy-server_dante 2>/dev/null || true
	-@docker system prune -af --volumes --force || true
	-@rm -rf proxy-server
	-@rm -f proxy_credentials.txt

# Создание конфигурационных файлов
setup:
	@echo "Настройка конфигурационных файлов..."
	@mkdir -p proxy-server
	@bash -c 'cat > proxy-server/docker-compose.yml << EOF
version: "3.3"
services:
  squid:
    image: ubuntu/squid:latest
    container_name: squid_proxy
    ports:
      - "${HTTP_PORT}:3128"
    volumes:
      - ./squid.conf:/etc/squid/squid.conf
      - ./squid.passwd:/etc/squid/passwd
    restart: unless-stopped
  dante:
    build:
      context: .
      dockerfile: Dockerfile.dante
    container_name: dante_proxy
    ports:
      - "${SOCKS_PORT}:1080"
    volumes:
      - ./danted.conf:/etc/danted.conf
    restart: unless-stopped
EOF'
	@bash -c 'cat > proxy-server/Dockerfile.dante << EOF
FROM vimagick/dante

# Установка необходимых пакетов
RUN apt-get update && \\
    apt-get install -y --no-install-recommends \\
    libpam-pwdfile passwd && \\
    apt-get clean && \\
    rm -rf /var/lib/apt/lists/*

# Создание пользователя
RUN useradd -m -s /bin/bash ${USER} && \\
    echo "${USER}:${PASS}" | chpasswd

EXPOSE 1080

CMD ["/usr/sbin/sockd"]
EOF'
	@bash -c 'cat > proxy-server/squid.conf << EOF
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Proxy Authentication
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all
http_port 3128
EOF'
	@bash -c 'cat > proxy-server/danted.conf << EOF
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
EOF'
	@cd proxy-server && htpasswd -bc squid.passwd $(USER) $(PASS)

# Запуск сервисов
start:
	@echo "Запуск прокси-серверов..."
	@cd proxy-server && docker-compose up -d --build

# Настройка брандмауэра
firewall:
	@echo "Настройка брандмауэра..."
	-@sudo ufw allow $(HTTP_PORT) || true
	-@sudo ufw allow $(SOCKS_PORT) || true
	-@sudo ufw reload || true

# Создание файла с учётными данными
credentials:
	@echo "Создание файла с учётными данными..."
	@IP=$$(curl -s ifconfig.me); \
	echo "http://$(USER):$(PASS)@$$IP:$(HTTP_PORT)" > proxy_credentials.txt; \
	echo "socks5://$(USER):$(PASS)@$$IP:$(SOCKS_PORT)" >> proxy_credentials.txt; \
	echo "Учётные данные сохранены в proxy_credentials.txt"

# Проверка статуса
status:
	@echo "Проверка статуса прокси-серверов..."
	@docker ps | grep -E "squid_proxy|dante_proxy" || echo "Прокси-серверы не запущены"
	@echo "\nЛоги Squid:"
	@docker logs squid_proxy 2>&1 | tail -n 5 || true
	@echo "\nЛоги Dante:"
	@docker logs dante_proxy 2>&1 | tail -n 5 || true

# Запрос портов - упрощенная версия
prompt:
	@echo "Используем порты: HTTP=${HTTP_PORT}, SOCKS=${SOCKS_PORT}"
	@echo "Если хотите изменить, отредактируйте Makefile"

# Полное восстановление
repair: clean install setup start firewall credentials status
