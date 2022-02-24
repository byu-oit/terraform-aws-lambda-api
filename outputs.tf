output "lambda" {
  value = local.use_zip ? aws_lambda_function.zip_api[0] : aws_lambda_function.docker_api[0]
}

output "lambda_security_group" {
  value = length(aws_security_group.lambda_sg) > 0 ? aws_security_group.lambda_sg[0] : null
}

output "lambda_live_alias" {
  value = length(aws_lambda_alias.live_codedeploy) > 0 ? aws_lambda_alias.live_codedeploy[0] : aws_lambda_alias.live[0]
}

output "codedeploy_deployment_group" {
  value = length(aws_codedeploy_deployment_group.deployment_group) > 0 ? aws_codedeploy_deployment_group.deployment_group[0] : null
}

output "codedeploy_appspec_json_file" {
  value = length(local_file.appspec_json) > 0 ? local_file.appspec_json[0].filename : null
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
