resource "aws_cloudfront_origin_access_control" "example" {
  name                              = "MAIN_NAME_ALL_UPPERCASE"
  description                       = "Origin-Access-Control"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
