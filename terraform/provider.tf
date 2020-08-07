terraform {
  required_version = ">=0.12"
  /*
  backend "s3" {
    bucket = "mybucket"
    key    = "path/to/my/key"
    region = "us-east-1"
  }
  */
}

provider "aws" {
  version = "~> 2.70"
}
