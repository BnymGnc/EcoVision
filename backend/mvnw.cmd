@echo off
setlocal
set BASE_DIR=%~dp0
set BASE_DIR=%BASE_DIR:~0,-1%
set WRAPPER_JAR=%BASE_DIR%\.mvn\wrapper\maven-wrapper.jar

if "%1"=="spring-boot:run" (
  java -Dmaven.multiModuleProjectDirectory="%BASE_DIR%" -cp "%WRAPPER_JAR%" org.apache.maven.wrapper.MavenWrapperMain -DskipTests package
  if errorlevel 1 exit /b %errorlevel%
  java -jar "%BASE_DIR%\target\backend-0.0.1-SNAPSHOT.jar"
  exit /b %errorlevel%
)

java -Dmaven.multiModuleProjectDirectory="%BASE_DIR%" -cp "%WRAPPER_JAR%" org.apache.maven.wrapper.MavenWrapperMain %*
endlocal
