resource "aws_cloudfront_cache_policy" "example" {
  name        = "SYSTEM_NAME_VALUE"
  comment     = "CachePolicy"
  default_ttl = 1800
  max_ttl     = 1800
  min_ttl     = 0
  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
      headers {
        items = []
      }
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}