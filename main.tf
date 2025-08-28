data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name       = var.name
  namespace  = var.namespace
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

locals {
  # Conditionally select the template file based on the chosen blueprint
  template_file_path = var.blueprint_type == "api_request" ? "${path.module}/canary-api.js.tpl" : (var.blueprint_type == "heartbeat" ? "${path.module}/canary-heartbeat.js.tpl" : "${path.module}/canary-lambda.js.tpl")

  # This creates a map containing content only for canaries using the TEMPLATE method.
  file_content = { for k, v in var.endpoints : k => templatefile(local.template_file_path, {
    # Pass the full endpoint object as a JSON string for the API template
    endpoint_json = jsonencode(v),
    # Pass just the URL for the page load template
    endpoint      = v.url
  }) if var.code_source == "TEMPLATE" }
}
locals {
  artifact_bucket_name = lower(
    var.s3_artifact_bucket != null ? var.s3_artifact_bucket :
    (length(module.canary_s3) > 0 ? module.canary_s3[0].name : "")
  )
}
module "canary_s3" {
  source = "test.com"
  # FIX: Create a bucket only if the variable is null.
  #count  = var.s3_artifact_bucket == null ? 1 : 0
  count     = var.s3_artifact_bucket == "" || var.s3_artifact_bucket == null ? 1 : 0
  bucket_policy = data.aws_iam_policy_document.canary_bucket_policy.json

  # REVERT: Use the shorter 'namespace' for the bucket name to avoid exceeding the API's length limit.
  name      = var.namespace
  namespace = var.namespace
}
data "aws_iam_policy_document" "canary_bucket_policy" {
  count = var.s3_artifact_bucket == "" || var.s3_artifact_bucket == null ? 1 : 0
  statement {
    sid    = "AllowCloudWatchSyntheticsAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [module.canary_access.role.arn]
    }

    actions = [
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


# locals {
#   # FIX: This local now correctly and safely determines the bucket name.
#   # It checks if a bucket name was provided. If not, it uses the name of the bucket created by the module.
#   # This avoids the invalid index error by removing the direct dependency on the module's output.
#   artifact_bucket_name = lower(var.s3_artifact_bucket != null ? var.s3_artifact_bucket : module.canary_s3[0].name)
# }




data "archive_file" "canary_archive_file" {
  # Only create an archive file if the code source is TEMPLATE.
  for_each       = { for k, v in var.endpoints : k => v if var.code_source == "TEMPLATE" }
  type           = "zip"
  source {
    content  = local.file_content[each.key]
    # FIX: The filename must match the handler for the selected blueprint.
    filename = "nodejs/node_modules/${var.blueprint_type == "api_request" ? "canary-api.js" : (var.blueprint_type == "heartbeat" ? "canary-heartbeat.js" : "canary-lambda.js")}"
  }
  output_path = "/tmp/${each.key}_${md5(local.file_content[each.key])}.zip"
}


resource "aws_synthetics_canary" "canary" {
  for_each = var.endpoints

  name                             = "${local.name}-${each.key}"
  artifact_s3_location             = "s3://${local.artifact_bucket_name}/${each.key}/"
  execution_role_arn               = aws_iam_role.canary_role.arn
  handler                          = var.blueprint_type == "api_request" ? "canary-api.handler" : (var.blueprint_type == "heartbeat" ? "canary-heartbeat.handler" : var.canary_handler)
  runtime_version                  = var.canary_runtime_version
  failure_retention_period_in_days = var.failure_retention_period_in_days
  success_retention_period_in_days = var.success_retention_period_in_days
  start_canary                     = var.start_canary

  # Conditionally set the code source
  s3_bucket   = var.code_source == "S3" ? var.code_s3_config.bucket : null
  s3_key      = var.code_source == "S3" ? var.code_s3_config.key : null
  s3_version  = var.code_source == "S3" ? var.code_s3_config.version : null
  zip_file    = var.code_source == "TEMPLATE" ? data.archive_file.canary_archive_file[each.key].output_path : (var.code_source == "ZIP_FILE" ? var.code_zip_file_path : null)

  # FIX: Use a static block to always apply KMS encryption from the state module.
  artifact_config {
    s3_encryption {
      encryption_mode = "SSE_KMS"
      kms_key_arn     = module.state.kms.this_region_arn
    }
  }

  run_config {
    timeout_in_seconds    = var.run_config.timeout_in_seconds
    memory_in_mb          = var.run_config.memory_in_mb
    active_tracing        = var.run_config.active_tracing
    environment_variables = var.run_config.environment
  }

  schedule {
    expression = var.schedule_expression
  }

  dynamic "vpc_config" {
    # Only create this block if vpc_config is provided.
    for_each = var.vpc_config != null ? [1] : []
    content {
      subnet_ids         = var.vpc_config.subnet_ids
      security_group_ids = var.vpc_config.security_group_ids
    }
  }

  tags = var.tags
}

# resource "aws_iam_role" "canary_role" {
#   name = "${local.name}-role"
#   assume_role_policy = jsonencode({
#     Version   = "2012-10-17"
#     Statement = [
#       {
#         Action    = "sts:AssumeRole"
#         Effect    = "Allow"
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#       }
#     ]
#   })
#   tags = var.tags
# }


resource "aws_synthetics_group_association" "this" {
  # FIX: Simplified logic. Create an association for each canary if a group_name is provided.
  for_each = var.group_name != null ? var.endpoints : {}
module "state" {
  group_name = var.group_nameterraform-aws-modules/terraform-aws-state"
  canary_arn = aws_synthetics_canary.canary[each.key].arn}module "state" {  source = "git://github.com/terraform-aws-modules/terraform-aws-state"  }


