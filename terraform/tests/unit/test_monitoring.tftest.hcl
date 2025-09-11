# UNIT TEST: Monitoring Module
# Tests for CloudWatch Insights, Lambda Functions, Alarms, and Data Masking

variables {
  project_code = "ses-migration"
  environment  = "production"
  domain_name  = "goo.ne.jp"
  retention_days = 2555
  notification_topic_arn = "arn:aws:sns:us-east-1:123456789012:ses-migration-production-notifications"
  ses_log_group_name = "/aws/ses/ses-migration/production"
  tags = {
    Project     = "ses-migration"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

run "test_cloudwatch_alarms_ses" {
  command = plan

  # Test SES Send Failure Alarm
  assert {
    condition     = aws_cloudwatch_metric_alarm.ses_send_failure.alarm_name == "ses-migration-production-ses-send-failure"
    error_message = "SES send failure alarm name should match expected pattern"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.ses_send_failure.alarm_description == "SES Send Success Rate is below 95%"
    error_message = "SES send failure alarm should have correct description"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.ses_send_failure.comparison_operator == "LessThanThreshold"
    error_message = "SES send failure alarm should use LessThanThreshold comparison"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.ses_send_failure.threshold == 95
    error_message = "SES send failure alarm should have 95% threshold"
  }

  # Test SES Bounce Rate Alarm
  assert {
    condition     = aws_cloudwatch_metric_alarm.ses_bounce_rate.alarm_name == "ses-migration-production-ses-bounce-rate"
    error_message = "SES bounce rate alarm name should match expected pattern"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.ses_bounce_rate.comparison_operator == "GreaterThanThreshold"
    error_message = "SES bounce rate alarm should use GreaterThanThreshold comparison"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.ses_bounce_rate.threshold == 5
    error_message = "SES bounce rate alarm should have 5% threshold"
  }

  # Test SES Complaint Rate Alarm
  assert {
    condition     = aws_cloudwatch_metric_alarm.ses_complaint_rate.alarm_name == "ses-migration-production-ses-complaint-rate"
    error_message = "SES complaint rate alarm name should match expected pattern"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.ses_complaint_rate.threshold == 0.1
    error_message = "SES complaint rate alarm should have 0.1% threshold"
  }
}

run "test_cloudwatch_composite_alarm" {
  command = plan

  assert {
    condition     = aws_cloudwatch_composite_alarm.ses_composite.alarm_name == "ses-migration-production-ses-composite"
    error_message = "Composite alarm name should match expected pattern"
  }

  assert {
    condition     = aws_cloudwatch_composite_alarm.ses_composite.alarm_description == "Composite alarm for SES health"
    error_message = "Composite alarm should have correct description"
  }

  # Test that composite alarm includes all individual alarms
  assert {
    condition     = can(regex("ses-migration-production-ses-send-failure", aws_cloudwatch_composite_alarm.ses_composite.alarm_rule))
    error_message = "Composite alarm should include SES send failure alarm"
  }

  assert {
    condition     = can(regex("ses-migration-production-ses-bounce-rate", aws_cloudwatch_composite_alarm.ses_composite.alarm_rule))
    error_message = "Composite alarm should include SES bounce rate alarm"
  }

  assert {
    condition     = can(regex("ses-migration-production-ses-complaint-rate", aws_cloudwatch_composite_alarm.ses_composite.alarm_rule))
    error_message = "Composite alarm should include SES complaint rate alarm"
  }
}

run "test_cloudwatch_insights_queries" {
  command = plan

  # Test Admin Query Definition
  assert {
    condition     = aws_cloudwatch_query_definition.ses_analysis_admin.name == "ses-migration-production-ses-analysis-admin"
    error_message = "Admin query definition name should match expected pattern"
  }

  assert {
    condition     = aws_cloudwatch_query_definition.ses_analysis_admin.log_group_names[0] == "/aws/ses/ses-migration/production"
    error_message = "Admin query should use the correct SES log group"
  }

  # Test Masked Query Definition
  assert {
    condition     = aws_cloudwatch_query_definition.ses_analysis_masked.name == "ses-migration-production-ses-analysis-masked"
    error_message = "Masked query definition name should match expected pattern"
  }

  assert {
    condition     = aws_cloudwatch_query_definition.ses_analysis_masked.log_group_names[0] == "/aws/ses/ses-migration/production"
    error_message = "Masked query should use the correct SES log group"
  }

  # Test that masked query contains masking logic
  assert {
    condition     = can(regex("maskedDestination", aws_cloudwatch_query_definition.ses_analysis_masked.query_string))
    error_message = "Masked query should include maskedDestination field"
  }

  assert {
    condition     = can(regex("maskedSourceIp", aws_cloudwatch_query_definition.ses_analysis_masked.query_string))
    error_message = "Masked query should include maskedSourceIp field"
  }

  # Test that admin query shows unmasked data
  assert {
    condition     = can(regex("destination", aws_cloudwatch_query_definition.ses_analysis_admin.query_string))
    error_message = "Admin query should include unmasked destination field"
  }

  assert {
    condition     = can(regex("sourceIp", aws_cloudwatch_query_definition.ses_analysis_admin.query_string))
    error_message = "Admin query should include unmasked sourceIp field"
  }
}

run "test_lambda_functions" {
  command = plan

  # Test Custom Metrics Lambda
  assert {
    condition     = aws_lambda_function.custom_metrics.function_name == "ses-migration-production-custom-metrics"
    error_message = "Custom metrics Lambda function name should match expected pattern"
  }

  assert {
    condition     = aws_lambda_function.custom_metrics.runtime == "python3.9"
    error_message = "Custom metrics Lambda should use Python 3.9 runtime"
  }

  assert {
    condition     = aws_lambda_function.custom_metrics.timeout == 60
    error_message = "Custom metrics Lambda should have 60 second timeout"
  }

  # Test Data Masking Lambda
  assert {
    condition     = aws_lambda_function.data_masking.function_name == "ses-migration-production-data-masking"
    error_message = "Data masking Lambda function name should match expected pattern"
  }

  assert {
    condition     = aws_lambda_function.data_masking.runtime == "python3.9"
    error_message = "Data masking Lambda should use Python 3.9 runtime"
  }

  assert {
    condition     = aws_lambda_function.data_masking.timeout == 30
    error_message = "Data masking Lambda should have 30 second timeout"
  }
}

run "test_lambda_environment_variables" {
  command = plan

  # Test Custom Metrics Lambda environment variables
  assert {
    condition     = aws_lambda_function.custom_metrics.environment[0].variables["PROJECT_CODE"] == "ses-migration"
    error_message = "Custom metrics Lambda should have PROJECT_CODE environment variable"
  }

  assert {
    condition     = aws_lambda_function.custom_metrics.environment[0].variables["ENVIRONMENT"] == "production"
    error_message = "Custom metrics Lambda should have ENVIRONMENT environment variable"
  }

  # Test Data Masking Lambda environment variables
  assert {
    condition     = aws_lambda_function.data_masking.environment[0].variables["PROJECT_CODE"] == "ses-migration"
    error_message = "Data masking Lambda should have PROJECT_CODE environment variable"
  }

  assert {
    condition     = aws_lambda_function.data_masking.environment[0].variables["ENVIRONMENT"] == "production"
    error_message = "Data masking Lambda should have ENVIRONMENT environment variable"
  }
}

run "test_cloudwatch_events" {
  command = plan

  assert {
    condition     = aws_cloudwatch_event_rule.custom_metrics_schedule.name == "ses-migration-production-custom-metrics-schedule"
    error_message = "CloudWatch event rule name should match expected pattern"
  }

  assert {
    condition     = aws_cloudwatch_event_rule.custom_metrics_schedule.schedule_expression == "rate(5 minutes)"
    error_message = "CloudWatch event rule should run every 5 minutes"
  }

  assert {
    condition     = aws_cloudwatch_event_target.custom_metrics.target_id == "CustomMetricsTarget"
    error_message = "CloudWatch event target should have correct target ID"
  }

  assert {
    condition     = aws_cloudwatch_event_target.custom_metrics.arn == aws_lambda_function.custom_metrics.arn
    error_message = "CloudWatch event target should point to custom metrics Lambda"
  }
}

run "test_application_logs" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.application.name == "/aws/application/ses-migration/production"
    error_message = "Application log group name should match expected pattern"
  }

  assert {
    condition     = aws_cloudwatch_log_group.application.retention_in_days == 2555
    error_message = "Application log group should have 7-year retention (2555 days)"
  }

  assert {
    condition     = aws_cloudwatch_log_stream.application.name == "ses-migration-production-application-stream"
    error_message = "Application log stream name should match expected pattern"
  }

  assert {
    condition     = aws_cloudwatch_log_stream.application.log_group_name == aws_cloudwatch_log_group.application.name
    error_message = "Application log stream should belong to application log group"
  }
}

