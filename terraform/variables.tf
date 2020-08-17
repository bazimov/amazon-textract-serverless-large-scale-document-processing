variable "textract_source_bucket_prefix" {
  default = "textract-source-bucket"
}

variable "textract_destination_bucket_prefix" {
  default = "textract-destination-bucket"
}

variable "textract_results_sns_name_prefix" {
  default = "textract-results"
}

variable "textract_processor_sqs_name_prefix" {
  default = "textract-processor-queue"
}

variable "textract_results_sqs_name_prefix" {
  default = "textract-results-queue"
}

variable "lambda_role_name" {
  default = "textract-processor-lambda-role"
}

variable "textract_results_role_name" {
  default = "textract-results-publisher-role"
}

variable "processor_lambda_name" {
  default = "textract-processor-function"
}

variable "results_lambda_name" {
  default = "textract-results-function"
}

variable "comprehend_lambda_name" {
  default = "comprehend-processor-function"
}
