#param1: SYSTEM_NAME_VALUE
#param2: ELB_ARN_VALUE
#param3: ACM_ARN_VALUE
#param4: TG_ARN_VALUE
#param5: ENVIRONMENT_VALUE

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = "ELB_ARN"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = "ACM_ARN_SEOUL"

  default_action {
    type             = "forward"
    target_group_arn = "TARGET_GROUP_ARN"
  }

  tags = {
    Environment = "ENVIRONMENT_NAME"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }
}
