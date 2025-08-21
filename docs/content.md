## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name for the canary setup. | string | n/a | yes |
| namespace | Namespace for tagging/naming. | string | n/a | yes |
| tags | Tags to apply to all created resources. | map(string) | {} | no |
| schedule_expression | Schedule expression for the canary (e.g., `rate(5 minutes)` or `cron(0 1 * * ? *)`). | string | n/a | yes |
| endpoints | Map of endpoints for canary testing. The key is used as the canary name suffix. | <pre>map(object({<br>  url = string<br>}))</pre> | n/a | yes |
| subnet_ids | List of subnet IDs for the canary to run in. If empty, the canary will not be associated with a VPC. | list(string) | [] | no |
| security_group_ids | List of security group IDs for the canary. Required if `subnet_ids` are provided. | list(string) | [] | no |
| s3_artifact_bucket | The name of an existing S3 bucket to store canary artifacts. If empty, a new bucket will be created. | string | "" | no |
| code_source | The source of the canary script code. Must be one of `TEMPLATE`, `S3`, or `ZIP_FILE`. | string | TEMPLATE | no |
| code_s3_bucket | The S3 bucket name for the canary script. Required if `code_source` is `S3`. | string | null | no |
| code_s3_key | The S3 key for the canary script. Required if `code_source` is `S3`. | string | null | no |
| code_s3_version | The S3 version ID for the canary script. | string | null | no |
| code_zip_file_path | The local path to the canary script zip file. Required if `code_source` is `ZIP_FILE`. | string | null | no |
| canary_handler | The entry point for the canary script. | string | n/a | yes |
| canary_runtime_version | The runtime version for the canary. | string | n/a | yes |
| start_canary | Specifies whether the canary is to start running upon creation. | bool | true | no |
| canary_timeout_in_seconds | How long the canary is allowed to run before it is stopped. | number | 60 | no |
| failure_retention_period_in_days | The number of days to retain data for failed canary runs. | number | 31 | no |
| success_retention_period_in_days | The number of days to retain data for successful canary runs. | number | 31 | no |
| canary_memory_in_mb | The amount of memory, in MB, to allocate to the canary. | number | 1024 | no |
| canary_active_tracing | Enables active X-Ray tracing for the canary. | bool | false | no |
| create_synthetics_group | Whether to create an AWS Synthetics Group and associate the canaries with it. | bool | false | no |
| synthetics_group_name | The name for the Synthetics Group if `create_synthetics_group` is true. | string | "" | no |
| canary_environment_variables | A map of environment variables for the canary. | map(string) | {} | no |

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