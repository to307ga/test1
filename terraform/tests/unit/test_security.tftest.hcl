# UNIT TEST: Security Module
# Tests for IAM Groups, Users, Policies, and Access Control for Personal Information Protection

variables {
  project_code = "ses-migration"
  environment  = "production"
  domain_name  = "goo.ne.jp"
  allowed_ip_ranges = ["10.0.0.0/8", "192.168.1.0/24"]
  initial_password = "TestPassword123!"
  tags = {
    Project     = "ses-migration"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

run "test_iam_groups" {
  command = plan

  # Test Admin Group
  assert {
    condition     = aws_iam_group.admin.name == "ses-migration-production-admin"
    error_message = "Admin group name should match expected pattern"
  }

  # Test ReadOnly Group
  assert {
    condition     = aws_iam_group.readonly.name == "ses-migration-production-readonly"
    error_message = "ReadOnly group name should match expected pattern"
  }

  # Test Monitoring Group
  assert {
    condition     = aws_iam_group.monitoring.name == "ses-migration-production-monitoring"
    error_message = "Monitoring group name should match expected pattern"
  }
}

run "test_iam_users" {
  command = plan

  # Test Admin User
  assert {
    condition     = aws_iam_user.admin.name == "ses-migration-production-admin-user"
    error_message = "Admin user name should match expected pattern"
  }

  # Test ReadOnly User
  assert {
    condition     = aws_iam_user.readonly.name == "ses-migration-production-readonly-user"
    error_message = "ReadOnly user name should match expected pattern"
  }

  # Test Monitoring User
  assert {
    condition     = aws_iam_user.monitoring.name == "ses-migration-production-monitoring-user"
    error_message = "Monitoring user name should match expected pattern"
  }
}

run "test_iam_user_group_memberships" {
  command = plan

  # Test Admin User Group Membership
  assert {
    condition     = aws_iam_user_group_membership.admin.user == aws_iam_user.admin.name
    error_message = "Admin user should be member of admin group"
  }

  assert {
    condition     = aws_iam_user_group_membership.admin.groups[0] == aws_iam_group.admin.name
    error_message = "Admin user should belong to admin group"
  }

  # Test ReadOnly User Group Membership
  assert {
    condition     = aws_iam_user_group_membership.readonly.user == aws_iam_user.readonly.name
    error_message = "ReadOnly user should be member of readonly group"
  }

  assert {
    condition     = aws_iam_user_group_membership.readonly.groups[0] == aws_iam_group.readonly.name
    error_message = "ReadOnly user should belong to readonly group"
  }

  # Test Monitoring User Group Membership
  assert {
    condition     = aws_iam_user_group_membership.monitoring.user == aws_iam_user.monitoring.name
    error_message = "Monitoring user should be member of monitoring group"
  }

  assert {
    condition     = aws_iam_user_group_membership.monitoring.groups[0] == aws_iam_group.monitoring.name
    error_message = "Monitoring user should belong to monitoring group"
  }
}

run "test_admin_policy" {
  command = plan

  assert {
    condition     = aws_iam_policy.admin.name == "ses-migration-production-admin-policy"
    error_message = "Admin policy name should match expected pattern"
  }

  assert {
    condition     = aws_iam_policy.admin.description == "Policy for Admin users with full access"
    error_message = "Admin policy should have correct description"
  }

  # Test that admin policy includes full SES access
  assert {
    condition     = can(regex("ses:\\*", aws_iam_policy.admin.policy))
    error_message = "Admin policy should include full SES access (ses:*)"
  }

  # Test that admin policy includes full CloudWatch access
  assert {
    condition     = can(regex("cloudwatch:\\*", aws_iam_policy.admin.policy))
    error_message = "Admin policy should include full CloudWatch access (cloudwatch:*)"
  }

  # Test that admin policy includes full Logs access
  assert {
    condition     = can(regex("logs:\\*", aws_iam_policy.admin.policy))
    error_message = "Admin policy should include full Logs access (logs:*)"
  }

  # Test that admin policy includes IP restrictions
  assert {
    condition     = can(regex("10\\.0\\.0\\.0/8", aws_iam_policy.admin.policy))
    error_message = "Admin policy should include IP restriction for 10.0.0.0/8"
  }

  assert {
    condition     = can(regex("192\\.168\\.1\\.0/24", aws_iam_policy.admin.policy))
    error_message = "Admin policy should include IP restriction for 192.168.1.0/24"
  }
}

run "test_readonly_policy" {
  command = plan

  assert {
    condition     = aws_iam_policy.readonly.name == "ses-migration-production-readonly-policy"
    error_message = "ReadOnly policy name should match expected pattern"
  }

  assert {
    condition     = aws_iam_policy.readonly.description == "Policy for ReadOnly users with masked data access"
    error_message = "ReadOnly policy should have correct description"
  }

  # Test that readonly policy includes limited SES access
  assert {
    condition     = can(regex("ses:GetSendStatistics", aws_iam_policy.readonly.policy))
    error_message = "ReadOnly policy should include ses:GetSendStatistics"
  }

  assert {
    condition     = can(regex("ses:GetSendQuota", aws_iam_policy.readonly.policy))
    error_message = "ReadOnly policy should include ses:GetSendQuota"
  }

  # Test that readonly policy includes limited CloudWatch access
  assert {
    condition     = can(regex("cloudwatch:GetMetricStatistics", aws_iam_policy.readonly.policy))
    error_message = "ReadOnly policy should include cloudwatch:GetMetricStatistics"
  }

  # Test that readonly policy includes IP restrictions
  assert {
    condition     = can(regex("10\\.0\\.0\\.0/8", aws_iam_policy.readonly.policy))
    error_message = "ReadOnly policy should include IP restriction for 10.0.0.0/8"
  }

  assert {
    condition     = can(regex("192\\.168\\.1\\.0/24", aws_iam_policy.readonly.policy))
    error_message = "ReadOnly policy should include IP restriction for 192.168.1.0/24"
  }
}

run "test_monitoring_policy" {
  command = plan

  assert {
    condition     = aws_iam_policy.monitoring.name == "ses-migration-production-monitoring-policy"
    error_message = "Monitoring policy name should match expected pattern"
  }

  assert {
    condition     = aws_iam_policy.monitoring.description == "Policy for Monitoring users with masked data access"
    error_message = "Monitoring policy should have correct description"
  }

  # Test that monitoring policy includes full CloudWatch access
  assert {
    condition     = can(regex("cloudwatch:\\*", aws_iam_policy.monitoring.policy))
    error_message = "Monitoring policy should include full CloudWatch access (cloudwatch:*)"
  }

  # Test that monitoring policy includes full Logs access
  assert {
    condition     = can(regex("logs:\\*", aws_iam_policy.monitoring.policy))
    error_message = "Monitoring policy should include full Logs access (logs:*)"
  }

  # Test that monitoring policy includes IP restrictions
  assert {
    condition     = can(regex("10\\.0\\.0\\.0/8", aws_iam_policy.monitoring.policy))
    error_message = "Monitoring policy should include IP restriction for 10.0.0.0/8"
  }

  assert {
    condition     = can(regex("192\\.168\\.1\\.0/24", aws_iam_policy.monitoring.policy))
    error_message = "Monitoring policy should include IP restriction for 192.168.1.0/24"
  }
}

run "test_personal_information_protection_policies" {
  command = plan

  # Test that admin policy allows access to unmasked query
  assert {
    condition     = can(regex("ses-analysis-admin", aws_iam_policy.admin.policy))
    error_message = "Admin policy should allow access to unmasked query (ses-analysis-admin)"
  }

  # Test that readonly policy restricts access to masked query
  assert {
    condition     = can(regex("ses-analysis-masked", aws_iam_policy.readonly.policy))
    error_message = "ReadOnly policy should restrict access to masked query (ses-analysis-masked)"
  }

  # Test that monitoring policy restricts access to masked query
  assert {
    condition     = can(regex("ses-analysis-masked", aws_iam_policy.monitoring.policy))
    error_message = "Monitoring policy should restrict access to masked query (ses-analysis-masked)"
  }

  # Test that readonly and monitoring policies can invoke data masking Lambda
  assert {
    condition     = can(regex("lambda:InvokeFunction", aws_iam_policy.readonly.policy))
    error_message = "ReadOnly policy should allow Lambda function invocation for data masking"
  }

  assert {
    condition     = can(regex("lambda:InvokeFunction", aws_iam_policy.monitoring.policy))
    error_message = "Monitoring policy should allow Lambda function invocation for data masking"
  }
}

run "test_iam_policy_attachments" {
  command = plan

  # Test Admin Policy Attachment
  assert {
    condition     = aws_iam_group_policy_attachment.admin.group == aws_iam_group.admin.name
    error_message = "Admin policy should be attached to admin group"
  }

  assert {
    condition     = aws_iam_group_policy_attachment.admin.policy_arn == aws_iam_policy.admin.arn
    error_message = "Admin policy should be attached to admin group"
  }

  # Test ReadOnly Policy Attachment
  assert {
    condition     = aws_iam_group_policy_attachment.readonly.group == aws_iam_group.readonly.name
    error_message = "ReadOnly policy should be attached to readonly group"
  }

  assert {
    condition     = aws_iam_group_policy_attachment.readonly.policy_arn == aws_iam_policy.readonly.arn
    error_message = "ReadOnly policy should be attached to readonly group"
  }

  # Test Monitoring Policy Attachment
  assert {
    condition     = aws_iam_group_policy_attachment.monitoring.group == aws_iam_group.monitoring.name
    error_message = "Monitoring policy should be attached to monitoring group"
  }

  assert {
    condition     = aws_iam_group_policy_attachment.monitoring.policy_arn == aws_iam_policy.monitoring.arn
    error_message = "Monitoring policy should be attached to monitoring group"
  }
}

run "test_smtp_credentials" {
  command = plan

  # Test IAM Access Key for Admin
  assert {
    condition     = aws_iam_access_key.admin.user == aws_iam_user.admin.name
    error_message = "Admin access key should belong to admin user"
  }

  # Test Secrets Manager Secret
  assert {
    condition     = aws_secretsmanager_secret.smtp_credentials.name == "ses-migration-production-smtp-credentials"
    error_message = "SMTP credentials secret name should match expected pattern"
  }

  assert {
    condition     = aws_secretsmanager_secret.smtp_credentials.description == "SMTP credentials for SES"
    error_message = "SMTP credentials secret should have correct description"
  }

  # Test Secret Version
  assert {
    condition     = aws_secretsmanager_secret_version.smtp_credentials.secret_id == aws_secretsmanager_secret.smtp_credentials.id
    error_message = "Secret version should belong to SMTP credentials secret"
  }
}

run "test_ec2_instance_role" {
  command = plan

  # Test IAM Role for EC2 Instances
  assert {
    condition     = aws_iam_role.instance.name == "ses-migration-production-instance-role"
    error_message = "EC2 instance role name should match expected pattern"
  }

  # Test IAM Policy for EC2 Instances
  assert {
    condition     = aws_iam_policy.instance.name == "ses-migration-production-instance-policy"
    error_message = "EC2 instance policy name should match expected pattern"
  }

  assert {
    condition     = aws_iam_policy.instance.description == "Policy for EC2 instances"
    error_message = "EC2 instance policy should have correct description"
  }

  # Test that EC2 policy includes SES send permissions
  assert {
    condition     = can(regex("ses:SendEmail", aws_iam_policy.instance.policy))
    error_message = "EC2 instance policy should include ses:SendEmail permission"
  }

  assert {
    condition     = can(regex("ses:SendRawEmail", aws_iam_policy.instance.policy))
    error_message = "EC2 instance policy should include ses:SendRawEmail permission"
  }

  # Test IAM Role Policy Attachment
  assert {
    condition     = aws_iam_role_policy_attachment.instance.role == aws_iam_role.instance.name
    error_message = "EC2 instance policy should be attached to instance role"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.instance.policy_arn == aws_iam_policy.instance.arn
    error_message = "EC2 instance policy should be attached to instance role"
  }

  # Test Instance Profile
  assert {
    condition     = aws_iam_instance_profile.instance.name == "ses-migration-production-instance-profile"
    error_message = "Instance profile name should match expected pattern"
  }

  assert {
    condition     = aws_iam_instance_profile.instance.role == aws_iam_role.instance.name
    error_message = "Instance profile should use the instance role"
  }
}

run "test_resource_tagging" {
  command = plan

  # Test IAM Group Tags
  assert {
    condition     = aws_iam_group.admin.tags["Name"] == "ses-migration-production-admin"
    error_message = "Admin group should have proper Name tag"
  }

  assert {
    condition     = aws_iam_group.readonly.tags["Name"] == "ses-migration-production-readonly"
    error_message = "ReadOnly group should have proper Name tag"
  }

  assert {
    condition     = aws_iam_group.monitoring.tags["Name"] == "ses-migration-production-monitoring"
    error_message = "Monitoring group should have proper Name tag"
  }

  # Test IAM User Tags
  assert {
    condition     = aws_iam_user.admin.tags["Name"] == "ses-migration-production-admin-user"
    error_message = "Admin user should have proper Name tag"
  }

  assert {
    condition     = aws_iam_user.readonly.tags["Name"] == "ses-migration-production-readonly-user"
    error_message = "ReadOnly user should have proper Name tag"
  }

  assert {
    condition     = aws_iam_user.monitoring.tags["Name"] == "ses-migration-production-monitoring-user"
    error_message = "Monitoring user should have proper Name tag"
  }

  # Test IAM Role Tags
  assert {
    condition     = aws_iam_role.instance.tags["Name"] == "ses-migration-production-instance-role"
    error_message = "EC2 instance role should have proper Name tag"
  }

  # Test Secrets Manager Tags
  assert {
    condition     = aws_secretsmanager_secret.smtp_credentials.tags["Name"] == "ses-migration-production-smtp-credentials"
    error_message = "SMTP credentials secret should have proper Name tag"
  }
}
