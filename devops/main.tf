
terraform {

  backend "s3" {
    bucket         = "mediscribe-terraform"
    key            = "terraform/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "mediscribe-terraform-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

######################
# Locals and Settings
######################

locals {
  app_name = var.project_name

  backend_domain = "api.${var.project_name}.quangtechnologies.com"
  app_buckets = {
    frontend = {
      name            = "frontend"
      domain          = "${var.project_name}.quangtechnologies.com"
      origin_id       = "${var.project_name}frontendS3Origin"
      oac_name        = "frontend-oac"
      oac_description = "OAC for Frontend"
    }

  }
  logs_buckets = {
    alb = {
      name = "alb-logs"
    }
  }

  lambdas = {
    msk_topic_creator = {
      name    = "msk_topic_creator"
      timeout = 60 # 1 minute
    }
  }
}

module "s3" {
  source = "./modules/storage/s3"

  project_name = var.project_name
  app_buckets  = local.app_buckets
  logs_buckets = local.logs_buckets
  region_id    = var.region_id
}

module "networking" {
  source = "./modules/networking"

  project_name          = var.project_name
  vpc_id                = var.vpc_id
  az_a                  = var.aza
  az_b                  = var.azb
  public_route_table_id = var.public_route_table_id
}

module "security_groups" {
  source = "./modules/security/security_groups"

  project_name = var.project_name
  vpc_id       = var.vpc_id
}

module "msk" {
  source = "./modules/messaging/msk"

  project_name        = var.project_name
  private_subnet_a_id = module.networking.private_subnet_a_id
  private_subnet_b_id = module.networking.private_subnet_b_id
  msk_sg_id           = module.security_groups.msk_sg_id
}

module "iam" {
  source = "./modules/security/iam"

  project_name    = var.project_name
  msk_cluster_arn = module.msk.msk_cluster_arn
}

module "logs" {
  source = "./modules/logs"

  project_name = var.project_name
}

module "cdn" {
  source = "./modules/cdn"

  project_name                     = var.project_name
  hosted_zone_id                   = var.hosted_zone_id
  app_buckets                      = local.app_buckets
  app_bucket_regional_domain_names = module.s3.app_bucket_regional_domain_names
  cloudfront_acm_certificate_arn   = var.acm_certificate_arn
}

module "alb" {
  source = "./modules/load_balancing/alb"

  project_name       = var.project_name
  public_subnet_a_id = module.networking.public_subnet_a_id
  public_subnet_b_id = module.networking.public_subnet_b_id
  vpc_id             = var.vpc_id
  hosted_zone_id     = var.hosted_zone_id
  alb_sg_id          = module.security_groups.alb_sg_id
  alb_logs_bucket    = module.s3.alb_logs_bucket
  backend_domain     = local.backend_domain
}

module "route53" {
  source = "./modules/load_balancing/route53"

  project_name   = var.project_name
  hosted_zone_id = var.hosted_zone_id
  app_buckets    = local.app_buckets
  cdn_domains    = module.cdn.cdn_domains
  alb_dns_name   = module.alb.alb_dns_name
  alb_zone_id    = module.alb.alb_zone_id
  backend_domain = local.backend_domain

  depends_on = [module.cdn, module.alb]
}

module "ecs" {
  source = "./modules/compute/ecs"

  project_name = var.project_name
  aws_region   = var.aws_region

  public_subnet_a_id  = module.networking.public_subnet_a_id
  private_subnet_a_id = module.networking.private_subnet_a_id
  private_subnet_b_id = module.networking.private_subnet_b_id

  backend_sg_id                 = module.security_groups.backend_sg_id
  service_sg_id                 = module.security_groups.service_sg_id
  backend_instance_profile_name = module.iam.backend_instance_profile_name
  backend_task_exec_role_arn    = module.iam.backend_task_exec_role_arn
  service_execution_role_arn    = module.iam.service_execution_role_arn
  service_task_exec_role_arn    = module.iam.service_task_exec_role_arn
  backend_image_url             = var.backend_image_url
  transcriber_image_url         = var.transcriber_image_url
  summarizer_image_url          = var.summarizer_image_url
  backend_logs_group_name       = module.logs.backend_logs_group_name
  transcriber_logs_group_name   = module.logs.transcriber_logs_group_name
  summarizer_logs_group_name    = module.logs.summarizer_logs_group_name
  alb_target_group_arn          = module.alb.alb_target_group_arn
  frontend_url                  = "https://${local.app_buckets.frontend.domain}"
  msk_bootstrap_brokers         = module.msk.msk_bootstrap_brokers
  openai_api_key                = var.openai_api_key

  depends_on = [module.topics]
}

module "lambda" {
  source = "./modules/compute/lambda"

  project_name                     = var.project_name
  private_subnet_a_id              = module.networking.private_subnet_a_id
  private_subnet_b_id              = module.networking.private_subnet_b_id
  msk_topic_creator_lambda_name    = local.lambdas.msk_topic_creator.name
  msk_topic_creator_lambda_timeout = local.lambdas.msk_topic_creator.timeout
  lambda_msk_sg_id                 = module.security_groups.lambda_msk_sg_id
  lambda_exec_role_arn             = module.iam.lambda_exec_role_arn
  msk_bootstrap_brokers            = module.msk.msk_bootstrap_brokers
}

module "topics" {
  source = "./modules/messaging/topics"

  msk_topic_creator_function_name = module.lambda.msk_topic_creator_function_name

  depends_on = [module.msk, module.lambda]
}

module "auto_scaling" {
  source = "./modules/auto_scaling"

  project_name             = var.project_name
  backend_ecs_cluster_name = module.ecs.backend_ecs_cluster_name
  backend_ecs_service_name = module.ecs.backend_ecs_service_name

  depends_on = [module.ecs]
}
