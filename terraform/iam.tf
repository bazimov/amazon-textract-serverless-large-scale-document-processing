resource "aws_iam_role" "iam_for_lambda_textract_processor" {
  name = var.lambda_role_name

  assume_role_policy = data.aws_iam_policy_document.textract_processor_lambda.json
  tags               = local.default_tags
}

resource "aws_iam_role_policy" "textract_processor" {
  policy = data.aws_iam_policy_document.lambda_shared_policy.json
  role   = aws_iam_role.iam_for_lambda_textract_processor.id
}

resource "aws_iam_role_policy" "textract_processor_sqs_policy" {
  policy = data.aws_iam_policy_document.stream_policy_document.json
  role   = aws_iam_role.iam_for_lambda_textract_processor.id
}

resource "aws_iam_role" "iam_for_textract_results_publisher" {
  name = var.textract_results_role_name

  assume_role_policy = data.aws_iam_policy_document.textract_results_assume_policy.json
  tags               = local.default_tags
}

resource "aws_iam_role_policy" "textract_results_publisher_policy" {
  policy = data.aws_iam_policy_document.textract_results_sns_policy.json
  role   = aws_iam_role.iam_for_textract_results_publisher.id
}

resource "aws_iam_role" "kms_key_admin_role" {
  name_prefix        = "KmsKeyAdminRole-"
  assume_role_policy = data.aws_iam_policy_document.kms_key_admin_assume_policy.json
  tags               = local.default_tags
}

