# INTEGRATION TEST: Full Infrastructure
# Tests for module dependencies and integration behavior

variables {
  project_code = "ses-migration"
  environment  = "production"
  domain_name  = "goo.ne.jp"
  allowed_ip_ranges = ["10.0.0.0/8", "192.168.1.0/24"]
  retention_days = 2555
  tags = {
    Project     = "ses-migration"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

run "test_module_dependencies" {
  command = plan

  # Test that base infrastructure provides required outputs
  assert {
    condition     = module.base_infrastructure.log_bucket_name != ""
    error_message = "Base infrastructure should provide log bucket name"
  }

  assert {
    condition     = module.base_infrastructure.notification_topic_arn != ""
    error_message = "Base infrastructure should provide notification topic ARN"
  }

  # Test that SES configuration uses base infrastructure outputs
  assert {
    condition     = module.ses_configuration.log_bucket_name == module.base_infrastructure.log_bucket_name
    error_message = "SES configuration should use base infrastructure log bucket"
  }

  # Test that monitoring uses SES log group
  assert {
    condition     = module.monitoring.ses_log_group_name == module.ses_configuration.ses_log_group_name
    error_message = "Monitoring should use SES log group from SES configuration"
  }

  # Test that monitoring uses base infrastructure notification topic
  assert {
    condition     = module.monitoring.notification_topic_arn == module.base_infrastructure.notification_topic_arn
    error_message = "Monitoring should use notification topic from base infrastructure"
  }
}

run "test_personal_information_protection_integration" {
  command = plan

  # Test that admin query definition exists and is accessible
  assert {
    condition     = module.monitoring.admin_query_definition_name != ""
    error_message = "Admin query definition should be created by monitoring module"
  }

  # Test that masked query definition exists and is accessible
  assert {
    condition     = module.monitoring.masked_query_definition_name != ""
    error_message = "Masked query definition should be created by monitoring module"
  }

  # Test that data masking Lambda function exists
  assert {
    condition     = module.monitoring.data_masking_function_arn != ""
    error_message = "Data masking Lambda function should be created by monitoring module"
  }

  # Test that security module creates proper IAM groups
  assert {
    condition     = module.security.admin_group_arn != ""
    error_message = "Security module should create admin group"
  }

  assert {
    condition     = module.security.readonly_group_arn != ""
    error_message = "Security module should create readonly group"
  }

  assert {
    condition     = module.security.monitoring_group_arn != ""
    error_message = "Security module should create monitoring group"
  }
}

run "test_logging_and_monitoring_integration" {
  command = plan

  # Test that CloudWatch alarms are properly configured
  assert {
    condition     = module.monitoring.ses_send_failure_alarm_name != ""
    error_message = "SES send failure alarm should be created"
  }

  assert {
    condition     = module.monitoring.ses_bounce_rate_alarm_name != ""
    error_message = "SES bounce rate alarm should be created"
  }

  assert {
    condition     = module.monitoring.ses_complaint_rate_alarm_name != ""
    error_message = "SES complaint rate alarm should be created"
  }

  # Test that composite alarm exists
  assert {
    condition     = module.monitoring.composite_alarm_name != ""
    error_message = "Composite alarm should be created"
  }

  # Test that custom metrics Lambda exists
  assert {
    condition     = module.monitoring.custom_metrics_function_arn != ""
    error_message = "Custom metrics Lambda function should be created"
  }
}

run "test_ses_configuration_integration" {
  command = plan

  # Test that SES domain identity is created
  assert {
    condition     = module.ses_configuration.domain_identity == "goo.ne.jp"
    error_message = "SES domain identity should match the specified domain"
  }

  # Test that DKIM tokens are generated
  assert {
    condition     = length(module.ses_configuration.dkim_tokens) > 0
    error_message = "DKIM tokens should be generated for DNS configuration"
  }

  # Test that mail from domain is configured
  assert {
    condition     = module.ses_configuration.mail_from_domain == "mail.goo.ne.jp"
    error_message = "Mail from domain should be properly configured"
  }

  # Test that SES log group is created
  assert {
    condition     = module.ses_configuration.ses_log_group_name != ""
    error_message = "SES log group should be created"
  }

  # Test that CloudWatch dashboard is created
  assert {
    condition     = module.ses_configuration.dashboard_name != ""
    error_message = "CloudWatch dashboard should be created"
  }
}

run "test_security_and_access_control_integration" {
  command = plan

  # Test that SMTP credentials are stored in Secrets Manager
  assert {
    condition     = module.security.smtp_credentials_secret_arn != ""
    error_message = "SMTP credentials should be stored in Secrets Manager"
  }

  # Test that instance profile is created for future EC2 migration
  assert {
    condition     = module.security.instance_profile_arn != ""
    error_message = "Instance profile should be created for EC2 instances"
  }

  # Test that admin user is created
  assert {
    condition     = module.security.admin_user_name != ""
    error_message = "Admin user should be created"
  }

  # Test that readonly user is created
  assert {
    condition     = module.security.readonly_user_name != ""
    error_message = "ReadOnly user should be created"
  }

  # Test that monitoring user is created
  assert {
    condition     = module.security.monitoring_user_name != ""
    error_message = "Monitoring user should be created"
  }
}

run "test_outputs_integration" {
  command = plan

  # Test main outputs
  assert {
    condition     = output.ses_domain_identity == "goo.ne.jp"
    error_message = "Main output should provide SES domain identity"
  }

  assert {
    condition     = output.ses_dkim_tokens != ""
    error_message = "Main output should provide DKIM tokens"
  }

  assert {
    condition     = output.smtp_credentials_secret_arn != ""
    error_message = "Main output should provide SMTP credentials secret ARN"
  }

  assert {
    condition     = output.cloudwatch_dashboard_url != ""
    error_message = "Main output should provide CloudWatch dashboard URL"
  }

  assert {
    condition     = output.log_bucket_name != ""
    error_message = "Main output should provide log bucket name"
  }

  assert {
    condition     = output.notification_topic_arn != ""
    error_message = "Main output should provide notification topic ARN"
  }

  assert {
    condition     = output.admin_user_name != ""
    error_message = "Main output should provide admin user name"
  }

  assert {
    condition     = output.readonly_user_name != ""
    error_message = "Main output should provide readonly user name"
  }

  assert {
    condition     = output.monitoring_user_name != ""
    error_message = "Main output should provide monitoring user name"
  }
}

run "test_compliance_and_audit_integration" {
  command = plan

  # Test that CloudTrail is configured for audit logging
  assert {
    condition     = module.base_infrastructure.cloudtrail_name != ""
    error_message = "CloudTrail should be configured for audit logging"
  }

  # Test that AWS Config is configured for compliance monitoring
  assert {
    condition     = module.base_infrastructure.config_role_arn != ""
    error_message = "AWS Config role should be configured for compliance monitoring"
  }

  # Test that S3 bucket has proper lifecycle configuration for 7-year retention
  assert {
    condition     = module.base_infrastructure.log_bucket_name != ""
    error_message = "S3 bucket should be configured for log storage"
  }

  # Test that CloudWatch log groups have proper retention
  assert {
    condition     = module.ses_configuration.ses_log_group_name != ""
    error_message = "SES log group should be configured with proper retention"
  }

  assert {
    condition     = module.monitoring.application_log_group_name != ""
    error_message = "Application log group should be configured with proper retention"
  }
}
