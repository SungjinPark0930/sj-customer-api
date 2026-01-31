terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

########################
# Variables
########################
variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "identity_pool_name" {
  description = "Cognito Identity Pool name"
  type        = string
  default     = "MAIN_NAME_FIRST_UPPERCASE"
}

variable "auth_role_name" {
  description = "IAM role name for authenticated users"
  type        = string
  default     = "MAIN_NAME_FIRST_UPPERCASE-auth"
}

variable "unauth_role_name" {
  description = "IAM role name for guest (unauthenticated) users"
  type        = string
  default     = "MAIN_NAME_FIRST_UPPERCASE-unauth"
}

########################
# Locals
########################
locals {
  common_tags = {
    ApplicationID      = "APPLICATION_ID"
    Environment        = "PROD"
    DataClassification = "Internal"
  }
}

########################
# Provider
########################
provider "aws" {
  region = var.region
}

########################
# Cognito Identity Pool
########################
resource "aws_cognito_identity_pool" "this" {
  identity_pool_name               = var.identity_pool_name
  allow_unauthenticated_identities = true
  allow_classic_flow               = false

  tags = local.common_tags
}

########################
# IAM Role - Guest / Unauthenticated
########################
resource "aws_iam_role" "unauth" {
  name = var.unauth_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CognitoUnauthAssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.this.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "unauthenticated"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

########################
# IAM Role - Authenticated
########################
resource "aws_iam_role" "auth" {
  name = var.auth_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CognitoAuthAssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.this.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

########################
# Identity Pool Role Attachment (중요: 1개만)
########################
resource "aws_cognito_identity_pool_roles_attachment" "this" {
  identity_pool_id = aws_cognito_identity_pool.this.id

  roles = {
    authenticated   = aws_iam_role.auth.arn
    unauthenticated = aws_iam_role.unauth.arn
  }
}

