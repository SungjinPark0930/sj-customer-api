resource "aws_lb" "test" {
  name               = "ELB_NAME"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["CLOUDFRONT_SG1_ID", "CLOUDFRONT_SG2_ID", "SECURITY_GROUP_ID"]
  subnets            = ["ELB_PUBLIC_SUBNET_ID_01", "ELB_PUBLIC_SUBNET_ID_02"]
  enable_deletion_protection = true
  idle_timeout = 60
    tags = {
    Environment = "ENVIRONMENT_NAME"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }
}
