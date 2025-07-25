# resource "aws_lambda_function" "summarizer_lambda" {
#   function_name    = var.summarizer_lambda_name
#   handler          = "handler.handler"
#   runtime          = "python3.10"
#   role             = var.lambda_exec_role_arn
#   filename         = "${path.module}/build/summarizer_lambda.zip"
#   source_code_hash = fileexists("${path.module}/build/summarizer_lambda.zip") ? filebase64sha256("${path.module}/build/summarizer_lambda.zip") : null

#   memory_size = 1024
#   timeout     = var.summarizer_lambda_timeout

#   environment {
#     variables = {
#       MSK_BROKERS = var.msk_bootstrap_brokers
#       OPENAI_API_KEY  = var.openai_api_key
#     }
#   }

#   vpc_config {
#     subnet_ids         = [var.private_subnet_a_id, var.private_subnet_b_id]
#     security_group_ids = [var.lambda_msk_sg_id]
#   }
# }

# resource "aws_lambda_function" "transcriber_lambda" {
#   function_name    = var.transcriber_lambda_name
#   role             = var.lambda_exec_role_arn
#   package_type  = "Image"
#   image_uri     = "058264550947.dkr.ecr.ap-southeast-2.amazonaws.com/mediscribe/transcriber:latest"

#   image_config {
#     command     = ["handler.handler"]
#   }

#   memory_size = 3000
#   timeout     = var.transcriber_lambda_timeout

#   ephemeral_storage {
#     size = 10240
#   }

#   environment {
#     variables = {
#       MSK_BROKERS = var.msk_bootstrap_brokers
#     }
#   }

#   vpc_config {
#     subnet_ids         = [var.private_subnet_a_id, var.private_subnet_b_id]
#     security_group_ids = [var.lambda_msk_sg_id]
#   }
# }

resource "aws_lambda_function" "msk_lambda" {
  function_name    = var.msk_lambda_name
  handler          = "handler.handler"
  runtime          = "python3.10"
  role             = var.lambda_exec_role_arn
  filename         = "${path.module}/build/msk_lambda.zip"
  source_code_hash = fileexists("${path.module}/build/msk_lambda.zip") ? filebase64sha256("${path.module}/build/msk_lambda.zip") : null

  memory_size = 1024
  timeout     = var.msk_lambda_timeout

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


# Triggers 
# resource "aws_lambda_event_source_mapping" "transcriber_lambda_trigger" {
#   event_source_arn = var.msk_cluster_arn
#   function_name    = aws_lambda_function.transcriber_lambda.arn

#   starting_position = "LATEST" 
#   topics            = ["audio.send"]
#   batch_size        = 100
# }

# resource "aws_lambda_event_source_mapping" "summarizer_lambda_trigger" {
#   event_source_arn = var.msk_cluster_arn
#   function_name    = aws_lambda_function.summarizer_lambda.arn

#   starting_position = "LATEST" 
#   topics            = ["transcription.data"]
#   batch_size        = 100
# }

# resource "aws_cloudwatch_log_group" "summarizer_logs" {
#   name              = "/aws/lambda/${aws_lambda_function.summarizer_lambda.function_name}"
#   retention_in_days = 14
# }

# resource "aws_cloudwatch_log_group" "transcriber_logs" {
#   name              = "/aws/lambda/${aws_lambda_function.transcriber_lambda.function_name}"
#   retention_in_days = 14
# }
