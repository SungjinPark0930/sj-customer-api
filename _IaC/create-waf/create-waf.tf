provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

resource "aws_wafv2_web_acl" "example" {
  provider = aws.east
  name        = "MAIN_NAME_FIRST_UPPERCASE"
  description = "MAIN_NAME_FIRST_UPPERCASE"
  scope       = "CLOUDFRONT"

  default_action {
    WAF_DEFAULT_ACTION {}
  }

  rule {
    name     = "Whitelist"
    priority = 0

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = "arn:aws:wafv2:us-east-1:AWS_ACCOUNT_NUMBER:global/ipset/Whitelist/WAF_WHITELIST_ID"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "Whitelist"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 9

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override { 
          action_to_use { 
            count {} 
            }
          name = "SizeRestrictions_QUERYSTRING"
        }

        rule_action_override {
          action_to_use {
            count {}
          }
          name = "SizeRestrictions_Cookie_HEADER"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                 = "AWS-AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Environment = "ENVIRONMENT_NAME_UPPER"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "waf"
  }
 }
