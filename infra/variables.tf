variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
  default     = "CHECKPOINT"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "cp-assignment"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "validator_service_port" {
  description = "Port for validator service"
  type        = number
  default     = 8080
}

variable "validator_service_cpu" {
  description = "CPU units for validator service"
  type        = number
  default     = 256
}

variable "validator_service_memory" {
  description = "Memory for validator service"
  type        = number
  default     = 512
}

variable "uploader_service_cpu" {
  description = "CPU units for uploader service"
  type        = number
  default     = 256
}

variable "uploader_service_memory" {
  description = "Memory for uploader service"
  type        = number
  default     = 512
}

variable "poll_interval" {
  description = "SQS poll interval in seconds"
  type        = number
  default     = 10
}
