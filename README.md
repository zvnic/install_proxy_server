# Прокси-сервер (HTTP и SOCKS5)

Проект представляет собой Docker-based прокси-сервер с поддержкой HTTP/HTTPS (Squid) и SOCKS5 (Dante) протоколов. Настройка автоматизирована с помощью Makefile.

## Возможности

- **HTTP/HTTPS прокси** (Squid):
  - Аутентификация по имени пользователя и паролю
  - Кэширование для улучшения производительности
  - Поддержка HTTPS
  - Настраиваемые правила доступа

- **SOCKS5 прокси** (Dante):
  - Аутентификация по имени пользователя и паролю
  - Поддержка TCP/UDP
  - Настраиваемые правила доступа
  - Логирование подключений

## Требования

- Docker и Docker Compose
- Make
- Apache2-utils (для создания файлов паролей)
- curl (для проверки работоспособности)

## Установка на сервере

1. Подключитесь к серверу:
```bash
ssh user@your-server-ip
```

2. Установите необходимые пакеты:
```bash
sudo apt update
sudo apt install -y git make docker.io docker-compose apache2-utils curl
```

3. Клонируйте репозиторий:
```bash
git clone https://github.com/zvnic/install_proxy_server.git
cd install_proxy_server
```

4. Запустите установку:
```bash
make install
```

5. Настройте и запустите прокси-серверы:
```bash
make setup
```

6. Настройте файрвол (опционально):
```bash
sudo ufw allow $(grep HTTP_PORT .env | cut -d'=' -f2)/tcp
sudo ufw allow $(grep SOCKS_PORT .env | cut -d'=' -f2)/tcp
sudo ufw reload
```

7. Проверьте работу прокси:
```bash
make check
```

### Использование прокси

После установки вы можете использовать прокси следующим образом:

1. HTTP прокси:
```bash
http://username:password@your-server-ip:3128
```

2. SOCKS5 прокси:
```bash
socks5://username:password@your-server-ip:1080
```

Где:
- `username` и `password` - учетные данные, которые вы указали при установке
- `your-server-ip` - IP-адрес вашего сервера
- `3128` и `1080` - порты, которые вы указали при установке (или порты по умолчанию)

### Проверка доступности прокси

1. Проверка HTTP прокси:
```bash
curl -x http://username:password@your-server-ip:3128 http://example.com
```

2. Проверка SOCKS5 прокси:
```bash
curl --socks5-hostname socks5://username:password@your-server-ip:1080 http://example.com
```

## Структура проекта

```
proxy-server/
├── docker-compose.yml    # Конфигурация Docker Compose
└── credentials/          # Директория для файлов с паролями
    ├── squid.passwd     # Пароли для HTTP прокси
    └── dante.passwd     # Пароли для SOCKS5 прокси
```

## Переменные окружения

Проект использует следующие переменные окружения (сохраняются в `.env`):

```bash
# Имя пользователя для аутентификации в прокси
USER=proxyuser

# Пароль для аутентификации в прокси
PASS=proxypass

# Порт для HTTP прокси (Squid)
HTTP_PORT=3128

# Порт для SOCKS5 прокси (Dante)
SOCKS_PORT=1080
```

## Конфигурация

### Squid (HTTP/HTTPS)

Основные настройки:
- Порт: 3128 (настраивается через HTTP_PORT)
- Аутентификация: Basic Auth
- Логирование: access.log

### Dante (SOCKS5)

Основные настройки:
- Порт: 1080 (настраивается через SOCKS_PORT)
- Аутентификация: username/password
- Логирование: syslog

## Безопасность

- Все контейнеры запускаются с минимальными привилегиями
- Файлы с паролями имеют ограниченные права доступа (600)
- Поддерживается аутентификация для обоих прокси
- Логирование всех подключений

## Мониторинг

- Healthcheck'и для обоих сервисов
- Логирование в syslog
- Доступ к логам через docker-compose
- Проверка статуса через make check

## Устранение неполадок

### Проблемы с портами

Если порты заняты:
```bash
sudo netstat -tuln | grep -E '3128|1080'
```

### Проблемы с контейнерами

Проверка статуса:
```bash
docker ps
docker logs squid_proxy
docker logs dante_proxy
```

### Проблемы с аутентификацией

Проверка файлов паролей:
```bash
ls -l proxy-server/credentials/
```

## Лицензия

MIT

## Автор

[Ваше имя/организация]
