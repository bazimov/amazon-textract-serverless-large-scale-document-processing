# TODO: Have separate iam role for each lambda
data "template_file" "datastore_py" {
  template = file("${path.module}/src/datastore.py")
}

data "template_file" "helper_py" {
  template = file("${path.module}/src/helper.py")
}

data "template_file" "og_py" {
  template = file("${path.module}/src/og.py")
}

data "template_file" "trp_py" {
  template = file("${path.module}/src/trp.py")
}

data "archive_file" "textract_processor_lambda_src" {
  source_file = "${path.module}/src/asyncprocess.py"
  output_path = "/tmp/textract_processor_payload.zip"
  type        = "zip"
}

data "archive_file" "textract_results_lambda_src" {
  source_file = "${path.module}/src/jobresultsprocess.py"
  output_path = "/tmp/textract_results_payload.zip"
  type        = "zip"
}

data "archive_file" "helper_layer" {
  type        = "zip"
  output_path = "/tmp/textract_lambda_base_layer.zip"
  source {
    content  = data.template_file.datastore_py.rendered
    filename = "python/datastore.py"
  }
  source {
    content  = data.template_file.helper_py.rendered
    filename = "python/helper.py"
  }
  source {
    content  = data.template_file.og_py.rendered
    filename = "python/og.py"
  }
  source {
    content  = data.template_file.trp_py.rendered
    filename = "python/trp.py"
  }
}

resource "aws_lambda_layer_version" "lambda_layer" {
  filename         = data.archive_file.helper_layer.output_path
  source_code_hash = data.archive_file.helper_layer.output_base64sha256
  layer_name       = "textractor_lambda_helper_layer"

  compatible_runtimes = ["python3.8"]
}

resource "aws_lambda_function" "textract_processor_lambda" {
  function_name    = var.processor_lambda_name
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
  role             = aws_iam_role.iam_for_lambda_textract_processor.arn
  handler          = "asyncprocess.lambda_handler"
  filename         = data.archive_file.textract_processor_lambda_src.output_path
  source_code_hash = data.archive_file.textract_processor_lambda_src.output_base64sha256
  timeout          = 120
  memory_size      = 512
  runtime          = "python3.8"

  environment {
    variables = {
      SNS_ROLE_ARN    = aws_iam_role.iam_for_textract_results_publisher.arn
      SNS_TOPIC_ARN   = aws_sns_topic.textract_results.arn
      ASYNC_QUEUE_URL = aws_sqs_queue.textract_processor_queue.id
    }
  }
  # depends_on = [aws_cloudwatch_log_group.processor_lambda_log_group]
  tags = local.default_tags
}

resource "aws_lambda_function" "textract_results_lambda" {
  function_name    = var.results_lambda_name
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
  role             = aws_iam_role.iam_for_lambda_textract_processor.arn
  handler          = "jobresultsprocess.lambda_handler"
  filename         = data.archive_file.textract_results_lambda_src.output_path
  source_code_hash = data.archive_file.textract_results_lambda_src.output_base64sha256
  timeout          = 900
  memory_size      = 3008 # TODO max memory specified may need to change.
  runtime          = "python3.8"

  environment {
    variables = {
      S3_KMS_KEY = aws_kms_key.textract_s3_key.arn
    }
  }
  # depends_on = [aws_cloudwatch_log_group.processor_lambda_log_group]
  tags = local.default_tags
}

resource "aws_lambda_event_source_mapping" "textract_results_lambda_event" {
  event_source_arn = aws_sqs_queue.textract_results_queue.arn
  function_name    = aws_lambda_function.textract_results_lambda.arn
}

data "archive_file" "comprehend_processor_lambda_src" {
  source_file = "${path.module}/src/comprehendprocess.py"
  output_path = "/tmp/comprehend_process_payload.zip"
  type        = "zip"
}

resource "aws_lambda_function" "comprehend_processor" {
  function_name    = var.comprehend_lambda_name
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
  role             = aws_iam_role.iam_for_lambda_textract_processor.arn
  handler          = "comprehendprocess.lambda_handler"
  filename         = data.archive_file.comprehend_processor_lambda_src.output_path
  source_code_hash = data.archive_file.comprehend_processor_lambda_src.output_base64sha256
  timeout          = 900
  memory_size      = 3008 # TODO max memory specified may need to change.
  runtime          = "python3.8"

  environment {
    variables = {
      S3_KMS_KEY = aws_kms_key.textract_s3_key.arn
    }
  }
  # depends_on = [aws_cloudwatch_log_group.processor_lambda_log_group]
  tags = local.default_tags
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id   = "AllowExecutionFromS3Bucket"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.comprehend_processor.arn
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.textract_source_bucket.arn
  source_account = data.aws_caller_identity.current.account_id
}

/* this sqs source also works but might overflow the lambda, using cron every minute
resource "aws_lambda_event_source_mapping" "textract_processor_lambda_event" {
  event_source_arn = aws_sqs_queue.textract_processor_queue.arn
  function_name    = aws_lambda_function.textract_processor_lambda.arn
}
*/

resource "aws_cloudwatch_event_rule" "every_two_minute" {
  name                = "every-two-minutes"
  description         = "Fires every two minutes"
  schedule_expression = "rate(2 minutes)"
}

resource "aws_cloudwatch_event_target" "check_foo_every_one_minute" {
  rule      = aws_cloudwatch_event_rule.every_two_minute.name
  target_id = "lambda"
  arn       = aws_lambda_function.textract_processor_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_check_foo" {
  statement_id   = "AllowExecutionFromCloudWatch"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.textract_processor_lambda.arn
  principal      = "events.amazonaws.com"
  source_arn     = aws_cloudwatch_event_rule.every_two_minute.arn
  source_account = data.aws_caller_identity.current.account_id
}

/*
resource "aws_cloudwatch_log_group" "processor_lambda_log_group" {
  name       = "/aws/lambda/${var.processor_lambda_name}"
  kms_key_id = aws_kms_key.textract_cw_key.arn
  # retention_in_days = 14
  tags = local.default_tags
}

resource "aws_cloudwatch_log_group" "results_lambda_log_group" {
  name       = "/aws/lambda/${var.results_lambda_name}"
  kms_key_id = aws_kms_key.textract_cw_key.arn
  # retention_in_days = 14
  tags = local.default_tags
}
*/