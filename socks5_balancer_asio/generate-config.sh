#!/bin/bash
source .env

# Проверяем, что SOCKS_SERVERS не пустой
if [ -z "$SOCKS_SERVERS" ]; then
    echo "Ошибка: SOCKS_SERVERS не задан в .env"
    exit 1
fi

# Начинаем формировать JSON-массив servers
servers_json="["
first=1

# Разделяем SOCKS_SERVERS на записи по запятым
IFS=',' read -ra servers <<< "$SOCKS_SERVERS"
for server in "${servers[@]}"; do
    # Проверяем, что строка начинается с socks5://
    if [[ ! "$server" =~ ^socks5:// ]]; then
        echo "Ошибка: Неверный протокол в записи сервера: $server"
        exit 1
    fi

    # Удаляем префикс socks5://
    server=${server#socks5://}

    # Извлекаем username:password и host:port
    IFS='@' read -r credentials host_port <<< "$server"
    if [ -z "$credentials" ] || [ -z "$host_port" ]; then
        echo "Ошибка: Неверный формат записи сервера: $server"
        exit 1
    fi

    # Извлекаем username и password
    IFS=':' read -r username password <<< "$credentials"
    if [ -z "$username" ] || [ -z "$password" ]; then
        echo "Ошибка: Неверные учетные данные в записи сервера: $server"
        exit 1
    fi

    # Извлекаем host и port
    IFS=':' read -r host port <<< "$host_port"
    if [ -z "$host" ] || [ -z "$port" ]; then
        echo "Ошибка: Неверный host или port в записи сервера: $server"
        exit 1
    fi

    # Добавляем запятую перед всеми элементами, кроме первого
    if [ $first -eq 1 ]; then
        first=0
    else
        servers_json+=","
    fi

    # Формируем JSON-объект для сервера
    servers_json+="{\"host\":\"$host\",\"port\":$port,\"username\":\"$username\",\"password\":\"$password\"}"
done
servers_json+="]"

# Генерируем config.json
cat << EOF > config.json
{
  "listenHost": "0.0.0.0",
  "listenPort": 1080,
  "balanceType": "random",
  "retryTimes": 3,
  "connectTimeout": 2000,
  "tcpCheckPeriod": 5000,
  "tcpCheckStart": 1000,
  "connectCheckPeriod": 300000,
  "connectCheckStart": 1000,
  "testRemoteHost": "www.google.com",
  "testRemotePort": 443,
  "auth": {
    "username": "$BALANCER_USER",
    "password": "$BALANCER_PASS"
  },
  "stateServerHost": "$STATE_SERVER_HOST",
  "stateServerPort": $STATE_SERVER_PORT,
  "servers": $servers_json
}
EOF

# Проверяем валидность JSON, если jq установлен
if command -v jq >/dev/null 2>&1; then
    jq . config.json >/dev/null 2>&1 || { echo "Ошибка: Сгенерированный config.json не является валидным JSON"; exit 1; }
fi