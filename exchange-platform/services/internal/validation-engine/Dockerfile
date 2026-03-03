# Stage 1: Build the Spring Boot application using Gradle
FROM eclipse-temurin:21-jdk-jammy AS build
WORKDIR /workspace/app

# Copy gradle files
COPY gradle gradle
COPY gradlew .
COPY build.gradle.kts .
COPY settings.gradle.kts .

# Download dependencies (this layer is cached)
RUN ./gradlew dependencies --no-daemon

# Copy source code and build the application
COPY src src
RUN ./gradlew clean bootJar --no-daemon -x test

# Stage 2: Create the runtime image
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

# Expose the application port
EXPOSE 8080

# Copy the built jar from the build stage
COPY --from=build /workspace/app/build/libs/*-SNAPSHOT.jar app.jar

# Run the Spring Boot application
ENTRYPOINT ["java", "-jar", "app.jar"]
