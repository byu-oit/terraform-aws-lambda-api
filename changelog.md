# Changelog

## v2.0.0
2/24/2022 - Major breaking changes from v1.x:
- dropped support for terraform v0.12
- renamed `lambda_zip_file` to `zip_filename`
- renamed `handler` to `zip_handler`
- renamed `runtime` to `zip_runtime`
- renamed `appspec_filename` to `codedeploy_appspec_filename`
- removed `use_codedeploy` - just include the codedeploy variables to enable codedeploy
- added `domain_url` variable to enable a custom API URL
