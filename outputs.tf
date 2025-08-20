# One output per resource - exposing the entire resource object



output "s3_bucket" {
  description = "The complete S3 bucket resource, only if it was created by this module."
  value       = var.s3_artifact_bucket != "" ? null : module.canary_s3[0]
}

output "synthetics_group" {
  description = "The complete AWS Synthetics Group resource, only if it was created."
  value       = var.create_synthetics_group ? aws_synthetics_group.this[0] : null
}

output "synthetics_group_association" {
  description = "Map of the associations between the canaries and the synthetics group."
  value       = aws_synthetics_group_association.this
}

# --- Data Source and Metadata Outputs ---
# These are useful for testing and do not represent created resources.

output "archive_file" {
  description = "The complete archive file data source, used for canaries with inline code."
  value       = data.archive_file.canary_archive_file
}

output "module_metadata" {
  description = "General metadata about the module deployment for validation."
  value = {
    name                     = local.name
    namespace                = var.namespace
    region                   = local.region
    account_id               = local.account_id
    tags                     = var.tags
    artifact_bucket_name     = local.artifact_bucket_name
    bucket_created_by_module = var.s3_artifact_bucket == ""
  }
}
output "synthetics_canary" {
  description = "Map of all created AWS Synthetics Canary resources."
  value       = aws_synthetics_canary.canary
}
