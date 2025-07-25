variable "app_name" {
  description = "The app name"
  type        = string
  default     = "tilelens"
}

variable "instance_type" {
  description = "The instance type of the EC2 instance running the ECS container"
  type        = string
  default     = "t3.micro"
}

variable "public_subnet_a_id" {
  description = "ID of the public subnet A"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  type        = string
}

variable "ecs_sg_id" {
  description = "ID of the ECS security group"
  type        = string
}

variable "ecs_task_exec_role_arn" {
  description = "ARN of the ECS take execution"
  type        = string
}

variable "ecs_image_url" {
  description = "ECS image URL"
  type        = string
}

variable "aws_region" {
  type = string
}

variable "ecs_logs_group_name" {
  description = "Log group name of the ecs task"
  type        = string
}

variable "frontend_url" {
  description = "URL of the frontend"
  type        = string
}

variable "alb_target_group_arn" {
  description = "aws_lb_target_group.tilelens_tg.arn"
  type        = string
}

variable "msk_bootstrap_brokers" {
  description = "Comma-separated list of MSK bootstrap brokers"
  type        = string
}


variable "private_subnet_a_id" {
  description = "ID of the private subnet A"
  type        = string
}

variable "private_subnet_b_id" {
  description = "ID of the private subnet B"
  type        = string
}

variable "openai_api_key" {
  type = string
}
