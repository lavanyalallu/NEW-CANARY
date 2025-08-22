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
  s3_artifact_bucket               = ""
  code_source                      = "TEMPLATE" # This is now a required variable
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
