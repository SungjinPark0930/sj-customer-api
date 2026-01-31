
resource "aws_cloudfront_distribution" "s3_distribution" {
origin {
    domain_name = "S3_ENDPOINT"
    origin_id   = "SYSTEM_NAME_ALL_UPPERCASE-S3"
    origin_access_control_id = "ORIGIN_ACCESS_CONTROL_ID_VALUE"
  }

origin {
    domain_name = "ELB_ENDPOINT"
    origin_id = "SYSTEM_NAME_ALL_UPPERCASE-ELB"
    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = ["TLSv1.2"]
      origin_read_timeout = 60
    }
  }

origin {
    domain_name = "HONEYPOT_ENDPOINT"
    origin_id = "SYSTEM_NAME_ALL_UPPERCASE-HONEYPOT"
    origin_path = "/ProdStage"
    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  # aliases = ["DOMAIN_NAME_VALUE"]
  default_root_object = "index.html"

  comment = "SYSTEM_NAME_ALL_UPPERCASE"
  web_acl_id = "WAF_ACL_VALUE"
  http_version = "http2and3"
  price_class = "PriceClass_All"
  enabled             = true
  is_ipv6_enabled     = false

  logging_config {
    include_cookies = false
    bucket          = "LOG_BUCKET_VALUE"
    prefix          = "DOMAIN_NAME_VALUE"
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    cache_policy_id  = "CACHE_POLICY_ID_COMMON_S3EC2"
    target_origin_id = "SYSTEM_NAME_ALL_UPPERCASE-S3"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "/v1/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    cache_policy_id  = "xxxx"
    origin_request_policy_id = "ORIGIN_REQUEST_POLICY_ID_MANAGED_ALL_VIEWER"
    target_origin_id = "SYSTEM_NAME_ALL_UPPERCASE-ELB"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  custom_error_response {
    error_code = 403
    error_caching_min_ttl = 10
    response_code = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code = 404
    error_caching_min_ttl = 10
    response_code = 404
    response_page_path = "/custom-error-page/404.html"
  }

  tags = {
    Environment = "ENVIRONMENT_NAME"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }

  restrictions {
    geo_restriction {
      locations = []
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn = "ACM_ARN_NVIRGINIA"
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method = "sni-only"
  }
}
