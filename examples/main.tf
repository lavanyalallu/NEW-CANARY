module "canaries" {
  source    = "../"
  name      = "canary"
  namespace = module.namespace.short
  tags      = module.namespace.tags

  # --- Individual Variables ---
  schedule_expression              = var.schedule_expression
  canary_handler                   = "pageLoadBlueprint.handler"
  canary_runtime_version           = "syn-nodejs-puppeteer-6.2"
  start_canary                     = true
  s3_artifact_bucket               = "" # REVERT: Explicitly pass an empty string to create a bucket.
  code_source                      = "TEMPLATE"
  failure_retention_period_in_days = 14
  success_retention_period_in_days = 7
  endpoints                        = var.endpoints

  # --- Grouped Variables ---
  run_config = {
    timeout_in_seconds = 60
    memory_in_mb       = 2048
    active_tracing     = true
    environment = {
      LOG_LEVEL = "INFO"
    }
  }

  group_config = {
    create_group = true
    group_name   = "monitor"
  }

  # Set to null to run outside a VPC, or provide the object to run inside.
  vpc_config = null
}

# --- Example for Page Load Canaries ---
module "page_load_canaries" {
  source    = "../"
  name      = "page-load-canary"
  namespace = module.namespace.short
  tags      = module.namespace.tags

  # --- Individual Variables ---
  schedule_expression              = var.schedule_expression
  canary_handler                   = "pageLoadBlueprint.handler"
  canary_runtime_version           = "syn-nodejs-puppeteer-6.2"
  start_canary                     = true
  s3_artifact_bucket               = "" # Create a new bucket
  code_source                      = "TEMPLATE"
  blueprint_type                   = "page_load" # Explicitly set for clarity
  failure_retention_period_in_days = 14
  success_retention_period_in_days = 7
  endpoints                        = var.page_load_endpoints

  # --- Grouped Variables ---
  run_config = {
    timeout_in_seconds = 60
    memory_in_mb       = 2048
    active_tracing     = true
  }
  vpc_config = null
}

# --- Example for API Canaries ---
module "api_canaries" {
  source    = "../"
  name      = "api-canary"
  namespace = module.namespace.short
  tags      = module.namespace.tags

  schedule_expression              = "rate(10 minutes)"
  canary_runtime_version           = "syn-nodejs-puppeteer-6.2"
  start_canary                     = true
  s3_artifact_bucket               = "" # Create another new bucket
  code_source                      = "TEMPLATE"
  blueprint_type                   = "api_request" # Use the new API blueprint
  failure_retention_period_in_days = 14
  success_retention_period_in_days = 7
  endpoints                        = var.api_endpoints

  run_config = {
    timeout_in_seconds = 30
    memory_in_mb       = 1024
  }
  vpc_config = null
}

# --- Example for Heartbeat Canary ---
module "heartbeat_canary" {
  source    = "../"
  name      = "batch-job-monitor"
  namespace = module.namespace.short
  tags      = module.namespace.tags

  schedule_expression    = "cron(0 12 * * ? *)" # e.g., run once a day at noon
  canary_runtime_version = "syn-nodejs-puppeteer-6.2"
  s3_artifact_bucket     = ""
  code_source            = "TEMPLATE"
  blueprint_type         = "heartbeat" # Use the new heartbeat blueprint

  # For heartbeats, the key is the name and the value is ignored.
  endpoints = {
    "daily-report-job" = {}
  }

  run_config = {
    timeout_in_seconds = 60
  }
}
