# SES Configuration Module
# SES Domain Identity, DKIM, Receipt Rules, and CloudWatch Logs

# SES Domain Identity
resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

# SES DKIM
resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

# SES Domain Mail From
resource "aws_ses_domain_mail_from" "main" {
  domain           = aws_ses_domain_identity.main.domain
  mail_from_domain = "mail.${aws_ses_domain_identity.main.domain}"
}

# SES Receipt Rule Set
resource "aws_ses_receipt_rule_set" "main" {
  rule_set_name = "${var.project_code}-${var.environment}-receipt-rules"
}

# SES Receipt Rule for Bounces and Complaints
resource "aws_ses_receipt_rule" "bounces_complaints" {
  name          = "bounces-complaints"
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
  recipients    = [var.domain_name]
  enabled       = true
  scan_enabled  = true

  add_header_action {
    header_name  = "X-SES-RECEIPT-RULE"
    header_value = "bounces-complaints"
  }

  s3_action {
    bucket_name       = var.log_bucket_name
    object_key_prefix = "bounces/${var.environment}/"
    position          = 1
  }

  s3_action {
    bucket_name       = var.log_bucket_name
    object_key_prefix = "complaints/${var.environment}/"
    position          = 2
  }

  depends_on = [aws_ses_receipt_rule_set.main]
}

# SES Configuration Set
resource "aws_ses_configuration_set" "main" {
  name = "${var.project_code}-${var.environment}-config-set"

  delivery_options {
    tls_policy = "Optional"
  }

  reputation_metrics_enabled = true
  last_fresh_start          = "2024-01-01T00:00:00Z"
}

# SES Configuration Set Event Destination
resource "aws_ses_configuration_set_event_destination" "cloudwatch" {
  configuration_set_name = aws_ses_configuration_set.main.name
  event_destination_name = "cloudwatch-logs"
  enabled                = true

  cloudwatch_destination {
    default_value  = "unknown"
    dimension_name = "ConfigurationSetName"
    value_source   = "messageTag"
  }

  matching_types = [
    "send",
    "reject",
    "bounce",
    "complaint",
    "delivery",
    "open",
    "click",
    "renderingFailure"
  ]
}

# CloudWatch Log Group for SES
resource "aws_cloudwatch_log_group" "ses" {
  name              = "/aws/ses/${var.project_code}/${var.environment}"
  retention_in_days = var.retention_days

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-ses-logs"
  })
}

# CloudWatch Log Stream for SES
resource "aws_cloudwatch_log_stream" "ses" {
  name           = "${var.project_code}-${var.environment}-ses-stream"
  log_group_name = aws_cloudwatch_log_group.ses.name
}

# CloudWatch Dashboard for SES
resource "aws_cloudwatch_dashboard" "ses" {
  dashboard_name = "${var.project_code}-${var.environment}-ses-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/SES", "Send", "Domain", var.domain_name],
            [".", "Bounce", ".", "."],
            [".", "Complaint", ".", "."],
            [".", "Delivery", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "SES Metrics - ${var.domain_name}"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/SES", "Send", "Domain", var.domain_name],
            [".", "Reject", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "SES Rejections - ${var.domain_name}"
        }
      }
    ]
  })
}

# Data source for current AWS region
data "aws_region" "current" {}
