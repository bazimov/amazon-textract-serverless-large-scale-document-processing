data "aws_iam_policy_document" "s3_source_bucket_policy" {
  statement {
    sid    = "DenyUnEncryptedObjectUploads"
    effect = "Deny"
    actions = [
      "s3:PutObject",
    ]
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    resources = [
      "arn:aws:s3:::${local.source_bucket_name}/*"
    ]
    condition {
      test     = "Null"
      values   = [true]
      variable = "s3:x-amz-server-side-encryption"
    }
  }
}

data "aws_iam_policy_document" "textract_processor_lambda" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "textract_results_assume_policy" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      identifiers = ["textract.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "textract_results_sns_policy" {
  statement {
    sid    = "KMSPolicy"
    effect = "Allow"
    actions = [
      "kms:CreateGrant",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:ListAliases",
      "kms:ListKeys",
    ]
    resources = [
      aws_kms_key.textract_sns_key.arn,
    ]
  }

  statement {
    sid    = "TextractSNSPublish"
    effect = "Allow"
    actions = [
      "sns:Publish",
    ]
    resources = [
      aws_sns_topic.textract_results.arn,
    ]
  }
}

data "aws_iam_policy_document" "cloudwatch_logs" {
  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:*:*:*",
    ]
  }
}

data "aws_iam_policy_document" "lambda_shared_policy" {
  source_json = data.aws_iam_policy_document.cloudwatch_logs.json
  statement {
    sid    = "TextractPermissions"
    effect = "Allow"
    actions = [
      "textract:AnalyzeDocument",
      "textract:DetectDocumentText",
      "textract:GetDocumentAnalysis",
      "textract:GetDocumentTextDetection",
      "textract:StartDocumentAnalysis",
      "textract:StartDocumentTextDetection",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KMSPolicy"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:ListAliases",
      "kms:ListKeys",
    ]
    resources = [
      aws_kms_key.textract_s3_key.arn,
    ]
  }

  # TODO: separate policies for lambda roles
  statement {
    sid    = "S3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject*",
      "s3:GetBucket*",
      "s3:List*",
      "s3:DeleteObject*",
      "s3:PutObject*",
      "s3:Abort*",
    ]
    resources = [
      aws_s3_bucket.textract_source_bucket.arn,
      "${aws_s3_bucket.textract_source_bucket.arn}/*",
    ]
  }

  statement {
    sid    = "ComprehendAccess"
    effect = "Allow"
    actions = [
      "comprehend:DetectEntities",
      "comprehend:DetectKeyPhrases",
    ]
    resources = ["*"]
  }
}


data "aws_iam_policy_document" "stream_policy_document" {
  statement {
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:ChangeMessageVisibilityBatch",
      "sqs:DeleteMessage",
      "sqs:DeleteMessageBatch",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage"
    ]

    resources = [
      aws_sqs_queue.textract_processor_queue.arn,
      aws_sqs_queue.textract_results_queue.arn,
    ]
  }
}

data "aws_iam_policy_document" "kms_key_admin_assume_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      type        = "AWS"
    }
    condition {
      test     = "StringEquals"
      values   = [md5("external id")]
      variable = "sts:ExternalId"
    }
  }
}
