terraform {
  required_version = "0.13.2"
}

provider "aws" {
  version = "~> 5.33"
  region  = "us-west-2"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v3.5.0"
}

module "lambda_api" {
  source                        = "../../"
  app_name                      = "my-lambda"
  zip_filename                  = "./lambda.zip"
  zip_handler                   = "index.handler"
  zip_runtime                   = "nodejs20.x"
  hosted_zone                   = module.acs.route53_zone
  https_certificate_arn         = module.acs.certificate.arn
  vpc_id                        = module.acs.vpc.id
  public_subnet_ids             = module.acs.public_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
  xray_enabled                  = true

  lambda_vpc_config = {
    subnet_ids         = module.acs.private_subnet_ids
    security_group_ids = []
  }
}

module "lambda_docker_api" {
  source                        = "../../"
  app_name                      = "my-docker-lambda"
  image_uri                     = "crccheck/hello-world:latest"
  hosted_zone                   = module.acs.route53_zone
  https_certificate_arn         = module.acs.certificate.arn
  vpc_id                        = module.acs.vpc.id
  public_subnet_ids             = module.acs.public_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
  xray_enabled                  = true

  lambda_vpc_config = {
    subnet_ids         = module.acs.private_subnet_ids
    security_group_ids = []
  }
}
