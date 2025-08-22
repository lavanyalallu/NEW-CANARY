## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name for the canary setup. | `string` | n/a | yes |
| namespace | Namespace for tagging/naming. | `string` | n/a | yes |
| tags | Tags to apply to all created resources. | `map(string)` | `{}` | no |
| endpoints | Map of endpoints for canary testing. The key is used as the canary name suffix. | <pre>map(object({<br>  url = string<br>}))</pre> | n/a | yes |
| schedule_expression | Schedule expression for the canary (e.g., `rate(5 minutes)` or `cron(0 1 * * ? *)`). | `string` | n/a | yes |
| start_canary | Specifies whether the canary is to start running upon creation. | `bool` | `true` | no |
| s3_artifact_bucket | The name of an existing S3 bucket to store canary artifacts. If empty, a new bucket will be created. | `string` | n/a | yes |
| code_source | The source of the canary script code. Must be one of `TEMPLATE`, `S3`, or `ZIP_FILE`. | `string` | n/a | yes |
| code_s3_config | Configuration for the canary script when source is S3. Required if `code_source` is `S3`. | <pre>object({<br>  bucket  = string<br>  key     = string<br>  version = optional(string)<br>})</pre> | `null` | no |
| code_zip_file_path | The local path to the canary script zip file. Required if `code_source` is `ZIP_FILE`. | `string` | `null` | no |
| canary_handler | The entry point for the canary script. | `string` | n/a | yes |
| canary_runtime_version | The runtime version for the canary. | `string` | n/a | yes |
| failure_retention_period_in_days | The number of days to retain data for failed canary runs. | `number` | n/a | yes |
| success_retention_period_in_days | The number of days to retain data for successful canary runs. | `number` | n/a | yes |
| run_config | Configuration for the canary's runtime behavior. | <pre>object({<br>  timeout_in_seconds = optional(number, 60)<br>  memory_in_mb       = optional(number, 1024)<br>  active_tracing     = optional(bool, false)<br>  environment        = optional(map(string), {})<br>})</pre> | n/a | yes |
| vpc_config | VPC configuration for the canary. Leave as `null` to run outside a VPC. | <pre>object({<br>  subnet_ids         = list(string)<br>  security_group_ids = list(string)<br>})</pre> | `null` | no |
| group_config | Configuration for associating canaries with a Synthetics Group. | <pre>object({<br>  create_group = optional(bool, false)<br>  group_name   = optional(string)<br>})</pre> | `{ create_group = false }` | no |

## Description

This Terraform module provisions and configures AWS CloudWatch Synthetics Canaries to proactively monitor your application endpoints and APIs. It simplifies the process of setting up one or more canaries by automating the creation of all necessary resources, including IAM roles, S3 artifact buckets, and the canaries themselves.

## Key Capabilities

-  Creates multiple canaries from a single map of endpoints, making it easy to monitor many URLs with a single module instance.
-  Supports using built-in AWS blueprints, custom scripts from local zip files, or scripts stored in an S3 bucket.
- Automatically creates and configures a dedicated S3 bucket for canary artifacts, or can use a pre-existing bucket.
-  Allows canaries to run within a specified VPC to monitor internal endpoints that are not publicly accessible.
-  Optionally creates an AWS Synthetics Group to organize and manage all created canaries together for better visibility.
-  Provides detailed control over canary settings, including schedule, runtime version, memory, timeout, and active X-Ray tracing.
- Provisions the necessary IAM role and policies for the canary to execute and write logs