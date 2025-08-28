#Module      : IAM ROLE FOR AWS SYNTHETIC CANARY 
#Description : Terraform module creates IAM Role for Cloudwatch Synthetic canaries on AWS for monitoriing Websites.

resource "aws_iam_policy" "canary_policy" {
  name        = "canary-policy-${local.name}-${local.namespace}"  # Make unique
  description = "Policy for canary"
  policy      = data.aws_iam_policy_document.canary_permissions.json
}

#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "canary_permissions" {
  statement {
    sid = "S3Artifacts"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      # REVERT: Use the local variable, which is now safe as the var is never null.
      "arn:aws:s3:::${local.artifact_bucket_name}/*",
      "arn:aws:s3:::${local.artifact_bucket_name}"
    ]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect  = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:CreateLogGroup"
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:/aws/lambda/cwsyn-*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:ListAllMyBuckets",
      "xray:PutTraceSegments"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    effect = "Allow"
    resources = [
      "*"
    ]
    actions = [
      "cloudwatch:PutMetricData"
    ]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values = [
        "CloudWatchSynthetics"
      ]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role" "canary_role" {
  name               = "CloudWatchSyntheticsRole-${local.name}-${local.namespace}"  # Make unique
  assume_role_policy = data.aws_iam_policy_document.canary_assume_role.json
}

data "aws_iam_policy_document" "canary_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "canary_role_policy" {
  role       = aws_iam_role.canary_role.name
  policy_arn = aws_iam_policy.canary_policy.arn
}