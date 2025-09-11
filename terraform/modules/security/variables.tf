# Variables for Security Module

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

variable "initial_password" {
  description = "Initial password for IAM users"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
