variable "name" {
  description = "Name for the canary setup"
  type        = string
}

variable "namespace" {
  description = "Namespace for tagging/naming"
  type        = string
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}

variable "endpoints" {
  description = "Map of endpoints for canary testing"
  type = map(object({
    url = string
  }))
}

variable "schedule_expression" {
  description = "Schedule expression for canary (e.g., 'rate(5 minutes)')"
  type        = string
}

variable "start_canary" {
  description = "Whether to start the canary after creation."
  type        = bool
  default     = true
}

# --- Grouped Variables ---

variable "code_config" {
  description = "Configuration for the canary's execution code."
  type = object({
    handler          = string
    runtime_version  = string
    source           = optional(string, "TEMPLATE")
    s3_bucket        = optional(string)
    s3_key           = optional(string)
    s3_version       = optional(string)
    zip_file_path    = optional(string)
  })

  validation {
    condition     = contains(["TEMPLATE", "S3", "ZIP_FILE"], var.code_config.source)
    error_message = "The code_config.source must be one of 'TEMPLATE', 'S3', or 'ZIP_FILE'."
  }
  validation {
    condition     = var.code_config.source != "S3" || (var.code_config.s3_bucket != null && var.code_config.s3_key != null)
    error_message = "If code_config.source is 'S3', then s3_bucket and s3_key must be provided."
  }
  validation {
    condition     = var.code_config.source != "ZIP_FILE" || var.code_config.zip_file_path != null
    error_message = "If code_config.source is 'ZIP_FILE', then zip_file_path must be provided."
  }
}

variable "run_config" {
  description = "Configuration for the canary's runtime behavior."
  type = object({
    timeout_in_seconds = optional(number, 60)
    memory_in_mb       = optional(number, 1024)
    active_tracing     = optional(bool, false)
    environment        = optional(map(string), {})
  })
}

variable "artifact_config" {
  description = "Configuration for canary artifacts."
  type = object({
    s3_bucket_name                   = optional(string, "")
    success_retention_period_in_days = optional(number, 31)
    failure_retention_period_in_days = optional(number, 31)
  })
}

variable "vpc_config" {
  description = "VPC configuration for the canary. Leave as null to run outside a VPC."
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "group_config" {
  description = "Configuration for associating canaries with a Synthetics Group."
  type = object({
    create_group      = optional(bool, false)
    group_name        = optional(string) # Name of group to create or existing group to use
  })
  default = {
    create_group = false
  }
}
