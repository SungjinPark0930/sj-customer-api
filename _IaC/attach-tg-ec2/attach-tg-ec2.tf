param1: TG_ARN_VALUE
param2: EC2_ID_VALUE

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = "TG_ARN_VALUE"
  target_id        = "EC2_ID_VALUE"
  port             = 80
}