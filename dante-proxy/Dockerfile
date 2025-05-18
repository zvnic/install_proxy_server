FROM alpine:latest

RUN apk add --no-cache dante-server shadow bash

WORKDIR /app
COPY entrypoint.sh /app/
COPY danted.conf.template /app/

# Создаем скрипт-обертку для danted
RUN echo '#!/bin/sh\n/usr/bin/danted "$@"' > /app/run-danted.sh && \
    chmod +x /app/run-danted.sh && \
    chmod +x /app/entrypoint.sh && \
    chown root:root /app/entrypoint.sh && \
    mkdir -p /var/run/danted && \
    chown nobody:nobody /var/run/danted

EXPOSE 1080

ENTRYPOINT ["/app/entrypoint.sh"]
