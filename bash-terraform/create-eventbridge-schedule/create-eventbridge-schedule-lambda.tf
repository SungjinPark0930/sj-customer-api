provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_scheduler_schedule" "example" {
  name                  = "xxxx"
  schedule_expression   = "cron(0 9 1 1 ? *)"
  flexible_time_window {
    mode = "OFF"
  }
  target {
    arn       = "arn:aws:lambda:ap-northeast-2:xxxx:function:xxxx"
    role_arn  = "arn:aws:iam::xxxx:role/xxxx"
  }
}

