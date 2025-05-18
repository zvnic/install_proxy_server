#!/bin/bash
# Создаём пользователя с паролем из переменных окружения
useradd -m -s /bin/false $SOCKS_USER
echo "$SOCKS_USER:$SOCKS_PASS" | chpasswd
# Запускаем Dante
exec sockd -f /etc/danted.conf