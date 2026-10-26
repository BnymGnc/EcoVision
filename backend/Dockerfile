FROM maven:3.8.5-openjdk-17 AS build
WORKDIR /app
COPY . /app
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
# Defaults also apply to manually created Render services, not only Blueprints.
# An explicit JAVA_TOOL_OPTIONS environment value still overrides these defaults.
ENV JAVA_TOOL_OPTIONS="-Xmx128m -XX:MaxMetaspaceSize=112m -XX:MaxDirectMemorySize=16m -XX:ReservedCodeCacheSize=48m -XX:+UseSerialGC -Xss512k -XX:TieredStopAtLevel=1 -XX:+ExitOnOutOfMemoryError"
EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]
