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

# --- Individual Variables (Reverted) ---

variable "s3_artifact_bucket" {
  description = "Name of S3 bucket to store Canary artifacts. Provide an empty string to have one created."
  type        = string
}

variable "code_source" {
  description = "The source of the canary script code. One of 'TEMPLATE', 'S3', or 'ZIP_FILE'."
  type        = string
}

variable "code_s3_config" {
  description = "Configuration for the canary script when source is S3. Required if code_source is 'S3'."
  type = object({
    bucket  = string
    key     = string
    version = optional(string)
  })
  default = null

  validation {
    condition     = var.code_source != "S3" || var.code_s3_config != null
    error_message = "If code_source is 'S3', then code_s3_config must be provided."
  }
}

variable "code_zip_file_path" {
  description = "The local path to the canary script zip file. Required if code_source is 'ZIP_FILE'."
  type        = string
  default     = null
}

variable "canary_handler" {
  description = "The handler for the canary script."
  type        = string
}

variable "canary_runtime_version" {
  description = "The runtime version for the canary."
  type        = string
}

variable "failure_retention_period_in_days" {
  description = "The number of days to retain canary artifacts for failed runs."
  type        = number
}

variable "success_retention_period_in_days" {
  description = "The number of days to retain canary artifacts for successful runs."
  type        = number
}


# --- Grouped Variables (Kept) ---

variable "run_config" {
  description = "Configuration for the canary's runtime behavior."
  type = object({
    timeout_in_seconds = optional(number, 60)
    memory_in_mb       = optional(number, 1024)
    active_tracing     = optional(bool, false)
    environment        = optional(map(string), {})
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
