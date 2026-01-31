resource "aws_cloudwatch_event_rule" "my-job-queue" {
  description         = "MAIN_NAME_FIRST_UPPERCASE"
  event_bus_name      = "default"
  force_destroy       = "false"
  name                = "MAIN_NAME_FIRST_UPPERCASE"
  schedule_expression = "cron(0 15 * * ? *)"

  tags = {
    ApplicationID      = "xxxx"
    DataClassification = "Internal"
    Environment        = "ENVIRONMENT_NAME_UPPER"
  }

  tags_all = {
    ApplicationID      = "xxxx"
    DataClassification = "Internal"
    Environment        = "ENVIRONMENT_NAME_UPPER"
  }
}
