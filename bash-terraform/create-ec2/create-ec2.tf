data "aws_ami" "ami_os_type" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["EC2_OS_IMAGE"]
  }
}

resource "aws_instance" "example" {
  ami           = data.aws_ami.ami_os_type.id
  instance_type = "EC2_TYPE"
  subnet_id     = "EC2_MORE_IP_SUBNET"
  key_name      = "MAIN_NAME_FIRST_UPPERCASE-EC2_KEYPAIR_ALGORITHM"
  iam_instance_profile = "CORP-EC2SSMAdministrationInstanceRole"
  vpc_security_group_ids = ["EC2_APPLICATION_SG", "EC2_COMMON_SG"]
  disable_api_termination = true

  root_block_device {
    volume_size = EC2_ROOT_VOLUME_SIZE
    volume_type = "gp3"
    encrypted   = true
  }
  
  tags = {
    Name = "MAIN_NAME_FIRST_UPPERCASE_HOSTNAME"
    ApplicationID = "APPLICATION_ID"
    Environment = "ENVIRONMENT_NAME_UPPER"
    DataClassification = "Internal"
  }
  associate_public_ip_address = false
}

resource "aws_ebs_volume" "example" {
  availability_zone = "EC2_AVAILABILITY_ZONE"
  size = 5
  type = "gp3"
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.example.id
  instance_id = aws_instance.example.id
}
