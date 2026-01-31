resource "aws_lb_target_group" "test" {
  name     = "TARGET_GROUP_NAME"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "VPC_ID"
  deregistration_delay = 60

  health_check {
    interval = 30
    healthy_threshold = 2
    unhealthy_threshold = 2
  }

  #stickiness {
  #  type            = "lb_cookie"
  #  cookie_duration = 3600
  #}
  
  target_type = "instance"

  tags = {
    Environment = "ENVIRONMENT_NAME"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }
}
