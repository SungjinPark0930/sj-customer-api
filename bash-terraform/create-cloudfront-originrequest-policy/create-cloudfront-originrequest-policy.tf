resource "aws_cloudfront_origin_request_policy" "example" {
  name    = "xxxx"
  comment = "xxxx"
  cookies_config {
    cookie_behavior = "allExcept"
    cookies {
        items = ["memberInfo", "originInfo"]
    }
  }
  headers_config {
    header_behavior = "allViewer"
  }
  query_strings_config {
    query_string_behavior = "all"
  }
}
