terraform {
  required_version = "0.12.26"
}

provider "aws" {
  version = "~> 2.56"
  region  = "us-west-2"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v2.1.0"
}

module "lambda_api" {
  source                        = "../../"
  app_name                      = "my-lambda"
  env                           = "dev"
  lambda_zip_file               = "./lambda.zip"
  handler                       = "index.handler"
  runtime                       = "nodejs12.x"
  hosted_zone                   = module.acs.route53_zone
  https_certificate_arn         = module.acs.certificate.arn
  vpc_id                        = module.acs.vpc.id
  public_subnet_ids             = module.acs.public_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn

  lambda_vpc_config = {
    subnet_ids         = module.acs.private_subnet_ids
    security_group_ids = []
  }
}

output "lambda" {
  value = module.lambda_api.lambda
}

output "lambda_security_group" {
  value = module.lambda_api.lambda_security_group
}

output "lambda_live_alias" {
  value = module.lambda_api.lambda_live_alias
}

output "codedeploy_deployment_group" {
  value = module.lambda_api.codedeploy_deployment_group
}

output "codedeploy_appspec_json_file" {
  value = module.lambda_api.codedeploy_appspec_json_file
}

output "alb" {
  value = module.lambda_api.alb
}

output "alb_security_group" {
  value = module.lambda_api.alb_security_group
}

output "dns_record" {
  value = module.lambda_api.dns_record
}

output "cloudwatch_log_group" {
  value = module.lambda_api.cloudwatch_log_group
}
