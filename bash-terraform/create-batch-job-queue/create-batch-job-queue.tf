resource "aws_batch_job_queue" "my-job-queue" {
  name     = "MAIN_NAME_FIRST_UPPERCASE"
  priority = 1
  state    = "ENABLED"

  compute_environment_order {
    order               = 1
    compute_environment = "BATCH_COMPUTE_ENVIRONMENT"
  }

  tags = {
    Name          = "MAIN_NAME_FIRST_UPPERCASE"
    ApplicationID = "APPLICATION_ID"
    Environment   = "ENVIRONMENT_NAME_UPPER"
  }
}

