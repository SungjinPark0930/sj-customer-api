resource "aws_lambda_function" "example_lambda" {
  function_name = "xxxx"
  handler       = "lambda_function.lambda_handler"
  runtime       = "nodejs22.x"
  role          = "arn:aws:iam::xxxx:role/xxxx"
  filename      = "create-lambda.zip"
  timeout       = 180
  environment {
    variables = {
      ENV = "env"
    }
  }
  tags = {
    Environment = "PROD"
    ApplicationID = "APPLICATION_ID"
    DataClassification = "Internal"
  }
  vpc_config {
    subnet_ids         = ["subnet-xxxx", "subnet-xxxx"]
    security_group_ids = ["sg-xxxx"]
  }
}
