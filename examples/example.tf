provider "aws" {
  version = "~> 2.56"
  region  = "us-west-2"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v2.1.0"
}

module "lambda_api" {
  source = "../"
  app_name = "test"
  codedeploy_service_role_arn = module.acs.power_builder_role.arn
  lambda_src_dir = "./my-lambda"
  hosted_zone = module.acs.route53_zone
  https_certificate_arn = module.acs.certificate.arn
  vpc_id = module.acs.vpc.id
  public_subnet_ids             = module.acs.public_subnet_ids
  private_subnet_ids            = module.acs.private_subnet_ids
  codedeploy_lifecycle_hooks = {
    BeforeInstall         = null
    AfterInstall          = null
    AfterAllowTestTraffic = null
    BeforeAllowTraffic    = null
    AfterAllowTraffic     = null
  }
}
