FROM alpine:latest

RUN apk add --no-cache dante-server shadow bash

WORKDIR /app
COPY entrypoint.sh /app/
COPY danted.conf.template /app/

RUN chmod +x /app/entrypoint.sh && \
    chown root:root /app/entrypoint.sh

EXPOSE 1080

ENTRYPOINT ["/app/entrypoint.sh"]
