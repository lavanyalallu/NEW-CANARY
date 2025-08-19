data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name       = var.name
  namespace  = var.namespace
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  group_name = var.synthetics_group_name != "" ? var.synthetics_group_name : local.name
}

locals {
  # FIX: Only generate file content if the code source is TEMPLATE.
  file_content = { for k, v in var.endpoints :
    k => var.code_source == "TEMPLATE" ? templatefile("${path.module}/canary-lambda.js.tpl", { endpoint = v.url }) : ""
  }
}

module "canary_s3" {
  source = "test.com"
  count  = var.s3_artifact_bucket != "" ? 0 : 1

  name      = local.name
  namespace = var.namespace
}

locals {
  artifact_bucket_name = var.s3_artifact_bucket != "" ? var.s3_artifact_bucket : module.canary_s3[0].name
}

data "archive_file" "canary_archive_file" {
  # FIX: Only create an archive file if the code source is TEMPLATE.
  for_each       = { for k, v in var.endpoints : k => v if var.code_source == "TEMPLATE" }
  type           = "zip"
  source_content = local.file_content[each.key]
  output_path    = "/tmp/${each.key}_${md5(local.file_content[each.key])}.zip"
}

resource "aws_synthetics_canary" "canary" {
  for_each = var.endpoints

  name                             = each.key
  artifact_s3_location             = "s3://${local.artifact_bucket_name}/${each.key}"
  execution_role_arn               = aws_iam_role.canary_role.arn
  handler                          = var.canary_handler
  runtime_version                  = var.canary_runtime_version
  failure_retention_period_in_days = var.failure_retention_period_in_days
  success_retention_period_in_days = var.success_retention_period_in_days
  start_canary                     = var.start_canary

  # Conditionally set the code source
  s3_bucket   = var.code_source == "S3" ? var.code_s3_bucket : null
  s3_key      = var.code_source == "S3" ? var.code_s3_key : null
  s3_version  = var.code_source == "S3" ? var.code_s3_version : null
  zip_file    = var.code_source == "TEMPLATE" ? data.archive_file.canary_archive_file[each.key].output_path : (var.code_source == "ZIP_FILE" ? var.code_zip_file_path : null)

  run_config {
    timeout_in_seconds = var.canary_timeout_in_seconds
    memory_in_mb       = var.canary_memory_in_mb
    active_tracing     = var.canary_active_tracing
  }

  schedule {
    expression = var.schedule_expression
  }

  dynamic "vpc_config" {
    # Only create this block if subnet_ids are provided.
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }


  tags = var.tags

  depends_on = [
    data.archive_file.canary_archive_file,
    aws_iam_role.canary_role,
    aws_iam_policy.canary_policy,
    module.canary_s3
  ]
}

# Upload canary zip files to S3
resource "aws_s3_object" "canary_zip" {
  # FIX: Only create an S3 object if the code source is TEMPLATE.
  for_each = { for k, v in var.endpoints : k => v if var.code_source == "TEMPLATE" }

  bucket = local.artifact_bucket_name
  key    = "${each.key}/canary.zip"
  source = data.archive_file.canary_archive_file[each.key].output_path
  etag   = data.archive_file.canary_archive_file[each.key].output_md5

  depends_on = [
    module.canary_s3,
    data.archive_file.canary_archive_file
  ]
}
data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    sid    = "AllowCloudWatchSyntheticsAccess"
    effect  = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.canary_role.arn]
    }
    actions   = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [
      "${module.canary_s3[0].bucket.arn}",
      "${module.canary_s3[0].bucket.arn}/*"
    ]
  }
}
resource "aws_synthetics_group" "this" {
  count = var.create_synthetics_group ? 1 : 0
  name  = local.group_name
  tags  = var.tags
}

resource "aws_synthetics_group_association" "this" {
  # Create an association for each canary, but only if group creation is enabled.
  for_each = var.create_synthetics_group ? var.endpoints : {}

  group_name = aws_synthetics_group.this[0].name
  canary_arn = aws_synthetics_canary.canary[each.key].arn
}
module "state" {
  source = "git://github.com/terraform-aws-modules/terraform-aws-state"