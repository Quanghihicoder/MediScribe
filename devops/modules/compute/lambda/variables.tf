variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "lambda_exec_role_arn" {
  description = "ARN of lambda execution role"
  type        = string
}

variable "msk_topic_creator_lambda_name" {
  type = string
}

variable "msk_topic_creator_lambda_timeout" {
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

variable "msk_bootstrap_brokers" {
  description = "Comma-separated list of MSK bootstrap brokers"
  type        = string
}
