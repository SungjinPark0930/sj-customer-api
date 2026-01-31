resource "aws_codepipeline" "tfer-codepipeline" {
  artifact_store {
    location = "ARTIFACT_LOCATION"
    type     = "S3"
  }

  name     = "MAIN_NAME_FIRST_UPPERCASE-SERVICE_CLASSIFICATION_NAME"
  role_arn = "arn:aws:iam::AWS_ACCOUNT_NUMBER:role/service-role/CODEPIPELINE_SERVICE_ROLE_NAME"

  stage {
    action {
      category = "Source"

      configuration = {
        BranchName           = "BRANCH_NAME_VALUE"
        ConnectionArn        = "GITHUB_CONNECTION_ARN"
        FullRepositoryId     = "FULL_REPOSITORY_ID_VALUE"
        OutputArtifactFormat = "CODE_ZIP"
      }

      name             = "Source"
      namespace        = "SourceVariables"
      output_artifacts = ["SourceArtifact"]
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      region           = "ap-northeast-2"
      run_order        = "1"
      version          = "1"
    }

    name = "Source"
  }

  stage {
    action {
      category = "Build"

      configuration = {
        ProjectName = "MAIN_NAME_FIRST_UPPERCASE-SERVICE_CLASSIFICATION_NAME"
      }

      input_artifacts  = ["SourceArtifact"]
      name             = "Build"
      namespace        = "BuildVariables"
      output_artifacts = ["BuildArtifact"]
      owner            = "AWS"
      provider         = "CodeBuild"
      region           = "ap-northeast-2"
      run_order        = "2"  # Change the run_order to ensure the Build stage runs after the Source stage
      version          = "1"
    }

    name = "Build"
  }

  stage {
    action {
      category = "Deploy"

      configuration = {
        AppSpecTemplateArtifact        = "BuildArtifact"
        AppSpecTemplatePath            = "APPSPEC_FILE_NAME"
        ApplicationName                = "SYSTEM_NAME_ALL_UPPERCASE"
        DeploymentGroupName            = "SYSTEM_NAME_ALL_UPPERCASE"
        TaskDefinitionTemplateArtifact = "BuildArtifact"
        TaskDefinitionTemplatePath     = "TASK_DEFINITION_FILE_NAME"
      }

      input_artifacts = ["BuildArtifact"]
      name            = "Deploy"
      namespace       = "DeployVariables"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      region          = "ap-northeast-2"
      run_order       = "1"
      version         = "1"
    }

    name = "Deploy"
  }

  tags = {
    Environment = "ENVIRONMENT_NAME_UPPER"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }

  tags_all = {
    Environment = "ENVIRONMENT_NAME_UPPER"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }
}
