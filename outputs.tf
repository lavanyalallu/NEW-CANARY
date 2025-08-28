# One output per resource - exposing the entire resource object

output "s3_bucket" {
  description = "The complete S3 bucket resource, only if it was created by this module."
  value       = (var.s3_artifact_bucket == "" || var.s3_artifact_bucket == null) && length(module.canary_s3) > 0 ? { bucket = module.canary_s3[0] } : null
}

output "synthetics_group_association" {
  description = "Map of the associations between the canaries and the synthetics group."
  value       = aws_synthetics_group_association.this
}

output "synthetics_canary" {
  description = "Map of all created AWS Synthetics Canary resources."
  value       = aws_synthetics_canary.canary
}

output "debug_s3_artifact_bucket_value" {
  description = "Debug output to check the value of s3_artifact_bucket"
  value       = var.s3_artifact_bucket
}

output "debug_canary_s3_length" {
  description = "Debug output to check if the S3 bucket is being created"
  value       = length(module.canary_s3)
}

output "debug_canary_s3_first" {
  description = "Debug output to see module.canary_s3[0] value"
  value       = length(module.canary_s3) > 0 ? module.canary_s3[0] : null
}