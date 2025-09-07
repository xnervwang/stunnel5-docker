FROM alpine:3.20

RUN apk add --no-cache stunnel su-exec libcap-setcap \
 && addgroup -S stunnel && adduser -S -G stunnel stunnel \
 && /usr/sbin/setcap 'cap_net_bind_service=+ep' /usr/bin/stunnel \
 || echo "WARN: setcap failed; use cap_add: NET_BIND_SERVICE at runtime or run as root."

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
COPY stunnel5-https-proxy.conf.template /app/etc/stunnel5-https-proxy.conf.template
COPY stunnel5-mtls-server.conf.template /app/etc/stunnel5-mtls-server.conf.template

USER root
EXPOSE 443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["stunnel", "/app/etc/stunnel.conf"]
