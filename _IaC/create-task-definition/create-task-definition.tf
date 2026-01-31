resource "aws_ecs_task_definition" "tfer" {
  container_definitions    = "xxxxxx"
  cpu                      = "ECS_CPU_SIZE"
  execution_role_arn       = "arn:aws:iam::AWS_ACCOUNT_NUMBER:role/ecsTaskExecutionRole"
  family                   = "SYSTEM_NAME_FIRST_UPPERCASE"
  memory                   = "ECS_MEM_SIZE"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  volume {
    name = "oneagent"
  }

  tags = {
    Environment = "ENVIRONMENT_NAME_UPPER"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }
}
