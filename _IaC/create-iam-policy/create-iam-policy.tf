resource "aws_iam_policy" "policy" {
  name        = "xxxx"
  path        = "/"
  description = "."

  policy = jsonencode(

  )

  tags = {
    ApplicationID = "APPLICATION_ID"
    Environment = "ENVIRONMENT_NAME_UPPER"
    Classification = "Internal"
  }

}
