provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_efs_file_system" "example" {
  throughput_mode = "bursting"
  encrypted = true
  kms_key_id = "arn:aws:kms:ap-northeast-2:xxxx:key/xxxx"
  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }

  tags = {
    Name = "xxxx"
    ApplicationID = "APPLICATION_ID"
    Environment = "DEV"
    DataClassification = "Internal"
  }
}

resource "aws_efs_backup_policy" "example" {
  file_system_id = aws_efs_file_system.example.id

  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_mount_target" "example" {
  for_each = toset(["SUBNET_NAME"])
  file_system_id  = aws_efs_file_system.example.id
  subnet_id       = each.value
  security_groups = ["SG_NAME"]
}

output "efs_id" {
  value = aws_efs_file_system.example.id
}
