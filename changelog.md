# Changelog

## v2.0.0
2/24/2022 - Major breaking changes from v1.x:
- dropped support for terraform v0.12
- renamed `lambda_zip_file` variable to `zip_filename`
- renamed `handler` variable to `zip_handler`
- renamed `runtime` variable to `zip_runtime`
- renamed `appspec_filename` variable to `codedeploy_appspec_filename`
- removed `use_codedeploy` variable - just include the codedeploy variables to enable codedeploy
- removed `env` variable - just include the env inside the `app_name` variable 
- added `domain_url` variable to enable a custom API URL
