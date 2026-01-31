resource "aws_iam_role" "test_role" {
  name = "oidc-creator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = [ "ec2.amazonaws.com", "eks.amazonaws.com" ]
        }
      },
    ]
  })

  tags = {
        Name = "xxxx",
        Environment = "DEV",
        ApplicationID = "APPLICATION_ID"
  }
}

