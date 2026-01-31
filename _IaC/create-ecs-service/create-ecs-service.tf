resource "aws_ecs_service" "tf" {
  cluster = "MAIN_NAME_FIRST_UPPERCASE"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  deployment_maximum_percent         = "200"
  deployment_minimum_healthy_percent = "100"
  desired_count                      = "1"
  enable_ecs_managed_tags            = "true"
  enable_execute_command             = "false"
  health_check_grace_period_seconds  = "60"
  launch_type                        = "FARGATE"

  load_balancer {
    container_name   = "SYSTEM_NAME_FIRST_UPPERCASE"
    container_port   = "PORT_NUMBER_CONTAINER"
    target_group_arn = "TARGET_GROUP_ARN"
  }

  name = "SYSTEM_NAME_FIRST_UPPERCASE"

  network_configuration {
    assign_public_ip = "false"
    security_groups  = ["SECURITY_GROUP_ID"]
    subnets          = ["SUBNET1_ID", "SUBNET2_ID"]
  }

  platform_version    = "1.4.0"
  scheduling_strategy = "REPLICA"
  task_definition     = "arn:aws:ecs:ap-northeast-2:AWS_ACCOUNT_NUMBER:task-definition/SYSTEM_NAME_FIRST_UPPERCASE:TASK_DEFINITION_REVISION_NUMBER"

  tags = {
    Environment = "ENVIRONMENT_NAME_UPPER"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }
}
