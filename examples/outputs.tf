output "s3_bucket_info" {
  description = "S3 bucket information"
  value       = module.canaries.s3_bucket
}

output "s3_objects" {
  description = "S3 objects created for canary zip files"
  value       = module.canaries.s3_object
}

# Canary Information - using existing root outputs
output "canary_resources" {
  description = "Complete canary resources"
  value       = module.canaries.synthetics_canary
}

output "canary_names" {
  description = "Names of all canaries"
  value       = [for k, v in module.canaries.synthetics_canary : v.name]
}

output "canary_arns" {
  description = "ARNs of all canaries"
  value       = [for k, v in module.canaries.synthetics_canary : v.arn]
}

# IAM Information
output "iam_role_info" {
  description = "IAM role used by canaries"
  value       = module.canaries.iam_role
}

output "iam_policy_info" {
  description = "IAM policy used by canaries"
  value       = module.canaries.iam_policy
}

# Archive Information
output "archive_files" {
  description = "Archive files created for canaries"
  value       = module.canaries.archive_file
}

output "synthetics_canary" {
  description = "The canary resources created by the module, used for testing."
  value       = module.canaries.synthetics_canary
}

output "synthetics_group" {
  description = "The synthetics group resource created by the module, used for testing."
  value       = module.canaries.synthetics_group
}

output "iam_role" {
  description = "The IAM role resource created by the module, used for testing."
  value       = module.canaries.iam_role
}

output "s3_bucket" {
  description = "The S3 bucket resource created by the module, used for testing."
  value       = module.canaries.s3_bucket
}

output "artifact_bucket_name" {
  description = "The name of the S3 artifact bucket."
  value       = module.canaries.artifact_bucket_name
}

output "bucket_created_by_module" {
  description = "Flag indicating if the S3 bucket was created by the module."
  value       = module.canaries.bucket_created_by_module
}

output "canary_arns" {
  description = "A list of the created canary ARNs."
  value       = module.canaries.canary_arns
}

output "module_metadata" {
  description = "General metadata about the module deployment."
  value       = module.canaries.module_metadata
}

output "synthetics_group_info" {
  description = "Information about the created Synthetics Group."
  value       = module.canaries.synthetics_group
}

output "synthetics_group_associations" {
  description = "The associations created between the canaries and the group."
  value       = module.canaries.synthetics_group_association
}
