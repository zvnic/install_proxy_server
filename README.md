# Установка и настройка прокси-серверов

## Требования
- Docker
- Docker Compose
- curl
- ufw (для настройки файрвола)

## Компоненты
1. Dante Server (SOCKS5 прокси)
2. Squid Server (HTTP прокси)
3. SOCKS5 Balancer (балансировщик на базе Boost.Asio)

## Установка и настройка

### 1. Dante Server (SOCKS5 прокси)

```bash
# Переходим в директорию Dante
cd dante-proxy

# Копируем пример конфигурации
cp .env.example .env

# Редактируем .env файл
nano .env
# Укажите:
# - SOCKS_PORT (порт для SOCKS5 прокси)
# - SOCKS_USER (имя пользователя)
# - SOCKS_PASS (пароль)

# Запускаем контейнер
docker-compose up -d

# Проверяем статус
docker ps | grep dante_proxy
```

### 2. Squid Server (HTTP прокси)

```bash
# Переходим в директорию Squid
cd squid-server

# Копируем пример конфигурации
cp .env.example .env

# Редактируем .env файл
nano .env
# Укажите:
# - HTTP_PORT (порт для HTTP прокси)
# - SQUID_USER (имя пользователя)
# - SQUID_PASS (пароль)

# Запускаем контейнер
docker-compose up -d

# Проверяем статус
docker ps | grep squid_proxy
```

### 3. SOCKS5 Balancer

```bash
# Переходим в директорию балансировщика
cd socks5_balancer_asio

# Генерируем конфигурацию
./generate-config.sh

# Запускаем контейнер
docker-compose up -d

# Проверяем статус
docker ps | grep balancer
```

## Проверка работоспособности

### Проверка Dante (SOCKS5)
```bash
# Проверка подключения
curl --socks5-hostname localhost:1080 --proxy-user proxyuser:proxypass http://ifconfig.me
```

### Проверка Squid (HTTP)
```bash
# Проверка подключения
curl -x http://proxyuser:proxypass@localhost:3128 http://ifconfig.me
```

### Проверка балансировщика
```bash
# Проверка подключения
curl --socks5-hostname localhost:1080 http://ifconfig.me
```

## Структура проекта

```
.
├── dante-proxy/              # SOCKS5 прокси-сервер
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── entrypoint.sh
│   └── .env.example
├── squid-server/            # HTTP прокси-сервер
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── entrypoint.sh
│   └── .env.example
└── socks5_balancer_asio/    # Балансировщик SOCKS5
    ├── docker-compose.yml
    ├── generate-config.sh
    └── .env.example
```

## Управление серверами

### Остановка серверов
```bash
# Остановка Dante
cd dante-proxy && docker-compose down

# Остановка Squid
cd squid-server && docker-compose down

# Остановка балансировщика
cd socks5_balancer_asio && docker-compose down
```

### Просмотр логов
```bash
# Логи Dante
cd dante-proxy && docker-compose logs -f

# Логи Squid
cd squid-server && docker-compose logs -f

# Логи балансировщика
cd socks5_balancer_asio && docker-compose logs -f
```

### Перезапуск серверов
```bash
# Перезапуск Dante
cd dante-proxy && docker-compose restart

# Перезапуск Squid
cd squid-server && docker-compose restart

# Перезапуск балансировщика
cd socks5_balancer_asio && docker-compose restart
```

## Настройка файрвола

```bash
# Разрешаем порты для прокси
sudo ufw allow 1080/tcp  # SOCKS5
sudo ufw allow 3128/tcp  # HTTP

# Проверяем статус
sudo ufw status
```

## Безопасность

1. Все прокси-серверы работают в изолированных контейнерах
2. Используется аутентификация по имени пользователя и паролю
3. Доступ к прокси ограничен только необходимыми портами
4. Все конфигурационные файлы защищены от несанкционированного доступа

## Устранение неполадок

1. Проверьте логи контейнеров:
```bash
docker-compose logs
```

2. Проверьте статус контейнеров:
```bash
docker ps
```

3. Проверьте доступность портов:
```bash
netstat -tulpn | grep -E '1080|3128'
```

4. Проверьте настройки файрвола:
```bash
sudo ufw status
```

## Лицензия

MIT

