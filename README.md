![Latest GitHub Release](https://img.shields.io/github/v/release/byu-oit/terraform-aws-lambda-api?sort=semver)

# Terraform AWS Lambda API
Terraform module pattern to build a standard Lambda API.

#### [New to Terraform Modules at BYU?](https://github.com/byu-oit/terraform-documentation)

This module uses CodeDeploy to deploy a Lambda behind an ALB.

Before switching production traffic to the new Lambda, CodeDeploy runs Postman tests.
This is done by:
 * Having all production traffic (port `443`) sent to the Lambda version considered `live`
 * Creating and deploying the new untested Lambda version to `$LATEST`
 * Invoking a separate "test" Lambda that runs Postman tests
   - These tests run against the port specified by `codedeploy_test_listener_port`, which corresponds to `$LATEST`
 * If the tests pass, we give the alias `live` to the now-tested `$LATEST` version of the Lambda

## Usage
```hcl
module "lambda_api" {
  source                        = "github.com/byu-oit/terraform-aws-lambda-api?ref=v0.2.0"
  app_name                      = "my-lambda"
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

  codedeploy_lifecycle_hooks = {
    BeforeAllowTraffic = aws_lambda_function.test_lambda.function_name
    AfterAllowTraffic  = null
  }
}
```
## Created Resources
##### TODO fix this section (copy pasta from standard fargate)

* ECS Cluster
* ECS Service
    * with security group
* ECS Task Definition
    * with IAM role
* CloudWatch Log Group
* ALB
    * with security group
* 2 Target Groups (for blue-green deployment)
* CodeDeploy App
    * with IAM role
* CodeDeploy Group
* DNS A-Record
* AutoScaling Target
* AutoScaling Policies (one for stepping up and one for stepping down)
* CloudWatch Metric Alarms (one for stepping up and one for stepping down)

## Requirements
* Terraform version 0.12.21 or greater
* AWS provider version 2.56 or greater

## Inputs
| Name | Type  | Description | Default |
| --- | --- | --- | --- |
| app_name | string | application name |
| env | string | application environment (e.g. dev, stg, prd) |
| codedeploy_service_role_arn | string | ARN of the IAM Role for the CodeDeploy to use to initiate new deployments. (usually the PowerBuilder Role) |
| lambda_zip_file | string | File that contains your compiled or zipped source code. |
| handler | string | Lambda event handler |
| runtime | string | Lambda runtime |
| environment_variables | map(string) | A map that defines environment variables for the Lambda function. |
| hosted_zone | [object](#hosted_zone) | Hosted Zone object to redirect to ALB. (Can pass in the aws_hosted_zone object). A and AAAA records created in this hosted zone. |
| https_certificate_arn | string | ARN of the HTTPS certificate of the hosted zone/domain. |
| codedeploy_lifecycle_hooks | [object](#codedeploy_lifecycle_hooks) | Define Lambda Functions for CodeDeploy lifecycle event hooks. Or set this variable to null to not have any lifecycle hooks invoked. Defaults to null | null
| codedeploy_test_listener_port | number | The port for a codedeploy test listener. If provided CodeDeploy will use this port for test traffic on the new replacement set during the blue-green deployment process before shifting production traffic to the replacement set. Defaults to null | null
| vpc_id | string | VPC ID to deploy ECS fargate service. |
| public_subnet_ids | list(string) | List of subnet IDs for the ALB. |
| private_subnet_ids | list(string) | List of subnet IDs for the Lambda service. |
| tags | map(string) | A map of AWS Tags to attach to each resource created | {}
| role_permissions_boundary_arn | string | IAM Role Permissions Boundary ARN |
| log_retention_in_days | number | CloudWatch log group retention in days. Defaults to 7. | 7
| lambda_policies | list(string) | List of IAM Policy ARNs to attach to the lambda role. | []
| security_groups | list(string) | List of extra security group IDs to attach to the lambda. | []
| use_codedeploy | bool | If true, CodeDeploy App and Deployment Group will be created and TF will not update alias to point to new versions of the Lambda (becuase CodeDeploy will do that). | false

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

This module will create a CloudWatch log group named `/aws/lambda/<app_name>-<env>`.

For instance with the [above example](#usage) the logs could be found in the CloudWatch log group: `aws/lambda/my-lambda-dev`.

## Outputs
##### TODO fill out this section

| Name | Type | Description |
| ---  | ---  | --- |

#### appspec
##### TODO fix this section (copy pasta from standard fargate)

This module also creates a JSON file in the project directory: `appspec.json` used to initiate a CodeDeploy Deployment.

Here's an example appspec.json file this creates:
```json
{
  "Resources": [
    {
      "TargetService": {
        "Properties": {
          "LoadBalancerInfo": {
            "ContainerName": "example",
            "ContainerPort": 8000
          },
          "TaskDefinition": "arn:aws:ecs:us-west-2:123456789123:task-definition/example-api-def:2"
        },
        "Type": "AWS::ECS::SERVICE"
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
      "BeforeInstall": null
    },
    {
      "AfterInstall": "AfterInstallHookFunctionName"
    },
    {
      "AfterAllowTestTraffic": "AfterAllowTestTrafficHookFunctionName"
    },
    {
      "BeforeAllowTraffic": null
    },
    {
      "AfterAllowTraffic": null
    }
  ],
  "Resources": [
    {
      "TargetService": {
        "Properties": {
          "LoadBalancerInfo": {
            "ContainerName": "example",
            "ContainerPort": 8000
          },
          "TaskDefinition": "arn:aws:ecs:us-west-2:123456789123:task-definition/example-api-def:2"
        },
        "Type": "AWS::ECS::SERVICE"
      }
    }
  ],
  "version": 1
}
```

## CodeDeploy Blue-Green Deployment
##### TODO fix this section (copy pasta from standard fargate)

This module creates a blue-green deployment process with CodeDeploy. If a `codedeploy_test_listener_port` is provided 
this module will create an ALB listener that will allow public traffic from that port to the running lambda.

When a CodeDeploy deployment is initiated (either via a pipeline or manually) CodeDeploy will:
1. call lambda function defined for `BeforeInstall` hook
2. attempt to create a new set of tasks (called the replacement set) with the new task definition etc. in the unused ALB Target Group
3. call lambda function defined for `AfterInstall` hook
4. associate the test listener (if defined) to the new target group
5. call lambda function defined for `AfterAllowTestTraffic` hook
6. call lambda function defined for `BeforeAllowTraffic` hook
7. associate the production listener to the new target group
8. call lambda function defined for `AfterAllowTraffic` hook
9. wait for the `codedeploy_termination_wait_time` in minutes before destroying the original task set (this is useful if you need to manually rollback)

At any step (except step #1) the deployment can rollback (either manually or by the lambda functions in the lifecycle hooks or if there was an error trying to actually deploy)

##### TODO add diagrams to explain the blue-green deployment process 

## Note

If you require additional variables please create an [issue](https://github.com/byu-oit/terraform-aws-lambda-api/issues)
 and/or a [pull request](https://github.com/byu-oit/terraform-aws-lambda-api/pulls) to add the variable and reach 
 out to the Terraform Working Group on slack (`#terraform` channel).
