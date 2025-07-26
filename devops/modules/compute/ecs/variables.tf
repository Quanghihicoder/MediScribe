variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "aws_region" {
  type = string
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

variable "private_subnet_a_id" {
  description = "ID of the private subnet A"
  type        = string
}

variable "private_subnet_b_id" {
  description = "ID of the private subnet B"
  type        = string
}

variable "backend_sg_id" {
  type        = string
}

variable "service_sg_id" {
  type        = string
}

variable "backend_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  type        = string
}

variable "backend_task_exec_role_arn" {
  type        = string
}

variable service_execution_role_arn {
  type        = string
}

variable "service_task_exec_role_arn" {
  type        = string
}

variable "backend_image_url" {
  description = "ECS image URL"
  type        = string
}

variable "transcriber_image_url" {
  description = "ECS image URL"
  type        = string
}

variable "summarizer_image_url" {
  description = "ECS image URL"
  type        = string
}

variable "backend_logs_group_name" {
  description = "Log group name of the ecs task"
  type        = string
}

variable "transcriber_logs_group_name" {
  description = "Log group name of the ecs task"
  type        = string
}

variable "summarizer_logs_group_name" {
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

variable "openai_api_key" {
  type = string
}