run "test_metric_filters" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_metric_filter.application_errors.name == "ses-migration-production-application-errors"
    error_message = "Metric filter name should match expected pattern"
  }

  assert {
    condition     = aws_cloudwatch_log_metric_filter.application_errors.pattern == "ERROR"
    error_message = "Metric filter should look for ERROR pattern"
  }

  assert {
    condition     = aws_cloudwatch_log_metric_filter.application_errors.log_group_name == aws_cloudwatch_log_group.application.name
    error_message = "Metric filter should use application log group"
  }

  # Test metric transformation
  assert {
    condition     = aws_cloudwatch_log_metric_filter.application_errors.metric_transformation[0].name == "ApplicationErrors"
    error_message = "Metric filter should create ApplicationErrors metric"
  }

  assert {
    condition     = aws_cloudwatch_log_metric_filter.application_errors.metric_transformation[0].value == "1"
    error_message = "Metric filter should increment by 1 for each error"
  }
}

run "test_application_error_alarm" {
  command = plan

  assert {
    condition     = aws_cloudwatch_metric_alarm.application_errors.alarm_name == "ses-migration-production-application-errors"
    error_message = "Application errors alarm name should match expected pattern"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.application_errors.alarm_description == "Application Error Rate is above threshold"
    error_message = "Application errors alarm should have correct description"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.application_errors.comparison_operator == "GreaterThanThreshold"
    error_message = "Application errors alarm should use GreaterThanThreshold comparison"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.application_errors.threshold == 10
    error_message = "Application errors alarm should have threshold of 10"
  }
}

run "test_resource_tagging" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.application.tags["Name"] == "ses-migration-production-application-logs"
    error_message = "Application log group should have proper Name tag"
  }

  assert {
    condition     = aws_cloudwatch_log_stream.application.tags["Name"] == "ses-migration-production-application-stream"
    error_message = "Application log stream should have proper Name tag"
  }

  assert {
    condition     = aws_lambda_function.custom_metrics.tags["Name"] == "ses-migration-production-custom-metrics"
    error_message = "Custom metrics Lambda should have proper Name tag"
  }

  assert {
    condition     = aws_lambda_function.data_masking.tags["Name"] == "ses-migration-production-data-masking"
    error_message = "Data masking Lambda should have proper Name tag"
  }
}
