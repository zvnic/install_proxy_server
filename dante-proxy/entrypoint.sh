#!/bin/bash
set -e

# Проверяем существование пользователя и создаем если не существует
if ! id "${USER:-proxyuser}" >/dev/null 2>&1; then
    adduser -D -H -s /sbin/nologin "${USER:-proxyuser}"
    echo "${USER:-proxyuser}:${PASS:-proxypass}" | chpasswd
fi

# Генерируем конфигурацию
cat > /etc/danted.conf << EOF
logoutput: stderr
internal: 0.0.0.0 port = ${SOCKS_PORT:-1080}
external: eth0
socksmethod: username
user.privileged: root
user.notprivileged: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: error connect disconnect
    socksmethod: username
}
EOF

# Запускаем Dante
exec danted -f /etc/danted.conf
