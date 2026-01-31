provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_rds_cluster_parameter_group" "default" {
  name        = "ENV_NAME_LOWER_THREE_CHARACTERMAIN_NAME_SHORT_LOWER-cluster"
  family      = "aurora-mysql8.0"
  description = "ENV_NAME_LOWER_THREE_CHARACTERMAIN_NAME_SHORT_LOWER-cluster"

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
  parameter {
    name  = "character_set_connection"
    value = "utf8"
  }
  parameter {
    name  = "character_set_database"
    value = "utf8"
  }
  parameter {
    name  = "character_set_filesystem"
    value = "utf8"
  }
  parameter {
    name  = "character_set_results"
    value = "utf8"
  }
  parameter {
    name  = "character_set_server"
    value = "utf8"
  }
  parameter {
    name  = "time_zone"
    value = "Asia/Seoul"
  }
  parameter {
    name  = "max_connect_errors"
    value = "9223372036854775807"
  }

}

resource "aws_db_parameter_group" "default" {
  name   = "ENV_NAME_LOWER_THREE_CHARACTERMAIN_NAME_SHORT_LOWER-db"
  family = "aurora-mysql8.0"
  description = "ENV_NAME_LOWER_THREE_CHARACTERMAIN_NAME_SHORT_LOWER-db"

  parameter {
    name  = "max_connect_errors"
    value = "9223372036854775807"
  }
}

resource "aws_rds_cluster" "example" {
  backup_retention_period = 7
  cluster_identifier   = "ENV_NAME_LOWER_THREE_CHARACTERMAIN_NAME_SHORT_LOWER"
  engine               = "aurora-mysql"
  engine_mode          = "provisioned"
  engine_version       = "8.0.mysql_aurora.3.08.2"
  master_username      = "xxxx"
  master_password      = "xxxx"
  kms_key_id           = "arn:aws:kms:ap-northeast-2:AWS_ACCOUNT_NUMBER:key/DB_KMS_KEY_ID"
  db_subnet_group_name = "DB_SUBNET_GROUP_NAME_VALUE"
  db_cluster_parameter_group_name = "ENV_NAME_LOWER_THREE_CHARACTERMAIN_NAME_SHORT_LOWER-cluster"
  deletion_protection  = true
  port		       = 3306
  preferred_backup_window      = "16:00-17:00"
  preferred_maintenance_window = "fri:18:00-fri:18:30"
  serverlessv2_scaling_configuration {
    max_capacity       = 2.0
    min_capacity       = 0.5
  }
  storage_encrypted          = true
  tags = {
    Name               = "MAIN_NAME_FIRST_UPPERCASE"
    ApplicationID      = "APPLICATION_ID"
    Environment        = "ENVIRONMENT_NAME_UPPER"
    DataClassification = "Internal"
    Schedule           = "24hours"
  }
  vpc_security_group_ids = ["DB_SG_ID_COMMON", "DB_SG_ID_SERVICE"]
}

resource "aws_rds_cluster_instance" "example" {
  auto_minor_version_upgrade = true
  ca_cert_identifier      = "rds-ca-rsa2048-g1"
  cluster_identifier      = aws_rds_cluster.example.id
  db_subnet_group_name    = "DB_SUBNET_GROUP_NAME_VALUE"
  db_parameter_group_name = "ENV_NAME_LOWER_THREE_CHARACTERMAIN_NAME_SHORT_LOWER-db"
  instance_class          = "db.serverless"
  identifier 	          = "ENV_NAME_LOWER_THREE_CHARACTERMAIN_NAME_SHORT_LOWER-instance1"
  engine                  = aws_rds_cluster.example.engine
  engine_version          = aws_rds_cluster.example.engine_version
  preferred_maintenance_window = "fri:18:00-fri:18:30"
  performance_insights_enabled = true
}
