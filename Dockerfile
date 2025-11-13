# Multi-stage Dockerfile for Spring Boot (Java 21)
# Build stage
FROM eclipse-temurin:21-jdk AS builder
WORKDIR /app

# Leverage Maven wrapper if present, otherwise use system maven
# Copy only pom and wrapper first to leverage Docker layer caching
COPY mvnw mvnw.cmd pom.xml ./
COPY .mvn/ .mvn/

# Ensure wrapper is executable
RUN chmod +x mvnw

# Download dependencies
RUN ./mvnw -q -DskipTests dependency:go-offline

# Copy sources
COPY src/ src/

# Build application
RUN ./mvnw -q -DskipTests package

# Runtime stage
FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app

# Copy built jar
COPY --from=builder /app/target/*-SNAPSHOT.jar /app/app.jar

# Expose application port
EXPOSE 8080

# Default JVM and Spring options can be overridden by env vars
ENV JAVA_OPTS="" \
    SPRING_PROFILES_ACTIVE=dev

# Start the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
