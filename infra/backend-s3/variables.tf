variable "environment" {
  description = "The environment for which to create the S3 bucket (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}   