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
  canary_timeout_in_seconds = 90
  canary_memory_in_mb       = 2048
  canary_active_tracing     = true
  canary_environment_variables = {
    LOG_LEVEL = "INFO"
    API_KEY   = "some-secret-value" # For production, consider using AWS Secrets Manager
  }

  # Don't provide s3_artifact_bucket - let root module create one
  s3_artifact_bucket  = ""

  endpoints = {
    homepage = { url = "https://example.com" }
    api      = { url = "https://api.example.com/health" }
  }

  subnet_ids         = []
  security_group_ids = []
}

# --- Example using S3 code source ---
module "canaries_from_s3" {
  source = "../.."

  name                = "example-canary-from-s3"
  namespace           = "example"
  schedule_expression = "rate(15 minutes)"
  
  code_source    = "S3"
  code_s3_bucket = "my-existing-canary-scripts-bucket"
  code_s3_key    = "scripts/my-custom-canary.zip"

  # Endpoints map is still required for the for_each loop, but the content is not used for code generation.
  endpoints = {
    s3_canary = { url = "placeholder" }
  }
}

# --- Example using a local ZIP_FILE code source ---
module "canaries_from_zip" {
  source = "../.."

  name                = "example-canary-from-zip"
  namespace           = "example"
  schedule_expression = "rate(15 minutes)"
  
  code_source        = "ZIP_FILE"
  code_zip_file_path = "./canary_scripts/custom_script.zip" # A path to a zip file in your project

  endpoints = {
    zip_canary = { url = "placeholder" }
  }
}

