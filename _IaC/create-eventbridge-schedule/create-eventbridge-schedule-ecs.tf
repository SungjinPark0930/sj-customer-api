provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_scheduler_schedule" "example" {
  name                  = "xxxx"
  schedule_expression   = "cron(0 9 1 1 ? *)"
  schedule_expression_timezone = "Asia/Seoul"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn                = "arn:aws:ecs:ap-northeast-2:xxxx:cluster/xxxx"
    role_arn           = "arn:aws:iam::314757280827:role/xxxxDevEventbridgeCommon"

    ecs_parameters {
      launch_type         = "FARGATE"                          # Fargate로 작업 실행
      network_configuration {
          subnets         = ["subnet-xxxx", "subnet-xxxx"]
          assign_public_ip = false
          security_groups  = ["sg-xxxx"]
      }
    task_definition_arn = "arn:aws:ecs:ap-northeast-2:xxxx:task-definition/xxxx"
    }
  }
}
