resource "aws_route53_record" "root_domain" {
  zone_id = "ROUTE53_ZONE_ID_VALUE"
  name    = "RECORD_NAME_VALUE"
  type    = "CNAME"
  ttl     = 300
  records = ["CNAME_VALUE"]
}
