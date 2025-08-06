# infrastructure/terraform/outputs.tf

# infrastructure/terraform/outputs.tf

output "ecr_repository_url" {
  description = "URL of the ECR repository for Lambda container images"
  value       = aws_ecr_repository.lambda_repo.repository_url
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = "https://${aws_api_gateway_rest_api.model_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${var.api_stage}/predict"
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.model_api.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.model_api.arn
}

output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.mlops_dashboard.dashboard_name}"
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = var.enable_sns_alerts ? aws_sns_topic.alerts[0].arn : null
}

output "test_curl_command" {
  description = "cURL command to test the API"
  value = <<EOT
curl -X POST https://${aws_api_gateway_rest_api.model_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${var.api_stage}/predict \
  -H "Content-Type: application/json" \
  -d '{"features": {"bedrooms": 3, "bathrooms": 2, "sqft": 2000, "age": 10, "location_score": 7}}'
EOT
}