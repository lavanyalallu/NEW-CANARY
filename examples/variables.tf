variable "success_retention_period_in_days" {
  description = "The number of days to retain data for successful canary runs."
  type        = number
  default     = 7
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