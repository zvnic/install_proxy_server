FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    squid \
    apache2-utils \
    && rm -rf /var/lib/apt/lists/*

COPY squid.conf /etc/squid/squid.conf

RUN mkdir -p /var/cache/squid \
    && chown -R proxy:proxy /var/cache/squid \
    && chown -R proxy:proxy /var/log/squid

EXPOSE 3128

USER proxy

CMD ["squid", "-NYC"] 