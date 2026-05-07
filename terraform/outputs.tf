output "models_bucket" {
  description = "S3 bucket for XGBoost model artifacts"
  value       = aws_s3_bucket.models.bucket
}

output "lambda_zips_bucket" {
  description = "S3 bucket for Lambda deployment zips"
  value       = aws_s3_bucket.lambda_zips.bucket
}

output "frontend_bucket" {
  description = "S3 bucket for Angular static assets"
  value       = aws_s3_bucket.frontend.bucket
}

output "collector_lambda_arn" {
  description = "ARN of the collector Lambda function"
  value       = aws_lambda_function.collector.arn
}

output "inference_lambda_arn" {
  description = "ARN of the inference Lambda function"
  value       = aws_lambda_function.inference.arn
}

output "api_url" {
  description = "Public URL of the Go REST API (ALB DNS)"
  value       = var.enable_ecs ? "http://${aws_lb.api[0].dns_name}" : "ECS disabled"
}

output "frontend_url" {
  description = "CloudFront URL for the Angular frontend"
  value       = var.enable_cloudfront ? "https://${aws_cloudfront_distribution.frontend[0].domain_name}" : "CloudFront disabled"
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = var.enable_rds ? aws_db_instance.main[0].endpoint : "RDS disabled (using external DB)"
  sensitive   = false
}
