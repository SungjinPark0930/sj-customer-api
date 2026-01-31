provider "aws" {
  region = "ap-northeast-2"  
}

resource "aws_s3_bucket_policy" "example" {
  bucket = "S3_BUCKET_NAME_VALUE"  

  policy = <<EOF
{
    "Version": "2008-10-17",
    "Id": "PolicyForCloudFrontPrivateContent",
    "Statement": [
        {
            "Sid": "AllowCloudFrontServicePrincipal",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudfront.amazonaws.com"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::S3_BUCKET_NAME_VALUE/*",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceArn": "arn:aws:cloudfront::AWS_ACCOUNT_NUMBER:distribution/CLOUDFRONT_ID_RECENT_VALUE"
                }
            }
        }
    ]
}
EOF
}

