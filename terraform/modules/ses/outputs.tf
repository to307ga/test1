# Outputs for SES Configuration Module

output "domain_identity" {
  description = "SES Domain Identity"
  value       = aws_ses_domain_identity.main.domain
}

output "dkim_tokens" {
  description = "DKIM tokens for DNS configuration"
  value       = aws_ses_domain_dkim.main.dkim_tokens
  sensitive   = true
}

output "mail_from_domain" {
  description = "Mail from domain"
  value       = aws_ses_domain_mail_from.main.mail_from_domain
}

output "ses_log_group_name" {
  description = "Name of the CloudWatch Log Group for SES"
  value       = aws_cloudwatch_log_group.ses.name
}

output "ses_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for SES"
  value       = aws_cloudwatch_log_group.ses.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch Dashboard"
  value       = aws_cloudwatch_dashboard.ses.dashboard_name
}

output "configuration_set_name" {
  description = "Name of the SES Configuration Set"
  value       = aws_ses_configuration_set.main.name
}
