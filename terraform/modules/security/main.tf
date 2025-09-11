# Security Module
# IAM Groups, Users, Policies, and Access Control for Personal Information Protection

# IAM Group for Admin Users
resource "aws_iam_group" "admin" {
  name = "${var.project_code}-${var.environment}-admin"
  path = "/"

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-admin"
  })
}

# IAM Group for ReadOnly Users
resource "aws_iam_group" "readonly" {
  name = "${var.project_code}-${var.environment}-readonly"
  path = "/"

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-readonly"
  })
}

# IAM Group for Monitoring Users
resource "aws_iam_group" "monitoring" {
  name = "${var.project_code}-${var.environment}-monitoring"
  path = "/"

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-monitoring"
  })
}

# IAM Policy for Admin Users
resource "aws_iam_policy" "admin" {
  name        = "${var.project_code}-${var.environment}-admin-policy"
  description = "Policy for Admin users with full access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:*",
          "cloudwatch:*",
          "logs:*",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "firehose:*",
          "sns:*",
          "lambda:InvokeFunction"
        ]
        Resource = "*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = var.allowed_ip_ranges
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetUser",
          "iam:GetGroup",
          "iam:GetRole",
          "iam:GetPolicy",
          "iam:ListUsers",
          "iam:ListGroups",
          "iam:ListRoles"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "logs:QueryDefinitionName" = "${var.project_code}-${var.environment}-ses-analysis-admin"
          }
          IpAddress = {
            "aws:SourceIp" = var.allowed_ip_ranges
          }
        }
      }
    ]
  })
}

# IAM Policy for ReadOnly Users
resource "aws_iam_policy" "readonly" {
  name        = "${var.project_code}-${var.environment}-readonly-policy"
  description = "Policy for ReadOnly users with masked data access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:GetSendStatistics",
          "ses:GetSendQuota",
          "ses:GetIdentityVerificationAttributes",
          "ses:GetIdentityDkimAttributes",
          "ses:GetIdentityNotificationAttributes",
          "ses:ListIdentities",
          "ses:ListVerifiedEmailAddresses",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = "*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = var.allowed_ip_ranges
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "logs:QueryDefinitionName" = "${var.project_code}-${var.environment}-ses-analysis-masked"
          }
          IpAddress = {
            "aws:SourceIp" = var.allowed_ip_ranges
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.project_code}-${var.environment}-data-masking"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = var.allowed_ip_ranges
          }
        }
      }
    ]
  })
}

# IAM Policy for Monitoring Users
resource "aws_iam_policy" "monitoring" {
  name        = "${var.project_code}-${var.environment}-monitoring-policy"
  description = "Policy for Monitoring users with masked data access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:*",
          "logs:*",
          "sns:GetTopicAttributes",
          "sns:ListTopics",
          "sns:ListSubscriptions"
        ]
        Resource = "*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = var.allowed_ip_ranges
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "logs:QueryDefinitionName" = "${var.project_code}-${var.environment}-ses-analysis-masked"
          }
          IpAddress = {
            "aws:SourceIp" = var.allowed_ip_ranges
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.project_code}-${var.environment}-data-masking"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = var.allowed_ip_ranges
          }
        }
      }
    ]
  })
}

# IAM Group Policy Attachment for Admin
resource "aws_iam_group_policy_attachment" "admin" {
  group      = aws_iam_group.admin.name
  policy_arn = aws_iam_policy.admin.arn
}

# IAM Group Policy Attachment for ReadOnly
resource "aws_iam_group_policy_attachment" "readonly" {
  group      = aws_iam_group.readonly.name
  policy_arn = aws_iam_policy.readonly.arn
}

# IAM Group Policy Attachment for Monitoring
resource "aws_iam_group_policy_attachment" "monitoring" {
  group      = aws_iam_group.monitoring.name
  policy_arn = aws_iam_policy.monitoring.arn
}

# IAM User for Admin Access
resource "aws_iam_user" "admin" {
  name = "${var.project_code}-${var.environment}-admin-user"
  path = "/"

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-admin-user"
  })
}

# IAM User for ReadOnly Access
resource "aws_iam_user" "readonly" {
  name = "${var.project_code}-${var.environment}-readonly-user"
  path = "/"

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-readonly-user"
  })
}

# IAM User for Monitoring Access
resource "aws_iam_user" "monitoring" {
  name = "${var.project_code}-${var.environment}-monitoring-user"
  path = "/"

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-monitoring-user"
  })
}

# IAM User Group Membership for Admin
resource "aws_iam_user_group_membership" "admin" {
  user   = aws_iam_user.admin.name
  groups = [aws_iam_group.admin.name]
}

# IAM User Group Membership for ReadOnly
resource "aws_iam_user_group_membership" "readonly" {
  user   = aws_iam_user.readonly.name
  groups = [aws_iam_group.readonly.name]
}

# IAM User Group Membership for Monitoring
resource "aws_iam_user_group_membership" "monitoring" {
  user   = aws_iam_user.monitoring.name
  groups = [aws_iam_group.monitoring.name]
}

# IAM Access Keys for SMTP Authentication
resource "aws_iam_access_key" "admin" {
  user = aws_iam_user.admin.name
}

# Secrets Manager for SMTP Credentials
resource "aws_secretsmanager_secret" "smtp_credentials" {
  name        = "${var.project_code}-${var.environment}-smtp-credentials"
  description = "SMTP credentials for SES"

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-smtp-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "smtp_credentials" {
  secret_id = aws_secretsmanager_secret.smtp_credentials.id
  secret_string = jsonencode({
    username   = aws_iam_access_key.admin.id
    password   = aws_iam_access_key.admin.secret
    smtp_host  = "email-smtp.${data.aws_region.current.name}.amazonaws.com"
    smtp_port  = "587"
  })
}

# IAM Role for EC2 Instances (for future AWS migration)
resource "aws_iam_role" "instance" {
  name = "${var.project_code}-${var.environment}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-instance-role"
  })
}

# IAM Policy for EC2 Instances
resource "aws_iam_policy" "instance" {
  name        = "${var.project_code}-${var.environment}-instance-policy"
  description = "Policy for EC2 instances"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role Policy Attachment for Instance
resource "aws_iam_role_policy_attachment" "instance" {
  role       = aws_iam_role.instance.name
  policy_arn = aws_iam_policy.instance.arn
}

# Instance Profile for EC2
resource "aws_iam_instance_profile" "instance" {
  name = "${var.project_code}-${var.environment}-instance-profile"
  path = "/"
  role = aws_iam_role.instance.name
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
