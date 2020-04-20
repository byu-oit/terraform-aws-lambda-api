![Latest GitHub Release](https://img.shields.io/github/v/release/byu-oit/terraform-aws-lambda-api?sort=semver)

# Terraform AWS Lambda API
Terraform module pattern to build a standard Lambda API.

This module uses CodeDeploy to deploy a Lambda behind an ALB.

Before switching production traffic to the new Lambda, CodeDeploy runs Postman tests.
This is done by:
 * Having all production traffic (ports `80`/`443`) sent to the Lambda considered `live`
 * Creating and deploying the new untested Lambda to `$LATEST`
 * Invoking a separate Lambda that runs Postman tests
   - These tests run against port `4443`, which corresponds to `$LATEST`
 * If the tests pass, we give the alias `live` to the now-tested `$LATEST` version of the Lambda
