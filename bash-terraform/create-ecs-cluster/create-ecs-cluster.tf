resource "aws_ecs_cluster" "tf" {
  name = "MAIN_NAME_FIRST_UPPERCASE"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Environment = "ENVIRONMENT_NAME_UPPER"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }
}
