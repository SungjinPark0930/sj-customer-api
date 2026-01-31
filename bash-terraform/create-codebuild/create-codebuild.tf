resource "aws_codebuild_project" "tfer--codebuild-MAIN_NAME_FIRST_UPPERCASE-SERVICE_CLASSIFICATION_NAME" {
  artifacts {
    encryption_disabled    = "false"
    name                   = "MAIN_NAME_FIRST_UPPERCASE-SERVICE_CLASSIFICATION_NAME"
    override_artifact_name = "false"
    packaging              = "NONE"
    type                   = "CODEPIPELINE"
  }

  badge_enabled = "false"
  build_timeout = "60"

  cache {
    type = "NO_CACHE"
  }

  concurrent_build_limit = "1"
  description            = "MAIN_NAME_FIRST_UPPERCASE-SERVICE_CLASSIFICATION_NAME"
  encryption_key         = "arn:aws:kms:ap-northeast-2:AWS_ACCOUNT_NUMBER:alias/aws/s3"

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = "true"
    type                        = "LINUX_CONTAINER"

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      type  = "PLAINTEXT"
      value = "AWS_ACCOUNT_NUMBER"
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      type  = "PLAINTEXT"
      value = "ap-northeast-2"
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      type  = "PLAINTEXT"
      value = "ECR_NAME"
    }

    environment_variable {
      name  = "IMAGE_TAG"
      type  = "PLAINTEXT"
      value = "latest"
    }

    environment_variable {
      name  = "DEPLOY_SERVER"
      type  = "PLAINTEXT"
      value = "ENV_NAME_FIRST_UPPER"
    }

    environment_variable {
      name  = "S3_FOLDER_NAME"
      type  = "PLAINTEXT"
      value = "ENV_NAME_FIRST_UPPER_MAIN_NAME_SHORT_FIRST_UPPER_Lambda"
    }

    environment_variable {
      name  = "S3_BUCKET_NAME"
      type  = "PLAINTEXT"
      value = "ENVIRONMENT_NAME_LOWER-deploy"
    }
  }

  vpc_config {
    vpc_id            = "VPC_ID"
    subnets           = ["SUBNET1_ID", "SUBNET2_ID"]
    security_group_ids = ["CODEBUILD_SG_ID"]
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }

    s3_logs {
      encryption_disabled = "false"
      status              = "DISABLED"
    }
  }

  name               = "MAIN_NAME_FIRST_UPPERCASE-SERVICE_CLASSIFICATION_NAME"
  project_visibility = "PRIVATE"
  queued_timeout     = "480"
  service_role       = "arn:aws:iam::AWS_ACCOUNT_NUMBER:role/service-role/CODEBUILD_SERVICE_ROLE_NAME"

  source {
    buildspec           = "BUILDSPEC_FILE_NAME"
    git_clone_depth     = "0"
    insecure_ssl        = "false"
    report_build_status = "false"
    type                = "CODEPIPELINE"
  }

  tags = {
    ApplicationID = "APPLICATION_ID"
    Environment   = "ENVIRONMENT_NAME"
  }

  tags_all = {
    ApplicationID = "APPLICATION_ID"
    Environment   = "ENVIRONMENT_NAME"
  }
}
