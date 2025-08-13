module "canaries" {
  source = "../.."

  name                = "example-canary"
  namespace           = "example"
  tags                = { 
    Environment = "dev"
    Purpose     = "website-monitoring"
    Owner       = "platform-team"
  }
  schedule_expression = "rate(5 minutes)"
  canary_handler            = "pageLoadBlueprint.handler"
  canary_runtime_version    = "syn-nodejs-puppeteer-6.1"
  create_synthetics_group = true
  synthetics_group_name   = "example-website-monitors"
  failure_retention_period_in_days = 14
  success_retention_period_in_days = 7
  start_canary              = true
  canary_timeout_in_seconds = 60
  canary_timeout_in_seconds = 90
  canary_memory_in_mb       = 2048
  canary_active_tracing     = true

  # Don't provide s3_artifact_bucket - let root module create one
  s3_artifact_bucket  = ""

  endpoints = {
    homepage = { url = "https://example.com" }
    api      = { url = "https://api.example.com/health" }
  }

  subnet_ids         = []
  security_group_ids = []
}

