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

  # Don't provide s3_artifact_bucket - let root module create one
  s3_artifact_bucket  = ""

  endpoints = {
    homepage = { url = "https://example.com" }
    api      = { url = "https://api.example.com/health" }
  }

  subnet_ids         = []
  security_group_ids = []
}

# --- Example 1: Canary without a VPC ---
# This canary will run in the AWS-managed environment.
module "canaries_no_vpc" {
  source = "../.."

  name                = "example-canary-no-vpc"
  namespace           = "example"
  tags                = { Environment = "dev", Type = "no-vpc" }
  schedule_expression = "rate(5 minutes)"
  
  # No subnet_ids or security_group_ids are provided.
  # The root module will automatically skip the vpc_config block.
  
  endpoints = {
    homepage = { url = "https://example.com" }
  }
}


# --- Example 2: Canary inside a VPC sourced from a state module ---

# This is your state module that provides VPC information.
# (You would configure this to point to your actual state backend)
module "vpc_state" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.2"
  # This is just an example; you would configure this module
  # to read from your actual remote state.
  name = "example-vpc"
  cidr = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
}

# This canary will be deployed into the subnets provided by the state module.
module "canaries_with_vpc" {
  source = "../.."

  name                = "example-canary-with-vpc"
  namespace           = "example"
  tags                = { Environment = "dev", Type = "with-vpc" }
  schedule_expression = "rate(10 minutes)"

  # Provide the subnet and security group IDs from the state module.
  subnet_ids         = module.vpc_state.private_subnets
  security_group_ids = [module.vpc_state.default_security_group_id]

  endpoints = {
    internal_api = { url = "http://internal-service.example.local" }
  }
}

