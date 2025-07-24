@echo off
setlocal enabledelayedexpansion
echo Building Lambda in Docker...

REM Clean up old builds
if exist ..\..\devops\modules\compute\lambda\build\summarizer_lambda.zip (
    del ..\..\devops\modules\compute\lambda\build\summarizer_lambda.zip
)

REM Run the Docker container to build
docker buildx build --platform linux/amd64 -f Dockerfile.lambda-build -t summarizer-lambda-builder --load .

REM Create output folder
if not exist ..\..\devops\modules\compute\lambda\build\summarizer_lambda (
    mkdir ..\..\devops\modules\compute\lambda\build\summarizer_lambda
)

REM Copy build artifacts from container
for /f "tokens=*" %%i in ('docker create summarizer-lambda-builder') do set CONTAINER_ID=%%i
docker cp !CONTAINER_ID!:/var/task ..\..\devops\modules\compute\lambda\build\summarizer_lambda
docker rm !CONTAINER_ID!

REM Zip it
cd ..\..\devops\modules\compute\lambda\build\summarizer_lambda\task\
powershell Compress-Archive -Path * -DestinationPath ..\..\summarizer_lambda.zip -Force

cd ..\..\
rmdir /s /q summarizer_lambda

echo Build complete: summarizer_lambda.zip
endlocal