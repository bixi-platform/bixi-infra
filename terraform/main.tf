terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment and configure for remote state in production:
  # backend "s3" {
  #   bucket = "bixi-terraform-state"
  #   key    = "prod/terraform.tfstate"
  #   region = "ca-central-1"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.env
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name_prefix = "${var.project}-${var.env}"

  # Resolved DATABASE_URL: prefer var.database_url; falls back to RDS endpoint
  # when RDS is provisioned.
  resolved_database_url = var.database_url != "" ? var.database_url : (
    var.enable_rds
    ? "postgres://${var.db_username}:${var.db_password}@${aws_db_instance.main[0].endpoint}/${var.db_name}"
    : ""
  )
}
