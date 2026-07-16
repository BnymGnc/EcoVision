@echo off
setlocal
set BASE_DIR=%~dp0
set BASE_DIR=%BASE_DIR:~0,-1%
set WRAPPER_JAR=%BASE_DIR%\.mvn\wrapper\maven-wrapper.jar
java -Dmaven.multiModuleProjectDirectory="%BASE_DIR%" -cp "%WRAPPER_JAR%" org.apache.maven.wrapper.MavenWrapperMain %*
endlocal
