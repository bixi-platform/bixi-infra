variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ca-central-1"
}

variable "project" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "bixi"
}

variable "env" {
  description = "Deployment environment (dev, prod)"
  type        = string
  default     = "prod"
}

variable "database_url" {
  description = "PostgreSQL connection string (RDS in prod, local PG for dev)"
  type        = string
  sensitive   = true
}

variable "model_bucket_name" {
  description = "S3 bucket name for XGBoost model artifacts"
  type        = string
  default     = "bixi-models"
}

variable "frontend_bucket_name" {
  description = "S3 bucket name for Angular static assets"
  type        = string
  default     = "bixi-frontend"
}

# ── Conditional features ─────────────────────────────────────────────────────

variable "enable_rds" {
  description = "Provision RDS. Set false when testing locally against a native PG."
  type        = bool
  default     = true
}

variable "enable_ecs" {
  description = "Provision ECS Fargate + ALB for the Go API."
  type        = bool
  default     = true
}

variable "enable_cloudfront" {
  description = "Provision CloudFront distribution for the frontend."
  type        = bool
  default     = true
}

# ── RDS config (used when enable_rds = true) ─────────────────────────────────

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "bixi"
}

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "bixi"
}

variable "db_password" {
  description = "PostgreSQL master password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_allocated_storage_gb" {
  description = "RDS gp3 allocated storage in GB"
  type        = number
  default     = 50
}

# ── ECS / API config ──────────────────────────────────────────────────────────

variable "api_image" {
  description = "Docker image URI for the Go API (ECR or DockerHub)"
  type        = string
  default     = ""
}

variable "api_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "api_memory_mb" {
  description = "Fargate task memory in MB"
  type        = number
  default     = 512
}

variable "vpc_id" {
  description = "VPC ID to deploy into (ECS + RDS)"
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks and RDS"
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
  default     = []
}
