# syntax=docker/dockerfile:1.7
FROM maven:3.9.12-eclipse-temurin-17 AS build
ENV MAVEN_OPTS="-Xmx2048m -XX:+UseG1GC"
WORKDIR /build
# Build context is the repository root so migration scripts stay outside the backend tree.
COPY backend/ /build/
COPY database/migrations/ /database/migrations/
RUN --mount=type=cache,target=/root/.m2 \
    ["mvn", "-B", "-Plocal", "-pl", "ruoyi-admin", "-am", "-DskipTests=false", "package"]
FROM eclipse-temurin:17-jre-noble AS runtime
# Direct executable arrays install runtime dependencies without launching another shell.
# The build and runtime stages both use native Linux tooling; the final process is Java.
RUN ["sed", "-i", "s|http://|https://|g", "/etc/apt/sources.list.d/ubuntu.sources"]
RUN ["apt-get", "-o", "Acquire::Retries=3", "-o", "APT::Update::Error-Mode=any", "update"]
RUN ["apt-get", "install", "-y", "--no-install-recommends", "curl", "fontconfig", "fonts-noto-cjk"]
WORKDIR /app
COPY --from=build --chown=10001:10001 /build/ruoyi-admin/target/ruoyi-admin.jar /app/app.jar
USER 10001:10001
ENV TZ=Asia/Shanghai JAVA_TOOL_OPTIONS="-Xms256m -Xmx1536m -XX:+UseG1GC -Djava.awt.headless=true -Dfile.encoding=UTF-8"
EXPOSE 8080
# Actuator remains protected by the framework's monitor credentials. Do not expose it
# or place those credentials in a process argument just to perform a local probe.
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=5 CMD ["curl", "--fail", "--silent", "--output", "/dev/null", "http://127.0.0.1:8080/auth/code"]
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
