# infrastructure/terraform/terraform.tfvars.example
# Copy this to terraform.tfvars and customize for your environment

aws_region         = "us-east-1"
project_name       = "mlops-drift-monitor"
api_stage          = "dev"
drift_threshold    = "2.0"
log_retention_days = 14
enable_sns_alerts  = true
alert_email        = "testl@test.com"

tags = {
  Project     = "MLOps-Drift-Monitor"
  Environment = "dev"
  ManagedBy   = "Terraform"
  Owner       = "MLOps"
}