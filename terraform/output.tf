output "api_rest_url" {
  value = aws_lambda_function_url.url.function_url
}
