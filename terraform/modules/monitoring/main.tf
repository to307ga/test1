# Monitoring Module
# CloudWatch Alarms, Insights Queries, Lambda Functions for Data Masking

# CloudWatch Alarms for SES
resource "aws_cloudwatch_metric_alarm" "ses_send_failure" {
  alarm_name          = "${var.project_code}-${var.environment}-ses-send-failure"
  alarm_description   = "SES Send Success Rate is below 95%"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "SendSuccessRate"
  namespace           = "${var.project_code}/${var.environment}/SES"
  period              = 300
  statistic           = "Average"
  threshold           = 95
  treat_missing_data  = "breaching"

  alarm_actions = [var.notification_topic_arn]
  ok_actions    = [var.notification_topic_arn]

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-ses-send-failure"
  })
}

resource "aws_cloudwatch_metric_alarm" "ses_bounce_rate" {
  alarm_name          = "${var.project_code}-${var.environment}-ses-bounce-rate"
  alarm_description   = "SES Bounce Rate is above 5%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BounceRate"
  namespace           = "${var.project_code}/${var.environment}/SES"
  period              = 300
  statistic           = "Average"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.notification_topic_arn]

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-ses-bounce-rate"
  })
}

resource "aws_cloudwatch_metric_alarm" "ses_complaint_rate" {
  alarm_name          = "${var.project_code}-${var.environment}-ses-complaint-rate"
  alarm_description   = "SES Complaint Rate is above 0.1%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ComplaintRate"
  namespace           = "${var.project_code}/${var.environment}/SES"
  period              = 300
  statistic           = "Average"
  threshold           = 0.1
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.notification_topic_arn]

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-ses-complaint-rate"
  })
}

# CloudWatch Composite Alarm
resource "aws_cloudwatch_composite_alarm" "ses_composite" {
  alarm_name = "${var.project_code}-${var.environment}-ses-composite"
  alarm_description = "Composite alarm for SES health"
  alarm_rule = "ALARM(${aws_cloudwatch_metric_alarm.ses_send_failure.alarm_name}) OR ALARM(${aws_cloudwatch_metric_alarm.ses_bounce_rate.alarm_name}) OR ALARM(${aws_cloudwatch_metric_alarm.ses_complaint_rate.alarm_name})"

  alarm_actions = [var.notification_topic_arn]
  ok_actions    = [var.notification_topic_arn]

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-ses-composite"
  })
}

# CloudWatch Log Group for Application Logs
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/application/${var.project_code}/${var.environment}"
  retention_in_days = var.retention_days

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-application-logs"
  })
}

# CloudWatch Log Stream for Application Logs
resource "aws_cloudwatch_log_stream" "application" {
  name           = "${var.project_code}-${var.environment}-application-stream"
  log_group_name = aws_cloudwatch_log_group.application.name
}

# CloudWatch Metric Filter for Application Errors
resource "aws_cloudwatch_log_metric_filter" "application_errors" {
  name           = "${var.project_code}-${var.environment}-application-errors"
  pattern        = "ERROR"
  log_group_name = aws_cloudwatch_log_group.application.name

  metric_transformation {
    name          = "ApplicationErrors"
    namespace     = "${var.project_code}/${var.environment}/Application"
    value         = "1"
    default_value = "0"
  }
}

# CloudWatch Alarm for Application Errors
resource "aws_cloudwatch_metric_alarm" "application_errors" {
  alarm_name          = "${var.project_code}-${var.environment}-application-errors"
  alarm_description   = "Application Error Rate is above threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApplicationErrors"
  namespace           = "${var.project_code}/${var.environment}/Application"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.notification_topic_arn]

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-application-errors"
  })
}

# CloudWatch Insights Query for SES Analysis (Admin View)
resource "aws_cloudwatch_query_definition" "ses_analysis_admin" {
  name = "${var.project_code}-${var.environment}-ses-analysis-admin"

  log_group_names = [var.ses_log_group_name]

  query_string = <<EOF
fields @timestamp, eventType, destination, bounce.bounceType, complaint.complaintFeedbackType, sourceIp
| filter eventType = "bounce" or eventType = "complaint"
| stats count() by eventType
| sort @timestamp desc
EOF
}

# CloudWatch Insights Query for SES Analysis (Masked View)
resource "aws_cloudwatch_query_definition" "ses_analysis_masked" {
  name = "${var.project_code}-${var.environment}-ses-analysis-masked"

  log_group_names = [var.ses_log_group_name]

  query_string = <<EOF
fields @timestamp, eventType, 
  # メールアドレスマスキング: 最初の1文字のみ表示、残りは***でマスク
  case 
    when isPresent(destination) and destination like "%@%" then concat(substring(destination, 0, 1), "***@***.***")
    else "***@***.***"
  end as maskedDestination,
  bounce.bounceType, complaint.complaintFeedbackType,
  # IPアドレスマスキング: 最初のオクテットのみ表示、残りは.*.*.*でマスク
  case 
    when isPresent(sourceIp) and sourceIp like "%.%.%.%" then concat(substring(sourceIp, 0, indexOf(sourceIp, ".")), ".*.*.*")
    else "***.*.*.*"
  end as maskedSourceIp
| filter eventType = "bounce" or eventType = "complaint"
| stats count() by eventType
| sort @timestamp desc
EOF
}

# Lambda Function for Custom Metrics
resource "aws_lambda_function" "custom_metrics" {
  filename         = data.archive_file.custom_metrics_zip.output_path
  function_name    = "${var.project_code}-${var.environment}-custom-metrics"
  role            = aws_iam_role.custom_metrics.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      PROJECT_CODE = var.project_code
      ENVIRONMENT = var.environment
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-custom-metrics"
  })
}

# Lambda Function for Data Masking
resource "aws_lambda_function" "data_masking" {
  filename         = data.archive_file.data_masking_zip.output_path
  function_name    = "${var.project_code}-${var.environment}-data-masking"
  role            = aws_iam_role.data_masking.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      PROJECT_CODE = var.project_code
      ENVIRONMENT = var.environment
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-data-masking"
  })
}

# Data archive for Custom Metrics Lambda
data "archive_file" "custom_metrics_zip" {
  type        = "zip"
  output_path = "${path.module}/custom_metrics.zip"
  source {
    content = file("${path.module}/custom_metrics.py")
    filename = "index.py"
  }
}

# Data archive for Data Masking Lambda
data "archive_file" "data_masking_zip" {
  type        = "zip"
  output_path = "${path.module}/data_masking.zip"
  source {
    content = file("${path.module}/data_masking.py")
    filename = "index.py"
  }
}

# CloudWatch Event Rule for Custom Metrics
resource "aws_cloudwatch_event_rule" "custom_metrics_schedule" {
  name                = "${var.project_code}-${var.environment}-custom-metrics-schedule"
  description         = "Schedule for custom metrics collection"
  schedule_expression = "rate(5 minutes)"
}

# CloudWatch Event Target for Custom Metrics
resource "aws_cloudwatch_event_target" "custom_metrics" {
  rule      = aws_cloudwatch_event_rule.custom_metrics_schedule.name
  target_id = "CustomMetricsTarget"
  arn       = aws_lambda_function.custom_metrics.arn
}

# Lambda Permission for CloudWatch Events
resource "aws_lambda_permission" "custom_metrics" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.custom_metrics.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.custom_metrics_schedule.arn
}
