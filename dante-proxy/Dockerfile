FROM alpine:latest

RUN apk add --no-cache dante-server bash

COPY danted.conf.template /etc/danted.conf.template
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
