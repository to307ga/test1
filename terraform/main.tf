# AWS SES Migration Infrastructure - Terraform Configuration
# Version: 1.0
# Description: Main configuration for AWS SES migration

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# Provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_code
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  common_tags = {
    Project     = var.project_code
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
  
  name_prefix = "${var.project_code}-${var.environment}"
}

# Random password for initial user passwords
resource "random_password" "initial_password" {
  length  = 16
  special = true
}

# Modules
module "base_infrastructure" {
  source = "./modules/base"
  
  project_code      = var.project_code
  environment       = var.environment
  domain_name       = var.domain_name
  allowed_ip_ranges = var.allowed_ip_ranges
  retention_days    = var.retention_days
  
  tags = local.common_tags
}

module "ses_configuration" {
  source = "./modules/ses"
  
  project_code      = var.project_code
  environment       = var.environment
  domain_name       = var.domain_name
  allowed_ip_ranges = var.allowed_ip_ranges
  
  # Dependencies from base infrastructure
  log_bucket_name         = module.base_infrastructure.log_bucket_name
  notification_topic_arn  = module.base_infrastructure.notification_topic_arn
  
  tags = local.common_tags
  
  depends_on = [module.base_infrastructure]
}

module "monitoring" {
  source = "./modules/monitoring"
  
  project_code     = var.project_code
  environment      = var.environment
  domain_name      = var.domain_name
  retention_days   = var.retention_days
  
  # Dependencies
  notification_topic_arn = module.base_infrastructure.notification_topic_arn
  ses_log_group_name     = module.ses_configuration.ses_log_group_name
  
  tags = local.common_tags
  
  depends_on = [
    module.base_infrastructure,
    module.ses_configuration
  ]
}

module "security" {
  source = "./modules/security"
  
  project_code      = var.project_code
  environment       = var.environment
  domain_name       = var.domain_name
  allowed_ip_ranges = var.allowed_ip_ranges
  initial_password  = random_password.initial_password.result
  
  # Dependencies
  log_bucket_name = module.base_infrastructure.log_bucket_name
  
  tags = local.common_tags
  
  depends_on = [module.base_infrastructure]
}

# Outputs
output "ses_domain_identity" {
  description = "SES Domain Identity"
  value       = module.ses_configuration.domain_identity
}

output "ses_dkim_tokens" {
  description = "DKIM tokens for DNS configuration"
  value       = module.ses_configuration.dkim_tokens
  sensitive   = true
}

output "smtp_credentials_secret_arn" {
  description = "ARN of the SMTP credentials secret in Secrets Manager"
  value       = module.security.smtp_credentials_secret_arn
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${local.region}.console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${module.ses_configuration.dashboard_name}"
}

output "log_bucket_name" {
  description = "Name of the S3 bucket for logs"
  value       = module.base_infrastructure.log_bucket_name
}

output "notification_topic_arn" {
  description = "ARN of the SNS topic for notifications"
  value       = module.base_infrastructure.notification_topic_arn
}

output "admin_user_name" {
  description = "Name of the admin user"
  value       = module.security.admin_user_name
}

output "readonly_user_name" {
  description = "Name of the readonly user"
  value       = module.security.readonly_user_name
}

output "monitoring_user_name" {
  description = "Name of the monitoring user"
  value       = module.security.monitoring_user_name
}
