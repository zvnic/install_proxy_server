#!/bin/bash
# Очищаем кэш apt
rm -rf /var/lib/apt/lists/*
# Обновляем ключи GPG для репозиториев Ubuntu
apt-get update -o Acquire::AllowInsecureRepositories=true || true
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32 871920D1991BC93C
# Обновляем список пакетов и устанавливаем apache2-utils
apt-get update && apt-get install -y apache2-utils
# Очищаем кэш apt
apt-get clean && rm -rf /var/lib/apt/lists/*
# Создаём файл паролей для Squid
htpasswd -bc /etc/squid/passwd $HTTP_USER $HTTP_PASS
# Запускаем Squid
exec /usr/sbin/squid -N -f /etc/squid/squid.conf