# output "appspec" {
#   value = local_file.appspec_json.content
# }

output "dns_record" {
  value = aws_route53_record.a_record
}
