# MAIN

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [ aws.source, aws.dest ]
    }
  }
}

data "aws_caller_identity" "source" {
  provider = aws.source
}

data "aws_caller_identity" "dest" {
  provider = aws.dest
}
