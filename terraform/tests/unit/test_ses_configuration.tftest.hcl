# UNIT TEST: SES Configuration Module
# Tests for SES Domain Identity, DKIM, Receipt Rules, and CloudWatch Logs

variables {
  project_code = "ses-migration"
  environment  = "production"
  domain_name  = "goo.ne.jp"
  allowed_ip_ranges = ["10.0.0.0/8", "192.168.1.0/24"]
  log_bucket_name = "ses-migration-production-logs-abc12345"
  notification_topic_arn = "arn:aws:sns:us-east-1:123456789012:ses-migration-production-notifications"
  retention_days = 2555
  tags = {
    Project     = "ses-migration"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

run "test_ses_domain_identity" {
  command = plan

  assert {
    condition     = aws_ses_domain_identity.main.domain == "goo.ne.jp"
    error_message = "SES domain identity should match the specified domain"
  }
}

run "test_ses_dkim_configuration" {
  command = plan

  assert {
    condition     = aws_ses_domain_dkim.main.domain == aws_ses_domain_identity.main.domain
    error_message = "DKIM domain should match the SES domain identity"
  }
}

run "test_ses_mail_from_domain" {
  command = plan

  assert {
    condition     = aws_ses_domain_mail_from.main.domain == aws_ses_domain_identity.main.domain
    error_message = "Mail from domain should match the SES domain identity"
  }

  assert {
    condition     = aws_ses_domain_mail_from.main.mail_from_domain == "mail.goo.ne.jp"
    error_message = "Mail from domain should be prefixed with 'mail.'"
  }
}

run "test_ses_receipt_rule_set" {
  command = plan

  assert {
    condition     = aws_ses_receipt_rule_set.main.rule_set_name == "ses-migration-production-receipt-rules"
    error_message = "Receipt rule set name should match expected pattern"
  }
}

run "test_ses_receipt_rule_bounces_complaints" {
  command = plan

  assert {
    condition     = aws_ses_receipt_rule.bounces_complaints.name == "bounces-complaints"
    error_message = "Receipt rule name should be 'bounces-complaints'"
  }

  assert {
    condition     = aws_ses_receipt_rule.bounces_complaints.rule_set_name == aws_ses_receipt_rule_set.main.rule_set_name
    error_message = "Receipt rule should belong to the main rule set"
  }

  assert {
    condition     = aws_ses_receipt_rule.bounces_complaints.recipients[0] == "goo.ne.jp"
    error_message = "Receipt rule should have the correct domain as recipient"
  }

  assert {
    condition     = aws_ses_receipt_rule.bounces_complaints.enabled == true
    error_message = "Receipt rule should be enabled"
  }

  assert {
    condition     = aws_ses_receipt_rule.bounces_complaints.scan_enabled == true
    error_message = "Receipt rule should have scan enabled"
  }
}

run "test_ses_receipt_rule_s3_actions" {
  command = plan

  # Test bounces S3 action
  assert {
    condition     = aws_ses_receipt_rule.bounces_complaints.s3_action[0].bucket_name == "ses-migration-production-logs-abc12345"
    error_message = "Bounces S3 action should use the correct bucket"
  }

  assert {
    condition     = aws_ses_receipt_rule.bounces_complaints.s3_action[0].object_key_prefix == "bounces/production/"
    error_message = "Bounces S3 action should have correct object key prefix"
  }

  assert {
    condition     = aws_ses_receipt_rule.bounces_complaints.s3_action[0].position == 1
    error_message = "Bounces S3 action should have position 1"
  }

  # Test complaints S3 action
  assert {
    condition     = aws_ses_receipt_rule.bounces_complaints.s3_action[1].bucket_name == "ses-migration-production-logs-abc12345"
    error_message = "Complaints S3 action should use the correct bucket"
  }

  assert {
    condition     = aws_ses_receipt_rule.bounces_complaints.s3_action[1].object_key_prefix == "complaints/production/"
    error_message = "Complaints S3 action should have correct object key prefix"
  }

  assert {
    condition     = aws_ses_receipt_rule.bounces_complaints.s3_action[1].position == 2
    error_message = "Complaints S3 action should have position 2"
  }
}

run "test_ses_configuration_set" {
  command = plan

  assert {
    condition     = aws_ses_configuration_set.main.name == "ses-migration-production-config-set"
    error_message = "Configuration set name should match expected pattern"
  }

  assert {
    condition     = aws_ses_configuration_set.main.delivery_options[0].tls_policy == "Optional"
    error_message = "Configuration set should have Optional TLS policy"
  }

  assert {
    condition     = aws_ses_configuration_set.main.reputation_metrics_enabled == true
    error_message = "Configuration set should have reputation metrics enabled"
  }
}

run "test_ses_configuration_set_event_destination" {
  command = plan

  assert {
    condition     = aws_ses_configuration_set_event_destination.cloudwatch.configuration_set_name == aws_ses_configuration_set.main.name
    error_message = "Event destination should belong to the main configuration set"
  }

  assert {
    condition     = aws_ses_configuration_set_event_destination.cloudwatch.event_destination_name == "cloudwatch-logs"
    error_message = "Event destination name should be 'cloudwatch-logs'"
  }

  assert {
    condition     = aws_ses_configuration_set_event_destination.cloudwatch.enabled == true
    error_message = "Event destination should be enabled"
  }

  # Test CloudWatch destination configuration
  assert {
    condition     = aws_ses_configuration_set_event_destination.cloudwatch.cloudwatch_destination[0].default_value == "unknown"
    error_message = "CloudWatch destination should have default value 'unknown'"
  }

  assert {
    condition     = aws_ses_configuration_set_event_destination.cloudwatch.cloudwatch_destination[0].dimension_name == "ConfigurationSetName"
    error_message = "CloudWatch destination should use ConfigurationSetName dimension"
  }

  assert {
    condition     = aws_ses_configuration_set_event_destination.cloudwatch.cloudwatch_destination[0].value_source == "messageTag"
    error_message = "CloudWatch destination should use messageTag value source"
  }
}

run "test_ses_configuration_set_matching_types" {
  command = plan

  # Test that all required event types are included
  local.required_event_types = [
    "send",
    "reject", 
    "bounce",
    "complaint",
    "delivery",
    "open",
    "click",
    "renderingFailure"
  ]

  assert {
    condition     = length(aws_ses_configuration_set_event_destination.cloudwatch.matching_types) == 8
    error_message = "Configuration set should have 8 matching event types"
  }

  assert {
    condition     = contains(aws_ses_configuration_set_event_destination.cloudwatch.matching_types, "send")
    error_message = "Configuration set should include 'send' event type"
  }

  assert {
    condition     = contains(aws_ses_configuration_set_event_destination.cloudwatch.matching_types, "bounce")
    error_message = "Configuration set should include 'bounce' event type"
  }

  assert {
    condition     = contains(aws_ses_configuration_set_event_destination.cloudwatch.matching_types, "complaint")
    error_message = "Configuration set should include 'complaint' event type"
  }
}

run "test_cloudwatch_logs_configuration" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.ses.name == "/aws/ses/ses-migration/production"
    error_message = "CloudWatch log group name should match expected pattern"
  }

  assert {
    condition     = aws_cloudwatch_log_group.ses.retention_in_days == 2555
    error_message = "CloudWatch log group should have 7-year retention (2555 days)"
  }

  assert {
    condition     = aws_cloudwatch_log_stream.ses.name == "ses-migration-production-ses-stream"
    error_message = "CloudWatch log stream name should match expected pattern"
  }

  assert {
    condition     = aws_cloudwatch_log_stream.ses.log_group_name == aws_cloudwatch_log_group.ses.name
    error_message = "Log stream should belong to the SES log group"
  }
}

run "test_cloudwatch_dashboard" {
  command = plan

  assert {
    condition     = aws_cloudwatch_dashboard.ses.dashboard_name == "ses-migration-production-ses-dashboard"
    error_message = "CloudWatch dashboard name should match expected pattern"
  }

  # Test dashboard body contains required metrics
  assert {
    condition     = can(jsondecode(aws_cloudwatch_dashboard.ses.dashboard_body))
    error_message = "Dashboard body should be valid JSON"
  }
}

run "test_resource_tagging" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.ses.tags["Name"] == "ses-migration-production-ses-logs"
    error_message = "CloudWatch log group should have proper Name tag"
  }

  assert {
    condition     = aws_cloudwatch_log_stream.ses.tags["Name"] == "ses-migration-production-ses-stream"
    error_message = "CloudWatch log stream should have proper Name tag"
  }
}
