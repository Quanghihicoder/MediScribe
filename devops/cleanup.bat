@echo off

REM Safety destroy
destroy.bat

REM Delete terraform state bucket
aws s3 rb s3://mediscribe-terraform --force --region ap-southeast-2

REM Delete terraform lock table
aws dynamodb delete-table ^
  --table-name mediscribe-terraform-lock ^
  --region ap-southeast-2 ^
  --no-cli-pager