variable "lambda_exec_role_arn" {
  description = "ARN of lambda execution role"
  type        = string
}

variable "summarizer_lambda_name" {
  type = string
}

variable "transcriber_lambda_name" {
  type = string
}

variable "msk_lambda_name" {
  type = string
}

variable "summarizer_lambda_timeout" {
  type = number
}

variable "transcriber_lambda_timeout" {
  type = number
}

variable "msk_lambda_timeout" {
  type = number
}

variable "private_subnet_a_id" {
  description = "ID of the private subnet A"
  type        = string
}

variable "private_subnet_b_id" {
  description = "ID of the private subnet B"
  type        = string
}

variable "lambda_msk_sg_id" {
  description = "ID of the Lambda MSK security group"
  type        = string
}

variable "aws_region" {
  type = string
}

variable "msk_cluster_arn" {
  type        = string
}

variable "msk_bootstrap_brokers" {
  description = "Comma-separated list of MSK bootstrap brokers"
  type        = string
}

variable "openai_api_key" {
  type = string
}
