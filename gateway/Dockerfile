# syntax=docker/dockerfile:1
# Kalash API Gateway: OpenResty with the Redis-backed rate limiter
# (plan Sections 5.5 and 5.6). Runs as a non-root user.
#
#   docker build -t kalash/gateway gateway                   # runtime image
#   docker build --target test -t kalash/gateway-test gateway  # Lua test tools

ARG OPENRESTY_VERSION=1.31.1.1

# Unit-test toolchain (D-23): busted, luacheck and luacov on OpenResty's LuaJIT.
# The default command lints, runs the specs and prints the coverage summary.
FROM openresty/openresty:${OPENRESTY_VERSION}-alpine-fat AS test
RUN luarocks install busted 2.3.0-1 \
    && luarocks install luacheck 1.2.0-1 \
    && luarocks install luacov 0.17.0-1
WORKDIR /gateway
COPY .busted .luacheckrc .luacov ./
COPY conf ./conf
COPY lua ./lua
COPY spec ./spec
CMD ["sh", "-c", "luacheck lua spec && busted && luacov && sed -n '/^Summary/,$p' luacov.report.out"]

FROM openresty/openresty:${OPENRESTY_VERSION}-alpine AS runtime
ARG GATEWAY_VERSION=0.1.0
ENV KALASH_GATEWAY_VERSION=${GATEWAY_VERSION}
WORKDIR /usr/local/openresty/nginx
RUN rm -f /etc/nginx/conf.d/default.conf html/*.html
COPY conf/ conf/
COPY lua/ lua/
COPY html/ html/
# The non-root user owns only what nginx writes: rendered configuration,
# the pid file (logs/) and temporary files (/var/run/openresty). Docker sets
# net.ipv4.ip_unprivileged_port_start=0 in containers, so port 80 still binds.
RUN sed -i "s/@GATEWAY_VERSION@/${GATEWAY_VERSION}/g" html/index.html \
    && mkdir -p conf/generated \
    && addgroup -S -g 10001 kalash \
    && adduser -S -D -H -u 10001 -G kalash -s /sbin/nologin kalash \
    && chown -R kalash:kalash conf/generated logs /var/run/openresty
COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Labels last, so new label values never invalidate the layers above.
# BUILD_DATE replaces the creation date inherited from the base image; Make
# passes the HEAD commit time, so unchanged sources give an identical image.
ARG GIT_SHA=unknown
ARG BUILD_DATE=unknown
LABEL org.opencontainers.image.title="Kalash API Gateway" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.description="OpenResty gateway with Redis-backed per-IP rate limiting" \
      org.opencontainers.image.version="${GATEWAY_VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Kalash Financial Services"

USER kalash
EXPOSE 80
# nginx -s quit semantics (plan Section 7.5), bounded by worker_shutdown_timeout.
STOPSIGNAL SIGQUIT
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1/health || exit 1
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
