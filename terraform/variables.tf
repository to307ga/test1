# Variables for AWS SES Migration Infrastructure

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition = contains([
      "us-east-1", "us-west-1", "us-west-2", "eu-west-1", 
      "eu-west-2", "eu-central-1", "ap-southeast-1", 
      "ap-southeast-2", "ap-northeast-1"
    ], var.aws_region)
    error_message = "AWS region must be a valid SES-supported region."
  }
}

variable "project_code" {
  description = "Project code for resource naming"
  type        = string
  default     = "ses-migration"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project_code))
    error_message = "Project code must start with a letter, contain only lowercase letters, numbers, and hyphens, and end with a letter or number."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
  
  validation {
    condition = contains([
      "development", "dev", "staging", "stage", "production", "prod"
    ], var.environment)
    error_message = "Environment must be one of: development, dev, staging, stage, production, prod."
  }
}

variable "domain_name" {
  description = "Domain name for SES configuration"
  type        = string
  default     = "goo.ne.jp"
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]\\.[a-z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid domain format."
  }
}

variable "allowed_ip_ranges" {
  description = "List of allowed IP address ranges for access control"
  type        = list(string)
  default     = ["10.0.0.0/8", "192.168.1.0/24"]
  
  validation {
    condition = alltrue([
      for ip in var.allowed_ip_ranges : can(cidrhost(ip, 0))
    ])
    error_message = "All IP ranges must be valid CIDR notation."
  }
}

variable "retention_days" {
  description = "Log retention period in days (7 years = 2555 days)"
  type        = number
  default     = 2555
  
  validation {
    condition     = var.retention_days > 0 && var.retention_days <= 3653
    error_message = "Retention days must be between 1 and 3653 (10 years)."
  }
}

variable "enable_dkim" {
  description = "Enable DKIM signing for the domain"
  type        = bool
  default     = true
}

variable "enable_feedback_forwarding" {
  description = "Enable feedback forwarding for bounces and complaints"
  type        = bool
  default     = true
}

variable "daily_sending_quota" {
  description = "Maximum number of emails that can be sent in a 24-hour period"
  type        = number
  default     = 5300000
  
  validation {
    condition     = var.daily_sending_quota > 0
    error_message = "Daily sending quota must be greater than 0."
  }
}

variable "max_send_rate" {
  description = "Maximum number of emails that can be sent per second"
  type        = number
  default     = 50
  
  validation {
    condition     = var.max_send_rate > 0
    error_message = "Max send rate must be greater than 0."
  }
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for audit logging"
  type        = bool
  default     = true
}

variable "enable_config" {
  description = "Enable AWS Config for compliance monitoring"
  type        = bool
  default     = true
}

variable "enable_multi_region_trail" {
  description = "Enable multi-region CloudTrail"
  type        = bool
  default     = true
}

variable "sns_email_endpoints" {
  description = "List of email addresses for SNS notifications"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for email in var.sns_email_endpoints : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All email addresses must be valid email format."
  }
}

variable "sns_sms_endpoints" {
  description = "List of phone numbers for SNS SMS notifications"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for phone in var.sns_sms_endpoints : can(regex("^\\+[1-9]\\d{1,14}$", phone))
    ])
    error_message = "All phone numbers must be valid international format (e.g., +81901234567)."
  }
}

variable "alarm_evaluation_periods" {
  description = "Number of evaluation periods for CloudWatch alarms"
  type        = number
  default     = 2
  
  validation {
    condition     = var.alarm_evaluation_periods >= 1 && var.alarm_evaluation_periods <= 10
    error_message = "Alarm evaluation periods must be between 1 and 10."
  }
}

variable "alarm_period" {
  description = "Period in seconds for CloudWatch alarms"
  type        = number
  default     = 300
  
  validation {
    condition = contains([60, 300, 900, 3600, 21600, 86400], var.alarm_period)
    error_message = "Alarm period must be one of: 60, 300, 900, 3600, 21600, or 86400 seconds."
  }
}

variable "bounce_rate_threshold" {
  description = "Bounce rate threshold percentage for alarms"
  type        = number
  default     = 5.0
  
  validation {
    condition     = var.bounce_rate_threshold >= 0 && var.bounce_rate_threshold <= 100
    error_message = "Bounce rate threshold must be between 0 and 100."
  }
}

variable "complaint_rate_threshold" {
  description = "Complaint rate threshold percentage for alarms"
  type        = number
  default     = 0.1
  
  validation {
    condition     = var.complaint_rate_threshold >= 0 && var.complaint_rate_threshold <= 100
    error_message = "Complaint rate threshold must be between 0 and 100."
  }
}

variable "send_success_rate_threshold" {
  description = "Send success rate threshold percentage for alarms"
  type        = number
  default     = 95.0
  
  validation {
    condition     = var.send_success_rate_threshold >= 0 && var.send_success_rate_threshold <= 100
    error_message = "Send success rate threshold must be between 0 and 100."
  }
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring with custom metrics"
  type        = bool
  default     = true
}

variable "custom_metrics_schedule" {
  description = "Schedule expression for custom metrics collection (CloudWatch Events)"
  type        = string
  default     = "rate(5 minutes)"
  
  validation {
    condition = can(regex("^(rate\\([0-9]+ (minute|minutes|hour|hours|day|days)\\)|cron\\(.+\\))$", var.custom_metrics_schedule))
    error_message = "Custom metrics schedule must be a valid CloudWatch Events schedule expression."
  }
}

variable "s3_lifecycle_transition_days" {
  description = "Configuration for S3 lifecycle transitions"
  type = object({
    standard_ia  = number
    glacier      = number
    deep_archive = number
  })
  default = {
    standard_ia  = 30
    glacier      = 90
    deep_archive = 365
  }
  
  validation {
    condition = (
      var.s3_lifecycle_transition_days.standard_ia > 0 &&
      var.s3_lifecycle_transition_days.glacier > var.s3_lifecycle_transition_days.standard_ia &&
      var.s3_lifecycle_transition_days.deep_archive > var.s3_lifecycle_transition_days.glacier
    )
    error_message = "S3 lifecycle transition days must be in ascending order: standard_ia < glacier < deep_archive."
  }
}

variable "enable_versioning" {
  description = "Enable versioning for S3 buckets"
  type        = bool
  default     = true
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete for S3 buckets (requires versioning)"
  type        = bool
  default     = false
}

variable "kms_key_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
  
  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days."
  }
}

variable "enable_kms_encryption" {
  description = "Enable KMS encryption for supported resources"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
