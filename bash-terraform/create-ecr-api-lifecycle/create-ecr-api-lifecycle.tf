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
