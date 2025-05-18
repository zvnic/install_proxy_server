#!/bin/bash
# Устанавливаем apache2-utils для получения htpasswd
apt-get update && apt-get install -y apache2-utils
# Создаём файл паролей для Squid
htpasswd -bc /etc/squid/passwd $HTTP_USER $HTTP_PASS
# Запускаем Squid
exec /usr/sbin/squid -N -f /etc/squid/squid.conf