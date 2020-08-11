resource "aws_sns_topic" "textract_results" {
  name_prefix       = var.textract_results_sns_name_prefix
  kms_master_key_id = aws_kms_key.textract_sns_key.key_id
  policy            = ""
  tags              = local.default_tags
}

resource "aws_sns_topic_subscription" "textract_results_sqs_target" {
  topic_arn = aws_sns_topic.textract_results.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.textract_results_queue.arn
}

data "aws_iam_policy_document" "sns_access_policy" {
  statement {
    sid    = "SNSDefaultAccessPolicy"
    effect = "Allow"
    actions = [
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish",
      "SNS:Receive",
    ]
    principals {
      identifiers = [aws_iam_role.iam_for_textract_results_publisher.arn]
      type        = "AWS"
    }
    resources = [
      aws_sns_topic.textract_results.arn,
    ]
  }
}