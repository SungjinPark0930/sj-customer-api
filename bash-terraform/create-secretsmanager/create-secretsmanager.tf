resource "aws_secretsmanager_secret" "tfer" {
  description = "xxxx"
  name        = "xxxx"

  tags = {
    ApplicationID = "APPLICATION_ID"
    Environment   = "DEV"
  }

  tags_all = {
    ApplicationID = "APPLICATION_ID"
    Environment   = "DEV"
  }
}