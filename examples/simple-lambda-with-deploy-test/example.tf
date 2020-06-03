provider "aws" {
  version = "~> 2.56"
  region  = "us-west-2"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v2.1.0"
}

module "lambda_api" {
  # source                        = "../../"
  source                        = "github.com/byu-oit/terraform-aws-lambda-api?ref=v1.0.1"
  app_name                      = "my-lambda-codedeploy"
  env                           = "dev"
  codedeploy_service_role_arn   = module.acs.power_builder_role.arn
  lambda_zip_file               = "./src/lambda.zip"
  handler                       = "index.handler"
  runtime                       = "nodejs12.x"
  hosted_zone                   = module.acs.route53_zone
  https_certificate_arn         = module.acs.certificate.arn
  vpc_id                        = module.acs.vpc.id
  public_subnet_ids             = module.acs.public_subnet_ids
  private_subnet_ids            = module.acs.private_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
  codedeploy_test_listener_port = 4443
  use_codedeploy                = true

  codedeploy_lifecycle_hooks = {
    BeforeAllowTraffic = aws_lambda_function.test_lambda.function_name
    AfterAllowTraffic  = null
  }
}

resource "aws_iam_role" "test_lambda" {
  name                 = "my-lambda-deploy-test"
  permissions_boundary = module.acs.role_permissions_boundary.arn

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
  source_dir  = "./tst"
  output_path = "./tst/lambda.zip"
  type        = "zip"
}

resource "aws_lambda_function" "test_lambda" {
  filename         = "./tst/lambda.zip"
  function_name    = "my-lambda-deploy-test"
  role             = aws_iam_role.test_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs12.x"
  timeout          = 30
  source_code_hash = data.archive_file.cleanup_lambda_zip.output_base64sha256
}

resource "aws_iam_role_policy" "test_lambda" {
  name = "my-lambda-deploy-test"
  role = aws_iam_role.test_lambda.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    },
    {
      "Action": "codedeploy:PutLifecycleEventHookExecutionStatus",
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

output "url" {
  value = module.lambda_api.dns_record.fqdn
}
