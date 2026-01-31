resource "aws_codedeploy_deployment_group" "example" {
  app_name               = "SYSTEM_NAME_ALL_UPPERCASE"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "SYSTEM_NAME_ALL_UPPERCASE"
  service_role_arn       = "arn:aws:iam::AWS_ACCOUNT_NUMBER:role/ecsCodeDeployRole"

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 0
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = "MAIN_NAME_FIRST_UPPERCASE"
    service_name = "SYSTEM_NAME_FIRST_UPPERCASE"
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = ["ELB_LISTENER_ARN"]
      }

      target_group {
        name = "TARGET_GROUP_NAME_01"
      }

      target_group {
        name = "TARGET_GROUP_NAME_02"
      }
    }
  }

  tags = {
    Environment = "ENVIRONMENT_NAME_UPPER"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }
}
