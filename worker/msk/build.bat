@echo off
setlocal enabledelayedexpansion
echo Building Lambda in Docker...

REM Clean up old builds
if exist ..\..\devops\modules\compute\lambda\build\msk_lambda.zip (
    del ..\..\devops\modules\compute\lambda\build\msk_lambda.zip
)

REM Run the Docker container to build
docker buildx build --platform linux/amd64 -f Dockerfile.lambda-build -t msk-lambda-builder --load .

REM Create output folder
if not exist ..\..\devops\modules\compute\lambda\build\msk_lambda (
    mkdir ..\..\devops\modules\compute\lambda\build\msk_lambda
)

REM Copy build artifacts from container
for /f "tokens=*" %%i in ('docker create msk-lambda-builder') do set CONTAINER_ID=%%i
docker cp !CONTAINER_ID!:/var/task ..\..\devops\modules\compute\lambda\build\msk_lambda
docker rm !CONTAINER_ID!

REM Zip it
cd ..\..\devops\modules\compute\lambda\build\msk_lambda\task\
powershell Compress-Archive -Path * -DestinationPath ..\..\msk_lambda.zip -Force

cd ..\..\
rmdir /s /q msk_lambda

echo Build complete: msk_lambda.zip
endlocal