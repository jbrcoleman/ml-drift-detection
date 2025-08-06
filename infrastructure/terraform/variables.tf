# infrastructure/terraform/variables.tf

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "mlops-drift-monitor"
}

variable "api_stage" {
  description = "API Gateway stage name"
  type        = string
  default     = "prod"
}

variable "drift_threshold" {
  description = "Threshold for drift detection alerts"
  type        = string
  default     = "2.0"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "enable_sns_alerts" {
  description = "Enable SNS alerts for monitoring"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "MLOps-Drift-Monitor"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}