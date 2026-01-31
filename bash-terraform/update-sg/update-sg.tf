resource "aws_security_group_rule" "xxxx" {
  security_group_id = "sg-xxxx"
  type              = "ingress"
  cidr_blocks       = ["192.20.20.0/24"]
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  description       = "xxxx"
}

