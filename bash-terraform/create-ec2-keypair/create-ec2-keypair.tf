provider "aws" {
  region = "ap-northeast-2"
}

resource "tls_private_key" "default" {
  algorithm = "EC2_KEYPAIR_ALGORITHM"
}

resource "aws_key_pair" "default" {
  key_name   = "MAIN_NAME_FIRST_UPPERCASE-EC2_KEYPAIR_ALGORITHM"
  public_key = tls_private_key.default.public_key_openssh

  tags = {
    Environment = "ENVIRONMENT_NAME_UPPER"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }
}

resource "local_file" "private_key_pem" {
  filename        = "MAIN_NAME_FIRST_UPPERCASE-EC2_KEYPAIR_ALGORITHM.pem"
  content         = tls_private_key.default.EC2_KEYPAIR_TYPE
  file_permission = "0600"
}
