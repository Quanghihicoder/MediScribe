
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
  app_name = "mediscribe"

  backend_domain = "api.mediscribe.quangtechnologies.com"
  app_buckets = {
    frontend = {
      name            = "mediscribe-frontend"
      domain          = "mediscribe.quangtechnologies.com"
      origin_id       = "mediscribefrontendS3Origin"
      oac_name        = "mediscribe-frontend-oac"
      oac_description = "OAC for MediScribe Frontend"
    }

  }
  logs_buckets = {
    alb = {
      name = "mediscribe-alb-logs"
    }
  }

  lambdas = {
    summarizer = {
      name    = "summarizer"
      timeout = 60 # 1 minute
    }
    transcriber = {
      name    = "transcriber"
      timeout = 60 # 1 minute
    }
    msk = {
      name    = "msk"
      timeout = 60 # 1 minute
    }
  }
}

module "s3" {
  source = "./modules/storage/s3"

  app_buckets  = local.app_buckets
  logs_buckets = local.logs_buckets
  region_id    = var.region_id
}

module "networking" {
  source = "./modules/networking"

  vpc_id                = var.vpc_id
  az_a                  = var.aza
  az_b                  = var.azb
  public_route_table_id = var.public_route_table_id
}

module "security_groups" {
  source = "./modules/security/security_groups"

  vpc_id = var.vpc_id
}

module "msk" {
  source = "./modules/messaging/msk"

  private_subnet_a_id = module.networking.private_subnet_a_id
  private_subnet_b_id = module.networking.private_subnet_b_id
  msk_sg_id           = module.security_groups.msk_sg_id
}

module "iam" {
  source = "./modules/security/iam"

  msk_cluster_arn = module.msk.msk_cluster_arn
}

module "logs" {
  source = "./modules/logs"
}

module "cdn" {
  source = "./modules/cdn"

  hosted_zone_id                   = var.hosted_zone_id
  app_buckets                      = local.app_buckets
  app_bucket_regional_domain_names = module.s3.app_bucket_regional_domain_names
  cloudfront_acm_certificate_arn   = var.acm_certificate_arn
}

module "alb" {
  source = "./modules/load_balancing/alb"

  public_subnet_a_id = module.networking.public_subnet_a_id
  public_subnet_b_id = module.networking.public_subnet_b_id
  vpc_id             = var.vpc_id
  hosted_zone_id     = var.hosted_zone_id
  alb_sg_id          = module.security_groups.alb_sg_id
  alb_logs_bucket    = local.logs_buckets.alb.name
  backend_domain     = local.backend_domain
}

module "route53" {
  source = "./modules/load_balancing/route53"

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

  public_subnet_a_id        = module.networking.public_subnet_a_id
  ecs_task_exec_role_arn    = module.iam.ecs_task_exec_role_arn
  ecs_sg_id                 = module.security_groups.ecs_sg_id
  ecs_logs_group_name       = module.logs.ecs_logs_group_name
  ecs_image_url             = var.ecs_image_url
  iam_instance_profile_name = module.iam.iam_instance_profile_name
  alb_target_group_arn      = module.alb.alb_target_group_arn
  app_name                  = local.app_name
  aws_region                = var.aws_region
  frontend_url              = "https://${local.app_buckets.frontend.domain}"
  msk_bootstrap_brokers_tls = module.msk.msk_bootstrap_brokers_tls
}

module "lambda" {
  source = "./modules/compute/lambda"

  private_subnet_a_id        = module.networking.private_subnet_a_id
  private_subnet_b_id        = module.networking.private_subnet_b_id
  summarizer_lambda_name     = local.lambdas.summarizer.name
  summarizer_lambda_timeout  = local.lambdas.summarizer.timeout
  transcriber_lambda_name    = local.lambdas.transcriber.name
  transcriber_lambda_timeout = local.lambdas.transcriber.timeout
  msk_lambda_name            = local.lambdas.msk.name
  msk_lambda_timeout         = local.lambdas.msk.timeout
  lambda_msk_sg_id           = module.security_groups.lambda_msk_sg_id
  lambda_exec_role_arn       = module.iam.lambda_exec_role_arn
  aws_region                 = var.aws_region
  msk_cluster_arn            = module.msk.msk_cluster_arn
  openai_api_key             = var.openai_api_key
}

module "topics" {
  source = "./modules/messaging/topics"

  msk_cluster_arn   = module.msk.msk_cluster_arn
  msk_function_name = module.lambda.msk_function_name

  depends_on = [module.msk, module.lambda]
}

module "auto_scaling" {
  source = "./modules/auto_scaling"

  ecs_cluster_name = module.ecs.ecs_cluster_name
  ecs_service_name = module.ecs.ecs_service_name

  depends_on = [module.ecs]
}
