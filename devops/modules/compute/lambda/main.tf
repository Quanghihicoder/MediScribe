resource "aws_lambda_function" "msk_topic_creator_lambda" {
  function_name    = "${var.project_name}-${var.msk_topic_creator_lambda_name}"
  handler          = "handler.handler"
  runtime          = "python3.10"
  role             = var.lambda_exec_role_arn
  filename         = "${path.module}/build/msk_topic_creator_lambda.zip"
  source_code_hash = fileexists("${path.module}/build/msk_topic_creator_lambda.zip") ? filebase64sha256("${path.module}/build/msk_topic_creator_lambda.zip") : null

  memory_size = 1024
  timeout     = var.msk_topic_creator_lambda_timeout

  environment {
    variables = {
      MSK_BROKERS = var.msk_bootstrap_brokers
    }
  }

  vpc_config {
    subnet_ids         = [var.private_subnet_a_id, var.private_subnet_b_id]
    security_group_ids = [var.lambda_msk_sg_id]
  }
}