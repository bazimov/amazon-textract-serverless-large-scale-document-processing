data "aws_iam_policy_document" "kms_shared_policy" {
  statement {
    sid    = "SQSAllowRootPolicy"
    effect = "Allow"
    actions = [
      "kms:*"
    ]
    resources = ["*"]
    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      type        = "AWS"
    }
  }

  statement {
    sid    = "Allow Access for Key Administrators"
    effect = "Allow"
    principals {
      identifiers = [
        aws_iam_role.kms_key_admin_role.arn,
        data.aws_caller_identity.current.user_id,
      ]
      type = "AWS"
    }
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "sqs_key_policy" {
  source_json = data.aws_iam_policy_document.kms_shared_policy.json
  statement {
    sid    = "SQSAllowS3"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
    ]
    resources = ["*"]
    principals {
      identifiers = [
        "s3.amazonaws.com",
        "sns.amazonaws.com",
      ]
      type = "Service"
    }
  }

  statement {
    sid    = "SQSAllowDefault"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:List*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    condition {
      test     = "StringEquals"
      values   = ["sqs.${data.aws_region.current.name}.amazonaws.com"]
      variable = "kms:ViaService"
    }
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "kms:CallerAccount"
    }
  }
}

data "aws_iam_policy_document" "sns_key_policy" {
  source_json = data.aws_iam_policy_document.kms_shared_policy.json

  statement {
    sid    = "SNSAllowDefault"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:List*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    principals {
      identifiers = [
        "sqs.amazonaws.com",
        "sns.amazonaws.com",
      ]
      type = "Service"
    }

    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "kms:CallerAccount"
    }
  }
  statement {
    sid    = "TextractRoleAllow"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:List*",
      "kms:DescribeKey",
      "kms:CreateGrant",
    ]
    resources = ["*"]
    principals {
      identifiers = [
        aws_iam_role.iam_for_textract_results_publisher.arn,
      ]
      type = "AWS"
    }
  }
}

data "aws_iam_policy_document" "s3_key_policy" {
  source_json = data.aws_iam_policy_document.kms_shared_policy.json

  statement {
    sid    = "S3AllowDefault"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:List*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    condition {
      test     = "StringEquals"
      values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
      variable = "kms:ViaService"
    }
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "kms:CallerAccount"
    }
  }
}

data "aws_iam_policy_document" "cloudwatch_logs_key_policy" {
  source_json = data.aws_iam_policy_document.kms_shared_policy.json

  statement {
    sid    = "LogsAllowDefault"
    effect = "Allow"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]
    principals {
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
      type        = "Service"
    }
    condition {
      test = "ArnEquals"
      values = [
        "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.processor_lambda_name}:*",
        "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.results_lambda_name}:*",
      ]
      variable = "kms:EncryptionContext:aws:logs:arn"
    }
  }
}

resource "aws_kms_key" "textract_sqs" {
  description             = "This key is used to encrypt data of textract sqs pipeline services"
  policy                  = data.aws_iam_policy_document.sqs_key_policy.json
  deletion_window_in_days = 30
  tags                    = local.default_tags
}

resource "aws_kms_alias" "textract_sqs_alias" {
  name_prefix   = "alias/textract-pipeline-sqs-"
  target_key_id = aws_kms_key.textract_sqs.key_id
}

resource "aws_kms_key" "textract_sns_key" {
  description             = "This key is used to encrypt data of textract sns pipeline services"
  policy                  = data.aws_iam_policy_document.sns_key_policy.json
  deletion_window_in_days = 30
  tags                    = local.default_tags
}

resource "aws_kms_alias" "textract_sns_alias" {
  name_prefix   = "alias/textract-pipeline-sns-"
  target_key_id = aws_kms_key.textract_sns_key.key_id
}

resource "aws_kms_key" "textract_s3_key" {
  description             = "This key is used to encrypt data of textract s3 pipeline services"
  policy                  = data.aws_iam_policy_document.s3_key_policy.json
  deletion_window_in_days = 30
  tags                    = local.default_tags
}

resource "aws_kms_alias" "textract_s3_alias" {
  name_prefix   = "alias/textract-pipeline-s3-"
  target_key_id = aws_kms_key.textract_s3_key.key_id
}

resource "aws_kms_key" "textract_cw_key" {
  description             = "This key is used to encrypt data of textract cloudwatch pipeline services"
  policy                  = data.aws_iam_policy_document.cloudwatch_logs_key_policy.json
  deletion_window_in_days = 30
  tags                    = local.default_tags
}

resource "aws_kms_alias" "textract_cw_alias" {
  name_prefix   = "alias/textract-pipeline-logs-"
  target_key_id = aws_kms_key.textract_cw_key.key_id
}

output "s3_kms_key_arn" {
  value = aws_kms_key.textract_s3_key.arn
}
