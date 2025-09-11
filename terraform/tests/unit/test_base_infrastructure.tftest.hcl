# UNIT TEST: Base Infrastructure Module
# Tests for S3, SNS, CloudTrail, and AWS Config resources

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

run "test_s3_bucket_configuration" {
  command = plan

  assert {
    condition     = aws_s3_bucket.logs.bucket == "ses-migration-production-logs-${random_string.bucket_suffix.result}"
    error_message = "S3 bucket name should match expected pattern"
  }

  assert {
    condition     = aws_s3_bucket_versioning.logs.versioning_configuration[0].status == "Enabled"
    error_message = "S3 bucket versioning should be enabled"
  }

  assert {
    condition     = aws_s3_bucket_server_side_encryption_configuration.logs.rule[0].apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    error_message = "S3 bucket should use AES256 encryption"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.logs.block_public_acls == true
    error_message = "S3 bucket should block public ACLs"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.logs.block_public_policy == true
    error_message = "S3 bucket should block public policies"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.logs.ignore_public_acls == true
    error_message = "S3 bucket should ignore public ACLs"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.logs.restrict_public_buckets == true
    error_message = "S3 bucket should restrict public buckets"
  }
}

run "test_s3_bucket_lifecycle" {
  command = plan

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.logs.rule[0].transition[0].days == 30
    error_message = "First transition should be at 30 days"
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.logs.rule[0].transition[0].storage_class == "STANDARD_IA"
    error_message = "First transition should be to STANDARD_IA"
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.logs.rule[0].transition[1].days == 90
    error_message = "Second transition should be at 90 days"
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.logs.rule[0].transition[1].storage_class == "GLACIER"
    error_message = "Second transition should be to GLACIER"
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.logs.rule[0].transition[2].days == 365
    error_message = "Third transition should be at 365 days"
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.logs.rule[0].transition[2].storage_class == "DEEP_ARCHIVE"
    error_message = "Third transition should be to DEEP_ARCHIVE"
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.logs.rule[0].expiration[0].days == 2555
    error_message = "Expiration should be at 2555 days (7 years)"
  }
}

run "test_sns_topic_configuration" {
  command = plan

  assert {
    condition     = aws_sns_topic.notifications.name == "ses-migration-production-notifications"
    error_message = "SNS topic name should match expected pattern"
  }

  assert {
    condition     = aws_sns_topic_policy.notifications.policy != ""
    error_message = "SNS topic should have a policy"
  }
}

run "test_cloudtrail_configuration" {
  command = plan

  assert {
    condition     = aws_cloudtrail.audit.name == "ses-migration-production-audit-trail"
    error_message = "CloudTrail name should match expected pattern"
  }

  assert {
    condition     = aws_cloudtrail.audit.s3_bucket_name == aws_s3_bucket.logs.bucket
    error_message = "CloudTrail should use the logs S3 bucket"
  }

  assert {
    condition     = aws_cloudtrail.audit.include_global_service_events == true
    error_message = "CloudTrail should include global service events"
  }

  assert {
    condition     = aws_cloudtrail.audit.is_multi_region_trail == true
    error_message = "CloudTrail should be multi-region"
  }

  assert {
    condition     = aws_cloudtrail.audit.enable_log_file_validation == true
    error_message = "CloudTrail should enable log file validation"
  }
}

run "test_aws_config_configuration" {
  command = plan

  assert {
    condition     = aws_config_delivery_channel.main.name == "ses-migration-production-config-delivery"
    error_message = "AWS Config delivery channel name should match expected pattern"
  }

  assert {
    condition     = aws_config_delivery_channel.main.s3_bucket_name == aws_s3_bucket.logs.bucket
    error_message = "AWS Config should use the logs S3 bucket"
  }

  assert {
    condition     = aws_config_configuration_recorder.main.name == "ses-migration-production-config-recorder"
    error_message = "AWS Config recorder name should match expected pattern"
  }

  assert {
    condition     = aws_config_configuration_recorder.main.role_arn == aws_iam_role.config.arn
    error_message = "AWS Config recorder should use the config IAM role"
  }
}

run "test_iam_role_configuration" {
  command = plan

  assert {
    condition     = aws_iam_role.config.name == "ses-migration-production-config-role"
    error_message = "AWS Config IAM role name should match expected pattern"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.config.role == aws_iam_role.config.name
    error_message = "AWS Config role should have the ConfigRole policy attached"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.config_s3.role == aws_iam_role.config.name
    error_message = "AWS Config role should have the S3 access policy attached"
  }
}

run "test_resource_tagging" {
  command = plan

  # Test that all resources have proper tags
  assert {
    condition     = aws_s3_bucket.logs.tags["Name"] == "ses-migration-production-logs"
    error_message = "S3 bucket should have proper Name tag"
  }

  assert {
    condition     = aws_sns_topic.notifications.tags["Name"] == "ses-migration-production-notifications"
    error_message = "SNS topic should have proper Name tag"
  }

  assert {
    condition     = aws_cloudtrail.audit.tags["Name"] == "ses-migration-production-audit-trail"
    error_message = "CloudTrail should have proper Name tag"
  }

  assert {
    condition     = aws_iam_role.config.tags["Name"] == "ses-migration-production-config-role"
    error_message = "IAM role should have proper Name tag"
  }
}
