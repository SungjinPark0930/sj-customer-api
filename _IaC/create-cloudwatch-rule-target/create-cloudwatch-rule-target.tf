resource "aws_cloudwatch_event_target" "my-job-queue" {
  arn = "arn:aws:batch:ap-northeast-2:AWS_ACCOUNT_NUMBER:job-queue/MAIN_NAME_FIRST_UPPERCASE"

  batch_target {
    job_attempts   = "1"
    job_definition = "arn:aws:batch:ap-northeast-2:AWS_ACCOUNT_NUMBER:job-definition/MAIN_NAME_FIRST_UPPERCASE:1"
    job_name       = "MAIN_NAME_FIRST_UPPERCASE"
  }

  force_destroy = "false"
  role_arn      = "arn:aws:iam::AWS_ACCOUNT_NUMBER:role/BATCH_ROLE_NAME"
  rule          = "MAIN_NAME_FIRST_UPPERCASE"
}
