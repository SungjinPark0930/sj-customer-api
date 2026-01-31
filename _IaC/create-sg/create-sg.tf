resource "aws_security_group" "allow_tls" {
  name        = "SECURITY_GROUP_NAME"
  description = "SECURITY_GROUP_NAME"
  vpc_id      = "VPC_ID"

  tags = {
    Name = "SYSTEM_NAME_FIRST_UPPERCASE"
    Environment = "ENVIRONMENT_NAME"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }
}

output "sg_id" {
  value = aws_security_group.allow_tls.id
}
