# Outputs for Monitoring Module

output "application_log_group_name" {
  description = "CloudWatch Log Group for Application Logs"
  value       = aws_cloudwatch_log_group.application.name
}

output "custom_metrics_function_arn" {
  description = "ARN of the Custom Metrics Lambda Function"
  value       = aws_lambda_function.custom_metrics.arn
}

output "composite_alarm_name" {
  description = "Name of the Composite Alarm"
  value       = aws_cloudwatch_composite_alarm.ses_composite.alarm_name
}

output "data_masking_function_arn" {
  description = "ARN of the Data Masking Lambda Function"
  value       = aws_lambda_function.data_masking.arn
}

output "admin_query_definition_name" {
  description = "Name of the Admin CloudWatch Insights Query"
  value       = aws_cloudwatch_query_definition.ses_analysis_admin.name
}

output "masked_query_definition_name" {
  description = "Name of the Masked CloudWatch Insights Query"
  value       = aws_cloudwatch_query_definition.ses_analysis_masked.name
}

output "ses_send_failure_alarm_name" {
  description = "Name of the SES Send Failure Alarm"
  value       = aws_cloudwatch_metric_alarm.ses_send_failure.alarm_name
}

output "ses_bounce_rate_alarm_name" {
  description = "Name of the SES Bounce Rate Alarm"
  value       = aws_cloudwatch_metric_alarm.ses_bounce_rate.alarm_name
}

output "ses_complaint_rate_alarm_name" {
  description = "Name of the SES Complaint Rate Alarm"
  value       = aws_cloudwatch_metric_alarm.ses_complaint_rate.alarm_name
}
