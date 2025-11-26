data "aws_caller_identity" "current" {}
locals {
  tfstate_bucket_name = "cp-assignment-tfstate-${var.environment}-${data.aws_caller_identity.current.account_id}"
}
