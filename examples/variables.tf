variable "success_retention_period_in_days" {
  description = "The number of days to retain data for successful canary runs."
  type        = number
  default     = 7
}

variable "artifact_s3_kms_key_arn" {
  description = "Optional: The ARN of the KMS key to use for encrypting canary artifacts in S3."
  type        = string
  default     = null
}

variable "endpoints" {
  description = "A map of endpoints to monitor. The key is used as a suffix for the canary name."
  type = map(object({
    url          = string
    method        = string
    body          = string
    headers       = map(string)
    auth          = object({
      username = string
      password = string
    })
    expected_response = object({
      status_code = number
      body        = string
      headers     = map(string)
    })
  }))
}