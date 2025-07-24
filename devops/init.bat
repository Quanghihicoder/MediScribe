@echo off
REM Create Terraform bucket
aws s3 mb s3://mediscribe-terraform --region ap-southeast-2

REM Create terraform lock table
aws dynamodb create-table ^
  --table-name mediscribe-terraform-lock ^
  --attribute-definitions AttributeName=LockID,AttributeType=S ^
  --key-schema AttributeName=LockID,KeyType=HASH ^
  --billing-mode PAY_PER_REQUEST ^
  --region ap-southeast-2 ^
  --no-cli-pager