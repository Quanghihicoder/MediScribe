resource "aws_lambda_function" "summarizer_lambda" {
  function_name    = var.summarizer_lambda_name
  handler          = "handler.handler"
  runtime          = "python3.10"
  role             = var.lambda_exec_role_arn
  filename         = "${path.module}/build/summarizer_lambda.zip"
  source_code_hash = fileexists("${path.module}/build/summarizer_lambda.zip") ? filebase64sha256("${path.module}/build/summarizer_lambda.zip") : null

  memory_size = 1024
  timeout     = var.summarizer_lambda_timeout

  environment {
    variables = {
      MSK_CLUSTER_ARN = var.msk_cluster_arn
      OPENAI_API_KEY  = var.openai_api_key
    }
  }

  vpc_config {
    subnet_ids         = [var.private_subnet_a_id, var.private_subnet_b_id]
    security_group_ids = [var.lambda_msk_sg_id]
  }
}

resource "aws_lambda_function" "transcriber_lambda" {
  function_name    = var.transcriber_lambda_name
  handler          = "handler.handler"
  runtime          = "python3.10"
  role             = var.lambda_exec_role_arn
  filename         = "${path.module}/build/transcriber_lambda.zip"
  source_code_hash = fileexists("${path.module}/build/transcriber_lambda.zip") ? filebase64sha256("${path.module}/build/transcriber_lambda.zip") : null

  memory_size = 3072
  timeout     = var.transcriber_lambda_timeout

  ephemeral_storage {
    size = 10240
  }

  environment {
    variables = {
      MSK_CLUSTER_ARN = var.msk_cluster_arn
    }
  }

  vpc_config {
    subnet_ids         = [var.private_subnet_a_id, var.private_subnet_b_id]
    security_group_ids = [var.lambda_msk_sg_id]
  }
}

resource "aws_lambda_function" "msk_lambda" {
  function_name    = var.msk_lambda_name
  handler          = "handler.handler"
  runtime          = "python3.10"
  role             = var.lambda_exec_role_arn
  filename         = "${path.module}/build/msk_lambda.zip"
  source_code_hash = fileexists("${path.module}/build/msk_lambda.zip") ? filebase64sha256("${path.module}/build/msk_lambda.zip") : null

  memory_size = 1024
  timeout     = var.msk_lambda_timeout

  vpc_config {
    subnet_ids         = [var.private_subnet_a_id, var.private_subnet_b_id]
    security_group_ids = [var.lambda_msk_sg_id]
  }
}
