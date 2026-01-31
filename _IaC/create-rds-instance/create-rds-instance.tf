resource "aws_db_instance" "default" {
  allocated_storage          = 20
  auto_minor_version_upgrade = true
  availability_zone          = "ap-northeast-2c"
  backup_retention_period    = 7
  backup_window              = "16:00-17:00"
  ca_cert_identifier         = "rds-ca-rsa2048-g1"
  character_set_name         = "Korean_Wansung_CI_AS"
  db_subnet_group_name       = "xxxx"
  deletion_protection        = true
  enabled_cloudwatch_logs_exports = ["agent", "error"]
  engine                     = "sqlserver-web"
  engine_version             = "15.00.4316.3.v1"
  instance_class             = "db.t3.small"
  identifier                 = "xxxx"
  iops                       = 3000
  kms_key_id                 = "arn:aws:kms:ap-northeast-2:xxxx:key/xxxx"
  maintenance_window         = "fri:18:00-fri:18:30"
  monitoring_interval        = 0
  multi_az                   = false
  option_group_name          = "xxxx"
  parameter_group_name       = "xxxx"
  port                       = 1433
  password                   = "xxxx"
  skip_final_snapshot        = true
  storage_encrypted          = true
  storage_type               = "gp3"
  timezone                   = "Korea Standard Time"
  username                   = "xxxx"
  vpc_security_group_ids = ["sg-xxxx", "sg-xxxx"]
  tags = {
    Name               = "xxxx"
    ApplicationID      = "APPLICATION_ID"
    Environment        = "PROD"
    DataClassification = "Internal"
  }
}