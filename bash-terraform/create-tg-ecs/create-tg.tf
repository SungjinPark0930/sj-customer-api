resource "aws_lb_target_group" "test" {
  name     = "TARGET_GROUP_NAME"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "VPC_ID"
  deregistration_delay = 60

  health_check {
    interval = 120
    healthy_threshold = 5
    unhealthy_threshold = 2
    path                = "ELB_HEALTHCHECK_PATH"
  }

  target_type = "ip"

  tags = {
    Environment = "ENVIRONMENT_NAME"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }
}
