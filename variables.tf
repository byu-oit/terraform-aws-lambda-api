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
}

variable "codedeploy_termination_wait_time" {
  type        = number
  description = "The number of minutes to wait after a successful blue/green deployment before terminating instances from the original environment. Defaults to 15"
  default     = 15
}

variable "lambda_src_dir" {
  type        = string
  description = "Directory that contains your lambda source code"
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

variable "vpc_id" {
  type        = string
  description = "VPC ID to deploy ECS fargate service."
}
variable "public_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the ALB."
}
variable "private_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the fargate service."
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

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the fargate service."
  default     = []
}

variable "security_groups" {
  type        = list(string)
  description = "List of extra security group IDs to attach to the fargate task."
  default     = []
}
