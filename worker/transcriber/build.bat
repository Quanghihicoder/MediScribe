@echo off
setlocal enabledelayedexpansion
echo Building Lambda in Docker...

REM Clean up old builds
if exist ..\..\devops\modules\compute\lambda\build\transcriber_lambda.zip (
    del ..\..\devops\modules\compute\lambda\build\transcriber_lambda.zip
)

REM Run the Docker container to build
docker buildx build --platform linux/amd64 -f Dockerfile.lambda-build -t transcriber-lambda-builder --load .

REM Create output folder
if not exist ..\..\devops\modules\compute\lambda\build\transcriber_lambda (
    mkdir ..\..\devops\modules\compute\lambda\build\transcriber_lambda
)

REM Copy build artifacts from container
for /f "tokens=*" %%i in ('docker create transcriber-lambda-builder') do set CONTAINER_ID=%%i
docker cp !CONTAINER_ID!:/var/task ..\..\devops\modules\compute\lambda\build\transcriber_lambda
docker rm !CONTAINER_ID!

REM Zip it
cd ..\..\devops\modules\compute\lambda\build\transcriber_lambda\task\
powershell Compress-Archive -Path * -DestinationPath ..\..\transcriber_lambda.zip -Force

cd ..\..\
rmdir /s /q transcriber_lambda

echo Build complete: transcriber_lambda.zip
endlocal