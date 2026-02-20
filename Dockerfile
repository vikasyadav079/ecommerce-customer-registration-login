# ===== Stage 1: Build =====
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 \
    apt-get update && apt-get install -y maven && \
    mvn clean package -DskipTests -B

# ===== Stage 2: Extract layers =====
FROM eclipse-temurin:21-jdk AS extract
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract

# ===== Stage 3: Runtime =====
FROM eclipse-temurin:21-jre
WORKDIR /app

# Non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy layers (most stable first for cache optimization)
COPY --from=extract /app/dependencies/ ./
COPY --from=extract /app/spring-boot-loader/ ./
COPY --from=extract /app/snapshot-dependencies/ ./
COPY --from=extract /app/application/ ./

RUN chown -R appuser:appuser /app
USER appuser

# JVM tuning: ZGC, container-aware memory
ENV JAVA_OPTS="-XX:+UseZGC -XX:+ZGenerational \
    -XX:MaxRAMPercentage=75.0 \
    -XX:+UseContainerSupport \
    -Djava.security.egd=file:/dev/./urandom"

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health/liveness || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]
