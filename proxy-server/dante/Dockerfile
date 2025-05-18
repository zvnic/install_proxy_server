FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    dante-server \
    netcat \
    && rm -rf /var/lib/apt/lists/*

COPY sockd.conf /etc/sockd.conf

RUN mkdir -p /var/log/dante \
    && chown -R nobody:nogroup /var/log/dante

EXPOSE 1080

USER nobody

CMD ["danted", "-D", "-f", "/etc/sockd.conf"] 