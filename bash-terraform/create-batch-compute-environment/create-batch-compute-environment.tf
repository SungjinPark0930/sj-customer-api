# SG : DEV sg-xxxx    PROD

resource "aws_batch_compute_environment" "my-job-queue" {
  compute_environment_name = "my-job-queue"

  compute_resources {
    bid_percentage     = "0"
    desired_vcpus      = "0"
    max_vcpus          = "16"
    min_vcpus          = "0"
    security_group_ids = ["sg-xxxx"]
    subnets            = ["subnet-xxxx", "subnet-xxxx"]
    type               = "FARGATE"
  }

  service_role = "arn:aws:iam::xxxx:role/service-role/AWSBatchServiceRole"
  state        = "ENABLED"
  type         = "MANAGED"
}
