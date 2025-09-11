# Variables for SES Configuration Module

variable "project_code" {
  description = "Project code for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Domain name for SES configuration"
  type        = string
}

variable "allowed_ip_ranges" {
  description = "List of allowed IP address ranges for access control"
  type        = list(string)
}

variable "log_bucket_name" {
  description = "Name of the S3 bucket for logs"
  type        = string
}

variable "notification_topic_arn" {
  description = "ARN of the SNS topic for notifications"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
