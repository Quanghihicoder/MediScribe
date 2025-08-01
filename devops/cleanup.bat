@echo off

REM Safety destroy
call destroy.bat

REM Delete ECR
aws ecr delete-repository ^
  --repository-name mediscribe/backend ^
  --region ap-southeast-2 ^
  --force ^
  --no-cli-pager

aws ecr delete-repository ^
  --repository-name mediscribe/transcriber ^
  --region ap-southeast-2 ^
  --force ^
  --no-cli-pager

aws ecr delete-repository ^
  --repository-name mediscribe/summarizer ^
  --region ap-southeast-2 ^
  --force ^
  --no-cli-pager

REM Delete terraform state bucket
aws s3 rb s3://mediscribe-terraform --force --region ap-southeast-2

REM Delete terraform lock table
aws dynamodb delete-table ^
  --table-name mediscribe-terraform-lock ^
  --region ap-southeast-2 ^
  --no-cli-pager