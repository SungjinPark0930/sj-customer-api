resource "aws_codedeploy_app" "tfer" {
  compute_platform = "ECS"
  name             = "SYSTEM_NAME_ALL_UPPERCASE"

  tags = {
    Environment = "ENVIRONMENT_NAME_UPPER"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }
}
