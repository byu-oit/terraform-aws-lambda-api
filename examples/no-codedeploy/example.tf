provider "aws" {
  version = "~> 3.0"
  region  = "us-west-2"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v3.4.0"
}

module "lambda_api" {
  #  source = "../../"
  source                        = "github.com/byu-oit/terraform-aws-lambda-api?ref=v2.1.1"
  app_name                      = "my-lambda-dev"
  zip_filename                  = "./src/lambda.zip"
  zip_handler                   = "index.handler"
  zip_runtime                   = "nodejs12.x"
  hosted_zone                   = module.acs.route53_zone
  https_certificate_arn         = module.acs.certificate.arn
  vpc_id                        = module.acs.vpc.id
  public_subnet_ids             = module.acs.public_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
  xray_enabled                  = true
}

output "url" {
  value = module.lambda_api.dns_record.fqdn
}
