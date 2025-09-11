# Variables for Monitoring Module

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

variable "retention_days" {
  description = "Log retention period in days"
  type        = number
}

variable "notification_topic_arn" {
  description = "ARN of the SNS topic for notifications"
  type        = string
}

variable "ses_log_group_name" {
  description = "Name of the CloudWatch Log Group for SES"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
