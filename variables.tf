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

variable "schedule_expression" {
  description = "Schedule expression for canary"
  type        = string

  validation {
    condition     = can(regex("^(rate|cron)\\(.+\\)$", var.schedule_expression))
    error_message = "The schedule_expression must be a valid rate() or cron() expression."
  }
}

variable "endpoints" {
  description = "Map of endpoints for canary testing"
  type = map(object({
    url = string
  }))

  validation {
    condition     = length(var.endpoints) > 0
    error_message = "The endpoints map cannot be empty."
  }
}

variable "subnet_ids" {
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  type        = list(string)
  default     = []
}

variable "s3_artifact_bucket" {
  description = "Name of S3 bucket to store Canary artifacts. If empty, one will be created."
  type        = string
  default     = ""
}

variable "canary_handler" {
  description = "The handler for the canary script."
  type        = string
  default     = "pageLoadBlueprint.handler"

  validation {
    condition     = can(regex("^.+\\..+$", var.canary_handler))
    error_message = "The canary_handler must be in the format 'filename.handler'."
  }
}

variable "canary_runtime_version" {
  description = "The runtime version for the canary."
  type        = string
  default     = "syn-nodejs-puppeteer-6.1"

  validation {
    condition     = substr(var.canary_runtime_version, 0, 4) == "syn-"
    error_message = "The canary_runtime_version must start with 'syn-'."
  }
}

variable "start_canary" {
  description = "Whether to start the canary after creation."
  type        = bool
  default     = true
}

variable "failure_retention_period_in_days" {
  description = "The number of days to retain canary artifacts for failed runs (1-455)."
  type        = number
  default     = 31
  validation {
    condition     = var.failure_retention_period_in_days >= 1 && var.failure_retention_period_in_days <= 455
    error_message = "The failure_retention_period_in_days must be between 1 and 455."
  }
}

variable "success_retention_period_in_days" {
  description = "The number of days to retain canary artifacts for successful runs (1-455)."
  type        = number
  default     = 31
  validation {
    condition     = var.success_retention_period_in_days >= 1 && var.success_retention_period_in_days <= 455
    error_message = "The success_retention_period_in_days must be between 1 and 455."
  }
}

variable "canary_memory_in_mb" {
  description = "The memory in MB to allocate for a canary run."
  type        = number
  default     = 960
  validation {
    condition     = var.canary_memory_in_mb >= 960 && (var.canary_memory_in_mb - 960) % 1024 == 0 || var.canary_memory_in_mb == 2048
    error_message = "Valid memory values for Puppeteer runtimes are 960, 2048, 3008, etc."
  }
}

variable "canary_active_tracing" {
  description = "Set to true to enable active X-Ray tracing."
  type        = bool
  default     = false
}

variable "canary_timeout_in_seconds" {
  description = "How long the canary can run before it is stopped (3-840 seconds)."
  type        = number
  default     = 60
  validation {
    condition     = var.canary_timeout_in_seconds >= 3 && var.canary_timeout_in_seconds <= 840
    error_message = "The timeout must be between 3 and 840 seconds."
  }
}
variable "create_synthetics_group" {
  description = "Set to true to create a CloudWatch Synthetics Group and associate canaries with it."
  type        = bool
  default     = false
}

variable "synthetics_group_name" {
  description = "The name for the CloudWatch Synthetics Group. If not provided, it defaults to the module's 'name' variable."
  type        = string
  default     = ""
}
