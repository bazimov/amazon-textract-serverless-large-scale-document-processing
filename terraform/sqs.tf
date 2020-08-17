resource "aws_sqs_queue" "textract_processor_dead_letter" {
  name_prefix = "${var.textract_processor_sqs_name_prefix}-dead-letter-"
  tags        = local.default_tags
}

resource "aws_sqs_queue" "textract_processor_queue" {
  name                       = local.processor_sqs_name
  kms_master_key_id          = aws_kms_key.textract_sqs.key_id
  delay_seconds              = 90
  visibility_timeout_seconds = var.timeout_value
  max_message_size           = 2048
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.textract_processor_dead_letter.arn
    maxReceiveCount     = 4
  })
  tags = local.default_tags
}

resource "aws_sqs_queue" "textract_results_dead_letter" {
  name_prefix = "${var.textract_results_sqs_name_prefix}-dead-letter-"
  tags        = local.default_tags
}

data "aws_iam_policy_document" "sqs_async_processor_policy" {
  statement {
    sid    = "SQSFromS3Access"
    effect = "Allow"
    actions = [
      "SQS:SendMessage",
    ]
    resources = [
      aws_sqs_queue.textract_processor_queue.arn
    ]
    principals {
      identifiers = ["s3.amazonaws.com"]
      type        = "Service"
    }
    condition {
      test     = "ArnEquals"
      values   = ["arn:aws:s3:*:*:${aws_s3_bucket.textract_source_bucket.bucket}"]
      variable = "aws:SourceArn"
    }
  }
}

resource "aws_sqs_queue_policy" "from_s3" {
  policy    = data.aws_iam_policy_document.sqs_async_processor_policy.json
  queue_url = aws_sqs_queue.textract_processor_queue.id
}

resource "aws_sqs_queue" "textract_results_queue" {
  name                       = local.results_sqs_name
  kms_master_key_id          = aws_kms_key.textract_sqs.key_id
  delay_seconds              = 90
  visibility_timeout_seconds = var.timeout_value
  max_message_size           = 2048
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.textract_results_dead_letter.arn
    maxReceiveCount     = 4
  })

  tags = local.default_tags
}

data "aws_iam_policy_document" "sqs_results_policy" {
  statement {
    sid    = "SQSFromSNSAccess"
    effect = "Allow"
    actions = [
      "SQS:SendMessage",
    ]
    resources = [
      aws_sqs_queue.textract_results_queue.arn
    ]
    principals {
      identifiers = ["sns.amazonaws.com"]
      type        = "Service"
    }
    condition {
      test     = "ArnEquals"
      values   = [aws_sns_topic.textract_results.arn]
      variable = "aws:SourceArn"
    }
  }
}

resource "aws_sqs_queue_policy" "from_sns" {
  policy    = data.aws_iam_policy_document.sqs_results_policy.json
  queue_url = aws_sqs_queue.textract_results_queue.id
}