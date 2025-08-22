# One output per resource - exposing the entire resource object

output "s3_bucket" {
  description = "The complete S3 bucket resource, only if it was created by this module."
  value       = var.s3_artifact_bucket != "" ? null : module.canary_s3[0]
}

output "synthetics_group" {
  description = "The complete AWS Synthetics Group resource, only if it was created."
  # FIX: Updated to use the new grouped variable
  value       = var.group_config.create_group ? aws_synthetics_group.this[0] : null
}

output "synthetics_group_association" {
  description = "Map of the associations between the canaries and the synthetics group."
  value       = aws_synthetics_group_association.this
}

output "synthetics_canary" {
  description = "Map of all created AWS Synthetics Canary resources."
  value       = aws_synthetics_canary.canary
}
