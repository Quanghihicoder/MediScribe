@echo off
REM Authenticate to ECR
aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin 058264550947.dkr.ecr.ap-southeast-2.amazonaws.com

REM Build Docker image (Very important if build from Mac M chip)
docker buildx build --platform linux/amd64 -f ..\backend\Dockerfile -t mediscribe ..\backend --load
docker tag mediscribe:latest 058264550947.dkr.ecr.ap-southeast-2.amazonaws.com/mediscribe:latest
docker push 058264550947.dkr.ecr.ap-southeast-2.amazonaws.com/mediscribe:latest

docker buildx build --platform linux/amd64 -f ../worker/transcriber/Dockerfile.lambda-build -t mediscribe/transcriber ../worker/transcriber --load
docker tag mediscribe/transcriber:latest 058264550947.dkr.ecr.ap-southeast-2.amazonaws.com/mediscribe/transcriber:latest
docker push 058264550947.dkr.ecr.ap-southeast-2.amazonaws.com/mediscribe/transcriber:latest

docker buildx build --platform linux/amd64 -f ../worker/summarizer/Dockerfile.lambda-build -t mediscribe/summarizer ../worker/summarizer --load
docker tag mediscribe/summarizer:latest 058264550947.dkr.ecr.ap-southeast-2.amazonaws.com/mediscribe/summarizer:latest
docker push 058264550947.dkr.ecr.ap-southeast-2.amazonaws.com/mediscribe/summarizer:latest

cd ..\msk\
call build.bat

cd ..\..\frontend
npm install
npm run build

cd ..\devops
terraform init
terraform apply -auto-approve

aws s3 sync ..\frontend\dist s3://mediscribe-frontend --delete