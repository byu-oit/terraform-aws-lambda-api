output "lambda" {
  value = aws_lambda_function.api_lambda
}

output "lambda_security_group" {
  value = aws_security_group.lambda_sg
}

output "lambda_live_alias" {
  value = var.use_codedeploy ? aws_lambda_alias.live_codedeploy[0] : aws_lambda_alias.live[0]
}

output "codedeploy_deployment_group" {
  value = var.use_codedeploy ? aws_codedeploy_deployment_group.deployment_group[0] : null
}

output "codedeploy_appspec_json_file" {
  value = var.use_codedeploy ? local_file.appspec_json.*.filename : null
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
