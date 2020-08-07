data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  source_bucket_name      = "${var.textract_source_bucket_prefix}-${data.aws_caller_identity.current.account_id}"
  destination_bucket_name = "${var.textract_destination_bucket_prefix}-${data.aws_caller_identity.current.account_id}"
  processor_sqs_name      = "${var.textract_processor_sqs_name_prefix}-${data.aws_caller_identity.current.account_id}"
  results_sqs_name        = "${var.textract_results_sqs_name_prefix}-${data.aws_caller_identity.current.account_id}"
  default_tags = {
    Product = "Textract"
  }
}