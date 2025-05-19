# Установка и настройка прокси-серверов

Этот проект предоставляет автоматизированную установку и настройку прокси-серверов Squid (HTTP) и Dante (SOCKS5) с использованием Docker.

## Компоненты

### 1. Прокси-серверы
- **Squid** - HTTP прокси-сервер
- **Dante** - SOCKS5 прокси-сервер

### 2. Dante Server
В директории `dante-server` находится конфигурация SOCKS5 прокси-сервера на базе Dante. Он обеспечивает безопасный доступ через SOCKS5 протокол с поддержкой аутентификации.

#### Установка Dante
```bash
cd dante-server
cp .env.example .env
# Отредактируйте .env файл
docker-compose up -d
```

#### Конфигурация
Dante использует следующие параметры в `.env`:
- `SOCKS_PORT` - порт для SOCKS5 прокси (по умолчанию 1080)
- `SOCKS_USER` - имя пользователя для аутентификации
- `SOCKS_PASS` - пароль для аутентификации

### 3. Балансировщик SOCKS5
В директории `socks5_balancer_asio` находится балансировщик SOCKS5 прокси на базе Boost.Asio. Он позволяет распределять нагрузку между несколькими SOCKS5 прокси-серверами.

#### Установка балансировщика
```bash
cd socks5_balancer_asio
cp .env.example .env
# Отредактируйте .env файл
docker-compose up -d
```

#### Конфигурация
Балансировщик использует `config.json` для настройки:
- Список прокси-серверов
- Метод балансировки
- Параметры подключения

## Требования

- Docker
- Docker Compose
- UFW (для настройки файрвола)
- curl (для проверки прокси)

## Установка

1. Клонируйте репозиторий:
```bash
git clone https://github.com/yourusername/install_proxy_server.git
cd install_proxy_server
```

2. Установите зависимости:
```bash
make install
```

3. Настройте прокси-серверы:
```bash
make config
```
Вам будет предложено ввести:
- Порт для HTTP прокси (по умолчанию 3128)
- Порт для SOCKS5 прокси (по умолчанию 1080)
- Имя пользователя (по умолчанию proxyuser)
- Пароль (по умолчанию proxypass)

4. Запустите прокси-серверы:
```bash
make setup
```

## Использование

### Проверка статуса
```bash
make status
```

### Просмотр логов
```bash
make logs
```

### Проверка работоспособности прокси
```bash
make test-proxy
```

### Перезапуск серверов
```bash
make restart
```

### Остановка и удаление
```bash
make clean
```

## Конфигурация

Все настройки сохраняются в файле `.env` в корневой директории проекта. Вы можете изменить их вручную или использовать команду `make config` для интерактивной настройки.

### Пример использования прокси

#### HTTP прокси (Squid)
```bash
curl -x http://proxyuser:proxypass@localhost:3128 http://ifconfig.me
```

#### SOCKS5 прокси (Dante)
```bash
curl --socks5-hostname localhost:1080 --proxy-user proxyuser:proxypass http://ifconfig.me
```

#### Балансировщик SOCKS5
```bash
curl --socks5-hostname localhost:1080 --proxy-user proxyuser:proxypass http://ifconfig.me
```

## Структура проекта

```
.
├── Makefile              # Скрипты для управления
├── .env                  # Конфигурация (создается автоматически)
├── proxy-server/         # Директория с конфигурацией прокси
│   ├── docker-compose.yml
│   ├── squid.conf
│   ├── sockd.conf
│   ├── credentials/      # Учетные данные
│   └── cache/           # Кэш Squid
├── dante-server/         # Конфигурация Dante
│   ├── docker-compose.yml
│   ├── danted.conf
│   ├── entrypoint.sh
│   └── .env.example
├── socks5_balancer_asio/ # Балансировщик SOCKS5
│   ├── docker-compose.yml
│   ├── config.json
│   ├── .env.example
│   └── generate-config.sh
└── README.md
```

## Безопасность

- Все учетные данные хранятся в зашифрованном виде
- Доступ к прокси-серверам ограничен аутентификацией
- Порт прокси автоматически открывается в UFW
- Контейнеры запускаются с минимальными привилегиями

## Устранение неполадок

1. Если прокси не работает, проверьте логи:
```bash
make logs
```

2. Проверьте статус контейнеров:
```bash
make status
```

3. Проверьте конфигурацию:
```bash
make show-config
```

4. Если проблема сохраняется, попробуйте перезапустить:
```bash
make restart
```

## Лицензия

MIT

