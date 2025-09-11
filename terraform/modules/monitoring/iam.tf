# IAM Roles and Policies for Monitoring Module

# IAM Role for Custom Metrics Lambda
resource "aws_iam_role" "custom_metrics" {
  name = "${var.project_code}-${var.environment}-custom-metrics-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-custom-metrics-role"
  })
}

# IAM Role Policy Attachment for Custom Metrics Lambda
resource "aws_iam_role_policy_attachment" "custom_metrics_basic" {
  role       = aws_iam_role.custom_metrics.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy for Custom Metrics Lambda
resource "aws_iam_policy" "custom_metrics" {
  name        = "${var.project_code}-${var.environment}-custom-metrics-policy"
  description = "Policy for Custom Metrics Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:GetSendStatistics",
          "ses:GetSendQuota",
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role Policy Attachment for Custom Metrics
resource "aws_iam_role_policy_attachment" "custom_metrics" {
  role       = aws_iam_role.custom_metrics.name
  policy_arn = aws_iam_policy.custom_metrics.arn
}

# IAM Role for Data Masking Lambda
resource "aws_iam_role" "data_masking" {
  name = "${var.project_code}-${var.environment}-data-masking-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_code}-${var.environment}-data-masking-role"
  })
}

# IAM Role Policy Attachment for Data Masking Lambda
resource "aws_iam_role_policy_attachment" "data_masking_basic" {
  role       = aws_iam_role.data_masking.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy for Data Masking Lambda
resource "aws_iam_policy" "data_masking" {
  name        = "${var.project_code}-${var.environment}-data-masking-policy"
  description = "Policy for Data Masking Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:FilterLogEvents",
          "iam:GetUser",
          "iam:GetUserPolicy",
          "iam:ListGroupsForUser"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role Policy Attachment for Data Masking
resource "aws_iam_role_policy_attachment" "data_masking" {
  role       = aws_iam_role.data_masking.name
  policy_arn = aws_iam_policy.data_masking.arn
}
