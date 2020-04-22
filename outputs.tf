output "lambda" {
  value = aws_lambda_function.api_lambda
}

output "lambda_security_group" {
  value = aws_security_group.lambda_sg
}

output "lambda_live_alias" {
  value = aws_lambda_alias.live
}

output "codedeploy_deployment_group" {
  value = aws_codedeploy_deployment_group.deployment_group
}

output "codedeploy_appspec_json_file" {
  value = local_file.appspec_json.filename
}

output "alb" {
  value = aws_alb.alb
}

output "alb_security_group" {
  value = aws_security_group.alb-sg
}

output "dns_record" {
  value = aws_route53_record.a_record
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.log_group
}
