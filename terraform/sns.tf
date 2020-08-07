resource "aws_sns_topic" "textract_results" {
  name_prefix = var.textract_results_sns_name_prefix
  # kms_master_key_id = aws_kms_key.textract_kms_key.key_id
  tags = local.default_tags
}

resource "aws_sns_topic_subscription" "textract_results_sqs_target" {
  topic_arn = aws_sns_topic.textract_results.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.textract_results_queue.arn
}
