terraform {
  required_version = ">= 0.12.21"
  required_providers {
    aws = ">= 2.56"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ==================== Variables ====================

variable "app_name" {
  type        = string
  description = "application name"
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
    BeforeAllowTraffic    = string
    AfterAllowTraffic     = string
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

# ==================== Outputs ====================

# output "appspec" {
#   value = local_file.appspec_json.content
# }

output "dns_record" {
  value = aws_route53_record.a_record
}
# ==================== Locals ====================

locals {
  alb_name       = "${var.app_name}-alb"                     // ALB name has a restriction of 32 characters max
  app_domain_url = "${var.app_name}.${var.hosted_zone.name}" // Route53 A record name

  hooks = var.codedeploy_lifecycle_hooks != null ? setsubtract([
    for hook in keys(var.codedeploy_lifecycle_hooks) :
    zipmap([hook], [lookup(var.codedeploy_lifecycle_hooks, hook, null)])
    ], [
    {
      BeforeAllowTraffic = null
    },
    {
      AfterAllowTraffic = null
    }
  ]) : null
}


# ==================== ALB ====================

resource "aws_alb" "alb" {
  name            = local.alb_name
  subnets         = var.public_subnet_ids
  security_groups = [aws_security_group.alb-sg.id]
  tags            = var.tags
}

resource "aws_security_group" "alb-sg" {
  name        = "${local.alb_name}-sg"
  description = "Controls access to the ${local.alb_name}"
  vpc_id      = var.vpc_id

  // allow access to the ALB from anywhere for 80 and 443
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 4443
    to_port     = 4443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  // allow any outgoing traffic
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_alb_target_group" "tg" {
  name        = "${var.app_name}-tg"
  target_type = "lambda"
  tags        = var.tags
  depends_on  = [aws_alb.alb]
}

resource "aws_alb_target_group" "tst_tg" {
  name        = "${var.app_name}-tst"
  target_type = "lambda"
  tags        = var.tags
  depends_on  = [aws_alb.alb]
}

resource "aws_alb_listener" "https" {
  load_balancer_arn = aws_alb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.https_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.tg.arn
  }
  lifecycle {
    ignore_changes = [default_action[0].target_group_arn]
  }
  depends_on = [
    aws_alb_target_group.tg
  ]
}

resource "aws_alb_listener" "test_https" {
  load_balancer_arn = aws_alb.alb.arn
  port              = 4443
  protocol          = "HTTPS"
  certificate_arn   = var.https_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.tst_tg.arn
  }
  lifecycle {
    ignore_changes = [default_action[0].target_group_arn]
  }
  depends_on = [
    aws_alb_target_group.tst_tg
  ]
}

resource "aws_alb_listener" "http_to_https" {
  load_balancer_arn = aws_alb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      status_code = "HTTP_301"
      port        = aws_alb_listener.https.port
      protocol    = aws_alb_listener.https.protocol
    }
  }
}

resource "aws_lambda_permission" "with_lb" {
  statement_id  = "AllowExecutionFromlb"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_lambda.arn
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_alb_target_group.tg.arn
  qualifier     = aws_lambda_alias.live.name
}

resource "aws_lambda_permission" "with_tst_lb" {
  statement_id  = "AllowExecutionFromlb"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_lambda.arn
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_alb_target_group.tst_tg.arn
}

resource "aws_alb_target_group_attachment" "live_attachment" {
  target_group_arn = aws_alb_target_group.tg.arn
  target_id        = aws_lambda_alias.live.arn
  depends_on       = [aws_lambda_permission.with_lb]
}

resource "aws_alb_target_group_attachment" "tst_attachment" {
  target_group_arn = aws_alb_target_group.tst_tg.arn
  target_id        = aws_lambda_function.api_lambda.arn # Latest
  depends_on       = [aws_lambda_permission.with_tst_lb]
}

# ==================== Route53 ====================

resource "aws_route53_record" "a_record" {
  name    = local.app_domain_url
  type    = "A"
  zone_id = var.hosted_zone.id
  alias {
    evaluate_target_health = true
    name                   = aws_alb.alb.dns_name
    zone_id                = aws_alb.alb.zone_id
  }
}
resource "aws_route53_record" "aaaa_record" {
  name    = local.app_domain_url
  type    = "AAAA"
  zone_id = var.hosted_zone.id
  alias {
    evaluate_target_health = true
    name                   = aws_alb.alb.dns_name
    zone_id                = aws_alb.alb.zone_id
  }
}

# ==================== Lambda ====================

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "archive_file" "cleanup_lambda_zip" {
  source_dir  = var.lambda_src_dir
  output_path = "lambda_function_payload.zip"
  type        = "zip"
}

resource "aws_lambda_function" "api_lambda" {
  filename         = data.archive_file.cleanup_lambda_zip.output_path
  source_code_hash = data.archive_file.cleanup_lambda_zip.output_base64sha256
  function_name    = "my-lambda"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs12.x"
  publish          = true

  #   environment {
  #     variables = {
  #       netid = "jvisker"
  #     }
  #   }
}

resource "aws_lambda_alias" "live" {
  name             = "live"
  description      = "a sample description"
  function_name    = aws_lambda_function.api_lambda.arn
  function_version = "1"
  # Let CodeDeploy handle changes to the function version that this alias refers to
  lifecycle {
    ignore_changes = [
      function_version
    ]
  }
}

# ==================== CodeDeploy ====================

resource "aws_codedeploy_app" "app" {
  compute_platform = "Lambda"
  name             = "${var.app_name}-cd"
}

# resource "aws_codedeploy_deployment_config" "config" {
#   deployment_config_name = "${var.app_name}-cfg"
#   compute_platform       = "Lambda"

#   //TODO: There are other ways to configure this
#   traffic_routing_config {
#     type = "TimeBasedLinear"

#     time_based_linear {
#       interval   = 10
#       percentage = 10
#     }
#   }
# }

resource "aws_codedeploy_deployment_group" "deployment_group" {
  app_name               = aws_codedeploy_app.app.name
  deployment_group_name  = "${var.app_name}-dg"
  service_role_arn       = var.codedeploy_service_role_arn
  deployment_config_name = "CodeDeployDefault.LambdaAllAtOnce"
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}


# ==================== CloudWatch ====================

# resource "aws_cloudwatch_log_group" "log_group" {
#   name              = "/aws/lambda/${lambda_function_name}"
#   retention_in_days = var.log_retention_in_days
#   tags              = var.tags
# }


# ==================== AppSpec file ====================

data "aws_lambda_alias" "alias_for_old_version" {
  function_name = aws_lambda_function.api_lambda.function_name
  name          = "live" //TODO: Make local?
}

resource "local_file" "appspec_json" {
  filename = "${path.cwd}/appspec.json"
  content = jsonencode({
    version = 1
    Resources = [{
      apiLambdaFunction = {
        Type = "AWS::Lambda::Function"
        Properties = {
          Name           = aws_lambda_function.api_lambda.function_name
          Alias          = aws_lambda_alias.live.name
          CurrentVersion = data.aws_lambda_alias.alias_for_old_version.function_version
          TargetVersion  = aws_lambda_function.api_lambda.version
        }
      }
    }],
    Hooks = local.hooks
  })
}
