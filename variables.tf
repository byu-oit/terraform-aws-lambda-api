variable "app_name" {
  type        = string
  description = "application name"
}

variable "env" {
  type        = string
  description = "application environment (e.g. dev, stg, prd)"
}

variable "codedeploy_service_role_arn" {
  type        = string
  description = "ARN of the IAM Role for the CodeDeploy to use to initiate new deployments. (usually the PowerBuilder Role)"
  default     = null
}

variable "lambda_zip_file" {
  type        = string
  description = "File that contains your compiled or zipped source code."
}

variable "handler" {
  type        = string
  description = "Lambda event handler"
}

variable "runtime" {
  type        = string
  description = "Lambda runtime"
}

variable "environment_variables" {
  type        = map(string)
  description = "A map that defines environment variables for the Lambda function."
  default     = null
}

variable "lambda_vpc_config" {
  default     = null
  description = "Provide this to allow your function to access your VPC."
  type = object({
    security_group_ids = list(string)
    subnet_ids         = list(string)
  })
}

variable "hosted_zone" {
  type = object({
    name = string,
    id   = string
  })
  description = "Hosted Zone object to redirect to ALB. (Can pass in the aws_hosted_zone object). A and AAAA records created in this hosted zone."
}

variable "https_certificate_arn" {
  type        = string
  description = "ARN of the HTTPS certificate of the hosted zone/domain."
}

variable "codedeploy_lifecycle_hooks" {
  type = object({
    BeforeAllowTraffic = string
    AfterAllowTraffic  = string
  })
  description = "Define Lambda Functions for CodeDeploy lifecycle event hooks. Or set this variable to null to not have any lifecycle hooks invoked. Defaults to null"
  default     = null
}

variable "appspec_filename" {
  type        = string
  description = "Filename (including path) to use when outputting appspec json."
  default     = null
}

variable "codedeploy_test_listener_port" {
  type        = number
  description = "The port for a codedeploy test listener. If provided CodeDeploy will use this port for test traffic on the new replacement set during the blue-green deployment process before shifting production traffic to the replacement set. Defaults to null"
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to deploy Lambda API service."
}
variable "public_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the ALB."
}

variable "tags" {
  type        = map(string)
  description = "A map of AWS Tags to attach to each resource created"
  default     = {}
}

variable "role_permissions_boundary_arn" {
  type        = string
  description = "IAM Role Permissions Boundary ARN"
}

variable "log_retention_in_days" {
  type        = number
  description = "CloudWatch log group retention in days. Defaults to 7."
  default     = 7
}

variable "lambda_policies" {
  type        = list(string)
  description = "List of IAM Policy ARNs to attach to the lambda role."
  default     = []
}

variable "use_codedeploy" {
  type        = bool
  description = "If true, CodeDeploy App and Deployment Group will be created and TF will not update alias to point to new versions of the Lambda (because CodeDeploy will do that)."
  default     = false
}

variable "timeout" {
  type        = number
  description = "Timeout (in seconds) for lambda. Defaults to 3 (terraform default"
  default     = 3
}

variable "memory_size" {
  type        = number
  description = "Memory Size of the lambda"
  default     = 128
}
variable "xray_enabled" {
  type        = bool
  description = "Whether or not the X-Ray daemon should be created with the Lambda API."
  default     = false
}