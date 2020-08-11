resource "aws_s3_bucket" "textract_source_bucket" {
  bucket = local.source_bucket_name
  policy = data.aws_iam_policy_document.s3_source_bucket_policy.json
  tags   = local.default_tags

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.textract_s3_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  depends_on = [aws_sqs_queue.textract_processor_queue, aws_s3_bucket.textract_source_bucket]
  bucket     = aws_s3_bucket.textract_source_bucket.id

  queue {
    queue_arn     = aws_sqs_queue.textract_processor_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".pdf" # This can be removed if you want all files.
  }
}
