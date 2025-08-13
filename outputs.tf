# One output per resource - exposing the entire resource object

output "synthetics_canary" {
  description = "Complete AWS Synthetics Canary resource"
  value       = aws_synthetics_canary.canary
}

output "iam_role" {
  description = "Complete IAM role resource for canaries"
  value       = aws_iam_role.canary_role
}

output "iam_policy" {
  description = "Complete IAM policy resource for canaries"
  value       = aws_iam_policy.canary_policy
}

output "iam_role_policy_attachment" {
  description = "Complete IAM role policy attachment resource"
  value       = aws_iam_role_policy_attachment.canary_role_policy
}

output "s3_object" {
  description = "Complete S3 object resources for canary zip files"
  value       = aws_s3_object.canary_zip
}

output "archive_file" {
  description = "Complete archive file data source"
  value       = data.archive_file.canary_archive_file
}

output "s3_bucket" {
  description = "Complete S3 bucket resource (if created by module)"
  value       = var.s3_artifact_bucket != "" ? null : module.canary_s3[0]
}

# Additional outputs needed by examples
output "artifact_bucket_name" {
  description = "Name of the S3 bucket used for storing Canary artifacts"
  value       = local.artifact_bucket_name
}

output "bucket_created_by_module" {
  description = "Whether the S3 bucket was created by this module"
  value       = var.s3_artifact_bucket == ""
}

output "canary_names" {
  description = "Names of all created canaries"
  value       = [for k, v in aws_synthetics_canary.canary : v.name]
}

output "canary_arns" {
  description = "ARNs of all created canaries"
  value       = [for k, v in aws_synthetics_canary.canary : v.arn]
}

output "canary_endpoints" {
  description = "Map of canary names to their monitored endpoints"
  value       = var.endpoints
}

output "module_metadata" {
  description = "General metadata about the canary module"
  value = {
    name           = local.name
    namespace      = local.namespace
    region         = local.region
    account_id     = local.account_id
    canary_count   = length(var.endpoints)
    tags           = var.tags
  }
}
