![Latest GitHub Release](https://img.shields.io/github/v/release/byu-oit/terraform-aws-lambda-api?sort=semver)

# Terraform AWS Lambda API
Terraform module pattern to build a standard Lambda API.

#### [New to Terraform Modules at BYU?](https://github.com/byu-oit/terraform-documentation)

This module deploys a Lambda behind an ALB.

## CodeDeploy Option

Optionally, CodeDeploy can be used to perform "blue/green" deployments of new versions of the Lambda.

Before switching production traffic to the new Lambda, CodeDeploy runs Postman tests. This is done by:

 * Having all production traffic (port `443`) sent to the Lambda version considered `live`
 * Creating and deploying the new untested Lambda version to `$LATEST`
 * Invoking a separate "test" Lambda that runs Postman tests
   - These tests run against the port specified by `codedeploy_test_listener_port`, which corresponds to `$LATEST`
 * If the tests pass, we move the `live` alias to the now-tested `$LATEST` version of the Lambda

Note: If you do not specify `use_codedeploy = true`, the above process will not apply. Instead, the `live` alias will be updated directly by `terraform apply`.

Also Note: CodePipeline and CodeDeploy cannot be used together to deploy a Lambda. If you are using CodePipeline, you cannot specify `use_codedeploy = true`. CodeDeploy works fine with other pipelining tools (e.g. GitHub Actions).

## Usage
For a Zip file lambda
```hcl
module "lambda_api" {
  source       = "github.com/byu-oit/terraform-aws-lambda-api?ref=v2.1.1"
  app_name     = "my-lambda-codedeploy-dev"
  zip_filename = "./src/lambda.zip"
  zip_handler  = "index.handler"
  zip_runtime  = "nodejs12.x"

  hosted_zone                   = module.acs.route53_zone
  https_certificate_arn         = module.acs.certificate.arn
  vpc_id                        = module.acs.vpc.id
  public_subnet_ids             = module.acs.public_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
  codedeploy_service_role_arn   = module.acs.power_builder_role.arn
  codedeploy_test_listener_port = 4443
  codedeploy_lifecycle_hooks = {
    BeforeAllowTraffic = aws_lambda_function.test_lambda.function_name
    AfterAllowTraffic  = null
  }
}
```

For a docker image lambda:
```hcl
module "lambda_api" {
  source                        = "github.com/byu-oit/terraform-aws-lambda-api?ref=v2.1.1"
  app_name                      = "my-docker-lambda"
  image_uri                     = "my-image-from-my-ecr:latest"
  hosted_zone                   = module.acs.route53_zone
  https_certificate_arn         = module.acs.certificate.arn
  vpc_id                        = module.acs.vpc.id
  public_subnet_ids             = module.acs.public_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
  codedeploy_service_role_arn   = module.acs.power_builder_role.arn
  codedeploy_test_listener_port = 4443
  codedeploy_lifecycle_hooks = {
    BeforeAllowTraffic = aws_lambda_function.test_lambda.function_name
    AfterAllowTraffic  = null
  }
}
```
## Created Resources

* Lambda Function
    * with IAM role and policies
    * with security group
    * with "live" alias (for blue-green deployment)
* CloudWatch Log Group
* ALB
    * with security group
    * with listeners and target groups
        * 80 (redirects to 443)
        * 443 (HTTPS forwards to "live")
        * test_listener_port (HTTPS forwards to "latest")
* CodeDeploy App
    * with IAM role
* CodeDeploy Group
* DNS A-Record

## Requirements
* Terraform version 0.13.2 or greater
* AWS provider version 3.0 or greater

## Inputs
| Name | Type  | Description | Default |
| --- | --- | --- | --- |
| app_name | string | Application name to name your Lambda API and other resources (Must be <= 28 alphanumeric characters) | |
| image_uri | string | ECR Image URI containing the function's deployment package (conflicts with `zip_file`)| null |
| zip_filename | string | File that contains your compiled or zipped source code. |
| zip_handler | string | Lambda event handler |
| zip_runtime | string | Lambda runtime |
| lambda_vpc_config | [object](#lambda_vpc_config) | Lambda VPC object. Used if lambda requires to run inside a VPC | null |
| environment_variables | map(string) | A map that defines environment variables for the Lambda function. | |
| domain_url | string | Custom domain URL for the API, defaults to <app_name>.<hosted_zone_domain> | null | |
| hosted_zone | [object](#hosted_zone) | Hosted Zone object to redirect to ALB. (Can pass in the aws_hosted_zone object). A and AAAA records created in this hosted zone. | |
| https_certificate_arn | string | ARN of the HTTPS certificate of the hosted zone/domain. | |
| codedeploy_service_role_arn | string | ARN of the IAM Role for the CodeDeploy to use to initiate new deployments. (usually the PowerBuilder Role) |
| codedeploy_lifecycle_hooks | [object](#codedeploy_lifecycle_hooks) | Define Lambda Functions for CodeDeploy lifecycle event hooks. Or set this variable to null to not have any lifecycle hooks invoked. Defaults to null | null
| codedeploy_appspec_filename | string | Filename (including path) to use when outputing appspec json. | `appspec.json` in the current working directory (i.e. where you ran `terraform apply`) |
| codedeploy_test_listener_port | number | The port for a codedeploy test listener. If provided CodeDeploy will use this port for test traffic on the new replacement set during the blue-green deployment process before shifting production traffic to the replacement set. Defaults to null | null
| vpc_id | string | VPC ID to deploy ALB and Lambda (If specified). | |
| public_subnet_ids | list(string) | List of subnet IDs for the ALB. | |
| tags | map(string) | A map of AWS Tags to attach to each resource created | {} |
| role_permissions_boundary_arn | string | IAM Role Permissions Boundary ARN | |
| log_retention_in_days | number | CloudWatch log group retention in days. Defaults to 7. | 7 |
| lambda_policies | list(string) | List of IAM Policy ARNs to attach to the lambda role. | [] |
| lambda_layers | list(string) | List of Lambda Layer Version ARNs (maximum of 5) to attach to your function. | [] |
| timeout | number | How long the lambda will run (in seconds) before timing out | 3 (same as terraform default) |
| memory_size | number | Size of the memory of the lambda. CPU will scale along with it | 128 (same as terraform default) |
| xray_enabled | bool | Whether or not the X-Ray daemon should be created with the Lambda API. | false |

#### lambda_vpc_config

This variable is used when the lambda needs to be run from within a VPC. 

* **`subnet_ids`** - List of subnet IDs for the Lambda service. 
* **`security_group_ids`** - List of extra security group IDs to attach to the lambda.

#### codedeploy_lifecycle_hooks

This variable is used when generating the [appspec.json](#appspec) file. This will define what Lambda Functions to invoke 
at specific [lifecycle hooks](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-structure-hooks.html). 
Set this variable to `null` if you don't want to invoke any lambda functions. Set each hook to `null` if you don't need 
a specific lifecycle hook function.

* **`before_allow_traffic`** - lambda function name to run before public traffic points to new lambda version
* **`after_allow_traffic`** - lambda function name to run after public traffic points to new lambda version

#### hosted_zone

You can pass in either the object from the AWS terraform provider for an AWS Hosted Zone, or just an object with the following attributes:
* **`name`** - (Required) Name of the hosted zone
* **`id`** - (Required) ID of the hosted zone

#### CloudWatch logs

This module will create a CloudWatch log group named `/aws/lambda/<app_name>`.

For instance with the [above example](#usage) the logs could be found in the CloudWatch log group: `aws/lambda/my-lambda-dev`.

## Outputs

| Name | Type | Description |
| ---  | ---  | --- |
| lambda | [object](https://www.terraform.io/docs/providers/aws/r/lambda_function.html#argument-reference) | The Lambda that handles API requests |
| lambda_security_group | [object](https://www.terraform.io/docs/providers/aws/r/security_group.html#argument-reference) | Controls what the Lambda can access |
| lambda_live_alias | [object](https://www.terraform.io/docs/providers/aws/r/lambda_alias.html#argument-reference) | Controls which version of the Lambda receives "live" traffic |
| codedeploy_deployment_group | [object](https://www.terraform.io/docs/providers/aws/r/codedeploy_deployment_group.html#argument-reference) | The CodeDeploy deployment group object. |
| codedeploy_appspec_json_file | string | Filename of the generated appspec.json file |
| alb | [object](https://www.terraform.io/docs/providers/aws/r/lb.html#argument-reference) | The Application Load Balancer (ALB) object |
| alb_security_group | [object](https://www.terraform.io/docs/providers/aws/r/security_group.html#argument-reference) | The ALB's security group object |
| dns_record | [object](https://www.terraform.io/docs/providers/aws/r/route53_record.html#argument-reference) | The DNS A-record mapped to the ALB |
| cloudwatch_log_group | [object](https://www.terraform.io/docs/providers/aws/r/cloudwatch_log_group.html#argument-reference) | The log group for the Lambda's logs |

#### appspec

This module also creates a JSON file in the project directory: `appspec.json` used to initiate a CodeDeploy Deployment.

Here's an example appspec.json file this creates:
```json
{
  "Resources": [
    {
      "apiLambdaFunction": {
        "Properties": {
          "Alias": "live",
          "CurrentVersion": "6",
          "Name": "my-lambda-codedeploy-dev",
          "TargetVersion": "6"
        },
        "Type": "AWS::Lambda::Function"
      }
    }
  ],
  "version": 1
}
```
And example with [lifecycle hooks](#codedeploy_lifecycle_hooks):
```json
{
  "Hooks": [
    {
      "BeforeAllowTraffic": "my-lambda-deploy-test"
    }
  ],
  "Resources": [
    {
      "apiLambdaFunction": {
        "Properties": {
          "Alias": "live",
          "CurrentVersion": "6",
          "Name": "my-lambda-codedeploy-dev",
          "TargetVersion": "6"
        },
        "Type": "AWS::Lambda::Function"
      }
    }
  ],
  "version": 1
}
```

## CodeDeploy Blue-Green Deployment

If `use_codedeploy = true` is specified, this module creates a blue-green deployment process with CodeDeploy. If a `codedeploy_test_listener_port` is provided this module will create an ALB listener that will allow public traffic from that port to the running lambda.

When a CodeDeploy deployment is initiated (either via a pipeline or manually) CodeDeploy will:
1. call lambda function defined for `BeforeAllowTraffic` hook
2. associate the "live" alias "TargetVersion"
3. call lambda function defined for `AfterAllowTraffic` hook

At any step the deployment can rollback (either manually or by the lambda functions in the lifecycle hooks or if there was an error trying to actually deploy)

If manual rollback is needed after the deployment has completed, that can be done in the Lambda Console:
1. Select your Lambda Function.
2. Select a function alias (aka. "Qualifier")
3. Click the "Edit alias" button
4. Select the version you want to roll back to
5. Click "Save"

##### TODO add diagrams to explain the blue-green deployment process 

## Note

If you require additional variables please create an [issue](https://github.com/byu-oit/terraform-aws-lambda-api/issues)
 and/or a [pull request](https://github.com/byu-oit/terraform-aws-lambda-api/pulls) to add the variable and reach 
 out to the Application Engineering SpecOps Green team (`IT Collaboration` -> `OIT ENG AppEng - SpecOps Green` channel).
