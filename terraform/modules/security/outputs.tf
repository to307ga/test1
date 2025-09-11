# Outputs for Security Module

output "admin_group_arn" {
  description = "ARN of the Admin IAM Group"
  value       = aws_iam_group.admin.arn
}

output "readonly_group_arn" {
  description = "ARN of the ReadOnly IAM Group"
  value       = aws_iam_group.readonly.arn
}

output "monitoring_group_arn" {
  description = "ARN of the Monitoring IAM Group"
  value       = aws_iam_group.monitoring.arn
}

output "smtp_credentials_secret_arn" {
  description = "ARN of the SMTP Credentials Secret"
  value       = aws_secretsmanager_secret.smtp_credentials.arn
}

output "instance_profile_arn" {
  description = "ARN of the Instance Profile for EC2"
  value       = aws_iam_instance_profile.instance.arn
}

output "admin_user_name" {
  description = "Name of the admin user"
  value       = aws_iam_user.admin.name
}

output "readonly_user_name" {
  description = "Name of the readonly user"
  value       = aws_iam_user.readonly.name
}

output "monitoring_user_name" {
  description = "Name of the monitoring user"
  value       = aws_iam_user.monitoring.name
}

output "admin_access_key_id" {
  description = "Access Key ID for admin user"
  value       = aws_iam_access_key.admin.id
  sensitive   = true
}

output "admin_secret_access_key" {
  description = "Secret Access Key for admin user"
  value       = aws_iam_access_key.admin.secret
  sensitive   = true
}
