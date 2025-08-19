data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
locals {
  name             = "${var.namespace}-${var.name}"
  group_name       = var.synthetics_group_name != "" ? var.synthetics_group_name : local.name
  artifact_bucket_name = var.s3_artifact_bucket != "" ? var.s3_artifact_bucket : module.canary_s3[0].name
}
locals {
  # FIX: only generate file content if the code source is TEMPLATE
  file_content = { for k, v in var.endpoints :
    k => templatefile("${path.module}/canary-lambda.js.tpl", {
      endpoint = v.url
    }) if var.code_source == "TEMPLATE"
  }
}
module "state" {
  source = "git::https://gitlab.xyz.com/
}
module "canary_s3" {
  count            = var.s3_artifact_bucket == "" ? 1 : 0
  source           = "git::https://gitlab.bbcxyz.com"
  name             = local.name
  namespace        = var.namespace
  policy           = data.aws_iam_policy_document.canary_bucket_policy.json
  data_classification = "restricted"
  force_destroy    = true
}
data "aws_iam_policy_document" "canary_bucket_policy" {
  statement {
    sid    = "AllowCloudwatchSyntheticsAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.canary_access.role_arn]
    }
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [
      "${module.canary_s3[0].bucket_arn}",
      "${module.canary_s3[0].bucket_arn}/*"
    ]
  }
}

// FIX 1: Create a map that will contain the zip file path ONLY for TEMPLATE canaries.
// For other types, the value will be null, preventing invalid references.
locals {
  canary_zip_paths = { for k, v in var.endpoints : k => (
    var.code_source == "TEMPLATE" ? data.archive_file.canary_archive_file[k].output_path : null
  )}
}

data "archive_file" "canary_archive_file" {
  # FIX: Only create archive file if the code source is TEMPLATE
  for_each = { for k, v in var.endpoints : k => v if var.code_source == "TEMPLATE" }
  type        = "zip"
  output_path = "/tmp/${each.key}_${md5(local.file_content[each.key])}.zip"
  source {
    content  = local.file_content[each.key]
    filename = "nodejs/node_modules/pageLoadBlueprint.js"
  }
}
resource "aws_synthetics_canary" "canary" {
  for_each = var.endpoints
  name                 = each.key
  artifact_s3_location = "s3://${local.artifact_bucket_name}/${each.key}"
  execution_role_arn   = module.canary_access.role_arn
  handler              = var.canary_handler
  runtime_version      = var.canary_runtime_version
  schedule {
    expression = var.schedule_expression
  }
  success_retention_period = var.success_retention_period_in_days
  failure_retention_period = var.failure_retention_period_in_days
  run_config {
    timeout_in_seconds  = var.canary_timeout_in_seconds
    memory_in_mb        = var.canary_memory_in_mb
    active_tracing      = var.canary_active_tracing
  }
  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids = var.subnet_ids
    }
  }
  # Optionally set the code source
  s3_bucket  = var.code_source == "S3" ? var.code_s3_bucket : null
  s3_key     = var.code_source == "S3" ? var.code_s3_key : null
  s3_version = var.code_source == "S3" ? var.code_s3_version : null
  
  # FIX 2: Use the safe local map here. This expression no longer contains a direct
  # reference to the data source, breaking the invalid dependency chain.
  zip_file = local.canary_zip_paths[each.key]
}
resource "aws_s3_object" "canary_zip" {
  # Upload canary zip files to S3
  # FIX: Only create an S3 object if the code source is TEMPLATE
  for_each = { for k, v in var.endpoints : k => v if var.code_source == "TEMPLATE" }
  bucket = local.artifact_bucket_name
  key    = "canary.zip"
  source = data.archive_file.canary_archive_file[each.key].output_path
  etag   = data.archive_file.canary_archive_file[each.key].output_md5
  depends_on = [module.canary_s3]
}
resource "aws_synthetics_group" "this" {
  count = var.create_synthetics_group ? 1 : 0
  name = local.group_name
  tags = local.tags
}
resource "aws_synthetics_group_association" "this" {
  # Create an association for each canary, but only if group creation is enabled
  for_each = var.create_synthetics_group ? var.endpoints : {}
  group_name = aws_synthetics_group.this[0].name
  canary_arn = aws_synthetics_canary.canary[each.key].arn
}