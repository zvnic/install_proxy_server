#!/bin/sh
set -e

envsubst < /etc/danted.conf.template > /etc/danted.conf

# Добавление пользователя
adduser -D "$PROXY_USER"
echo "$PROXY_USER:$PROXY_PASS" | chpasswd

exec danted -f /etc/danted.conf
