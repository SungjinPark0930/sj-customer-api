#param1 FULL_DOMAIN_NAME_VALUE
#param2 BASE_DOMAIN_NAME_VALUE 

resource "aws_acm_certificate" "example" {
  domain_name       = "FULL_DOMAIN_NAME_VALUE"
  validation_method = "DNS"

  tags = {
    Environment = "ENVIRONMENT_NAME_UPPER"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }
}

data "aws_route53_zone" "example" {
  name         = "BASE_DOMAIN_NAME_VALUE"
  private_zone = false
}

resource "aws_route53_record" "example" {
  for_each = {
    for dvo in aws_acm_certificate.example.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.example.zone_id
}
