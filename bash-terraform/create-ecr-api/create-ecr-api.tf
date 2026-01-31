resource "aws_ecr_repository" "tfer" {
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = "arn:aws:kms:ap-northeast-2:AWS_ACCOUNT_NUMBER:key/ECR_KMS_ID"
  }

  image_scanning_configuration {
    scan_on_push = "true"
  }

  image_tag_mutability = "MUTABLE"
  name                 = "ECR_NAME"

  tags = {
    ApplicationID     = "APPLICATION_ID"
    Environment       = "ENVIRONMENT_NAME_UPPER"
    DataClassification = "Internal"
  }
}

resource "aws_ecr_lifecycle_policy" "tfer" {
  policy = <<POLICY
{
  "rules": [
    {
      "action": {
        "type": "expire"
      },
      "description": "clean-up",
      "rulePriority": 1,
      "selection": {
        "countNumber": 1,
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "tagStatus": "untagged"
      }
    }
  ]
}
POLICY

  repository = "ECR_NAME"
}
