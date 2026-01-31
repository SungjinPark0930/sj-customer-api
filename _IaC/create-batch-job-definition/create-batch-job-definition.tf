resource "aws_batch_job_definition" "test" {
  name = "MAIN_NAME_FIRST_UPPERCASE"
  type = "container"

  platform_capabilities = [
    "FARGATE",
  ]

  container_properties = jsonencode({
    command    = ["curl", "https://xxxx/v1/api/solr"]
    image      = "public.ecr.aws/amazonlinux/amazonlinux:latest"

    fargatePlatformConfiguration = {
      platformVersion = "LATEST"
    }

    resourceRequirements = [
      {
        type  = "VCPU"
        value = "0.25"
      },
      {
        type  = "MEMORY"
        value = "512"
      }
    ]

    executionRoleArn = "arn:aws:iam::AWS_ACCOUNT_NUMBER:role/ecsTaskExecutionRole"
  })

  timeout {
    attempt_duration_seconds = 600
  }

  tags = {
	ApplicationID      = "APPLICATION_ID"
	Environment        = "ENVIRONMENT_NAME_UPPER"
	DataClassification = "Internal"
  }
}
