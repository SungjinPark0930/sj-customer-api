resource "aws_db_instance" "default" {
  identifier                 = "xxxx"
  snapshot_identifier          = "rds:xxxx"
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
  instance_class             = "db.m6i.xlarge"
  kms_key_id                 = "xxxx"
  maintenance_window         = "fri:18:00-fri:18:30"
  monitoring_interval        = 0
  multi_az                   = false
  option_group_name          = "xxxx"
  parameter_group_name       = "xxxx"
  port                       = 1433
  password                   = "xxxx"
  skip_final_snapshot        = true
  storage_encrypted          = true
  storage_type               = "gp2"
  timezone                   = "Korea Standard Time"
  username                   = "xxxx"
  vpc_security_group_ids = ["sg-xxxx", "sg-xxxx"]
  domain_fqdn                = "xxxx"
  domain_ou                  = "xxxx"
  domain_auth_secret_arn     = "xxxx"
  domain_dns_ips             = ["xxxx", "xxxx"]
  copy_tags_to_snapshot      = true

  # allocated_storage          = 20
  # engine_version             = "15.00.4316.3.v1"
  # iops                       = 3000

  tags = {
    Name               = "xxxx"
    ApplicationID      = "APPLICATION_ID"
    Environment        = "PROD"
    DataClassification = "Internal"
  }
}
