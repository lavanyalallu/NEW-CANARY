output "s3_bucket" {
  description = "The S3 bucket resource created by the module."
  value       = module.canaries.s3_bucket
}

output "synthetics_group" {
  description = "The synthetics group resource created by the module."
  value       = module.canaries.synthetics_group
}

output "synthetics_group_association" {
  description = "The associations created between the canaries and the group."
  value       = module.canaries.synthetics_group_association
}

output "synthetics_group_name" {
  description = "The name of the Synthetics Group created in the example."
  value       = aws_synthetics_group.example.name
}

output "synthetics_canary" {
  description = "Map of the canaries created by the module."
  value       = module.canaries.synthetics_canary
}

