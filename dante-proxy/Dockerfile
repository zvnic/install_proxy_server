FROM alpine:latest

RUN apk add --no-cache dante-server shadow bash

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && \
    chown root:root /entrypoint.sh

EXPOSE 1080

CMD ["/entrypoint.sh"]
