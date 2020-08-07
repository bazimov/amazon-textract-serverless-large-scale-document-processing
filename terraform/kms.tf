# TODO: create separate key for each service and use dedicated kms key policies.
resource "aws_kms_key" "textract_sqs" {
  description = "This key is used to encrypt data of textract pipeline services"
  #policy = data.aws_iam_policy_document.sqs_key_policy.json
  deletion_window_in_days = 30
  tags                    = local.default_tags
}

# TODO: need to add key admin to the policy
# and following policy for sqs/sns
/*
{
    "Version": "2012-10-17",
    "Id": "example-ID",
    "Statement": [
        {
            "Sid": "example-statement-ID",
            "Effect": "Allow",
            "Principal": {
                "Service": "s3.amazonaws.com"
            },
            "Action": [
                "kms:GenerateDataKey",
                "kms:Decrypt"
            ],
            "Resource": "*"
        }
    ]
}
*/
data "aws_iam_policy_document" "sqs_key_policy" {
  statement {
    sid    = "SQSAllowRootPolicy"
    effect = "Allow"
    actions = [
      "kms:Describe*",
      "kms:Get*",
      "kms:List*",
      "kms:RevokeGrant",
    ]
    resources = ["*"]
    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      type        = "AWS"
    }
  }
  statement {
    sid    = "SQSAllowDefault"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:ListGrants",
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


resource "aws_kms_alias" "textract_sqs_alias" {
  name_prefix   = "alias/textract-pipeline-sqs-"
  target_key_id = aws_kms_key.textract_sqs.key_id
}

resource "aws_kms_key" "textract_sns_key" {
  description             = "This key is used to encrypt data of textract pipeline services"
  deletion_window_in_days = 30
  tags                    = local.default_tags
}

resource "aws_kms_alias" "textract_sns_alias" {
  name_prefix   = "alias/textract-pipeline-sns-"
  target_key_id = aws_kms_key.textract_sns_key.key_id
}

resource "aws_kms_key" "textract_s3_key" {
  description             = "This key is used to encrypt data of textract pipeline services"
  deletion_window_in_days = 30
  tags                    = local.default_tags
}

resource "aws_kms_alias" "textract_s3_alias" {
  name_prefix   = "alias/textract-pipeline-s3-"
  target_key_id = aws_kms_key.textract_s3_key.key_id
}
