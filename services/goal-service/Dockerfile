# syntax=docker/dockerfile:1
# Kalash Goal Service image (plan Section 5.6, LLD §27).
#
#   docker build -t kalash/goal-service services/goal-service
#
# Stage 1 builds the jar with the Maven Wrapper. Tests and Spotless run in
# `mvnw verify` and CI, not in the image build. Stage 2 runs Spring Boot's
# extracted layers on the Java 25 JRE as a non-root user.

ARG BUILD_IMAGE=maven:3.9.11-eclipse-temurin-25
ARG RUNTIME_IMAGE=eclipse-temurin:25.0.4.1_1-jre

FROM ${BUILD_IMAGE} AS build
WORKDIR /build
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
COPY src/main/ src/main/
RUN --mount=type=cache,target=/root/.m2 \
    chmod +x mvnw \
    && ./mvnw -B -q -Dmaven.test.skip=true -Dspotless.check.skip=true -Djacoco.skip=true package \
    && java -Djarmode=tools -jar target/goal-service-*.jar extract --layers --launcher \
       --destination /build/extracted

FROM ${RUNTIME_IMAGE} AS runtime
RUN groupadd --system --gid 10001 kalash \
    && useradd --system --uid 10001 --gid kalash --no-create-home --shell /usr/sbin/nologin kalash

WORKDIR /app
# Least-changing layers first, so a code change rebuilds only the last one.
COPY --from=build /build/extracted/dependencies/ ./
COPY --from=build /build/extracted/spring-boot-loader/ ./
COPY --from=build /build/extracted/snapshot-dependencies/ ./
COPY --from=build /build/extracted/application/ ./
COPY --chmod=0755 docker/healthcheck.sh /usr/local/bin/healthcheck

# Container-aware heap sizing: the JVM takes its limits from the container's
# memory limit (set in Compose), not from the host.
ENV SPRING_PROFILES_ACTIVE=docker \
    JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=25.0 -XX:+ExitOnOutOfMemoryError"

# Labels last, so new label values never invalidate the layers above.
# BUILD_DATE replaces the creation date inherited from the base image; Make
# passes the HEAD commit time, so unchanged sources give an identical image.
ARG VERSION=0.1.0-SNAPSHOT
ARG GIT_SHA=unknown
ARG BUILD_DATE=unknown
LABEL org.opencontainers.image.title="Kalash Goal Service" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.description="Goal lifecycle, balances and savings insights" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Kalash Financial Services"

USER kalash
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=90s --retries=3 \
    CMD ["healthcheck", "/health"]
# exec hands PID 1 to the JVM, so SIGTERM triggers the immediate shutdown (D-20).
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher \"$@\"", "--"]
