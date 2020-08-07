# TODO: table names hardcoded
resource "aws_dynamodb_table" "textract_documents_table" {
  name         = "textract-documents-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "documentId"

  attribute {
    name = "documentId"
    type = "S"
  }

  tags = local.default_tags
}

resource "aws_dynamodb_table" "textract_outputs_table" {
  name         = "textract-outputs-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "documentId"

  attribute {
    name = "documentId"
    type = "S"
  }

  tags = local.default_tags
}
