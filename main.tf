terraform {
  required_version = ">= 0.12.21"
  required_providers {
    aws = ">= 2.56"
  }
}

# ==================== Locals ====================

locals {
  long_name      = "${var.app_name}-${var.env}"
  alb_name       = "${local.long_name}-alb"                     // ALB name has a restriction of 32 characters max
  app_domain_url = "${local.long_name}.${var.hosted_zone.name}" // Route53 A record name

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
  // if test listner port is specified, allow traffic
  dynamic "ingress" {
    for_each = var.codedeploy_test_listener_port != null ? [1] : []
    content {
      from_port   = var.codedeploy_test_listener_port
      to_port     = var.codedeploy_test_listener_port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
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
  name        = "${local.long_name}-tg"
  target_type = "lambda"
  tags        = var.tags
  depends_on  = [aws_alb.alb]
}

resource "aws_alb_target_group" "tst_tg" {
  count       = var.use_codedeploy ? 1 : 0
  name        = "${local.long_name}-tst"
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
  count             = var.use_codedeploy ? 1 : 0
  load_balancer_arn = aws_alb.alb.arn
  port              = 4443
  protocol          = "HTTPS"
  certificate_arn   = var.https_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.tst_tg[0].arn
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
  qualifier     = var.use_codedeploy ? aws_lambda_alias.live_codedeploy[0].name : aws_lambda_alias.live[0].name
}

resource "aws_lambda_permission" "with_tst_lb" {
  count         = var.use_codedeploy ? 1 : 0
  statement_id  = "AllowExecutionFromlb"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_lambda.arn
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_alb_target_group.tst_tg[0].arn
}

resource "aws_alb_target_group_attachment" "live_attachment" {
  target_group_arn = aws_alb_target_group.tg.arn
  target_id        = var.use_codedeploy ? aws_lambda_alias.live_codedeploy[0].arn : aws_lambda_alias.live[0].arn #Live
  depends_on       = [aws_lambda_permission.with_lb]
}

resource "aws_alb_target_group_attachment" "tst_attachment" {
  count            = var.use_codedeploy ? 1 : 0
  target_group_arn = aws_alb_target_group.tst_tg[0].arn
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
  name                 = "${local.long_name}-role"
  permissions_boundary = var.role_permissions_boundary_arn
  assume_role_policy   = <<EOF
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

resource "aws_iam_role_policy_attachment" "lambda_eni_attach" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaENIManagementAccess"
  role       = aws_iam_role.iam_for_lambda.name
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  count      = length(var.lambda_policies)
  policy_arn = element(var.lambda_policies, count.index)
  role       = aws_iam_role.iam_for_lambda.name
}

resource "aws_security_group" "lambda_sg" {
  count       = var.lambda_vpc_config != null ? 1 : 0
  name        = "${local.long_name}-lambda-sg"
  description = "Controls access to the Lambda"
  vpc_id      = var.vpc_id

  # ingress not needed as ALB invokes Lambda via AWS API, not direct network traffic

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_lambda_function" "api_lambda" {
  filename         = var.lambda_zip_file
  source_code_hash = filebase64sha256(var.lambda_zip_file)
  function_name    = local.long_name
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = var.handler
  runtime          = var.runtime
  publish          = true

  dynamic "environment" {
    for_each = var.environment_variables != null ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = var.lambda_vpc_config == null ? [] : [var.lambda_vpc_config]
    content {
      subnet_ids         = lambda_vpc_config.value.subnet_ids
      security_group_ids = concat([aws_security_group.lambda_sg.id], lambda_vpc_config.value.security_group_ids)
    }
  }
}

resource "aws_lambda_alias" "live" {
  count            = ! var.use_codedeploy ? 1 : 0
  name             = "live"
  description      = "ALB sends traffic to this version"
  function_name    = aws_lambda_function.api_lambda.arn
  function_version = aws_lambda_function.api_lambda.version
}

resource "aws_lambda_alias" "live_codedeploy" {
  count         = var.use_codedeploy ? 1 : 0
  name          = "live"
  description   = "ALB sends traffic to this version"
  function_name = aws_lambda_function.api_lambda.arn
  # Get the version of the lambda when it is first created
  function_version = aws_lambda_function.api_lambda.version
  # Let CodeDeploy handle changes to the function version that this alias refers to
  lifecycle {
    ignore_changes = [
      function_version
    ]
  }
}

# ==================== CodeDeploy ====================

resource "aws_codedeploy_app" "app" {
  count            = var.use_codedeploy ? 1 : 0
  compute_platform = "Lambda"
  name             = "${local.long_name}-cd"
}

resource "aws_codedeploy_deployment_group" "deployment_group" {
  count                  = var.use_codedeploy ? 1 : 0
  app_name               = aws_codedeploy_app.app[0].name
  deployment_group_name  = "${local.long_name}-dg"
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

resource "aws_cloudwatch_log_group" "log_group" {
  name              = "/aws/lambda/${aws_lambda_function.api_lambda.function_name}"
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_attach" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.iam_for_lambda.name
}

# ==================== AppSpec file ====================

resource "local_file" "appspec_json" {
  count    = var.use_codedeploy ? 1 : 0
  filename = "${path.cwd}/appspec.json"
  content = jsonencode({
    version = 1
    Resources = [{
      apiLambdaFunction = {
        Type = "AWS::Lambda::Function"
        Properties = {
          Name           = aws_lambda_function.api_lambda.function_name
          Alias          = aws_lambda_alias.live_codedeploy[0].name
          CurrentVersion = aws_lambda_alias.live_codedeploy[0].function_version
          TargetVersion  = aws_lambda_function.api_lambda.version
        }
      }
    }],
    Hooks = local.hooks
  })
}
