# S3 source IAM and bucket

# S3 source IAM

data "aws_iam_policy_document" "source_replication_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "source_replication_policy" {
  statement {
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [
      "${local.source_bucket_arn}",
    ]
  }

  statement {
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
    ]

    resources = [
      "${local.source_bucket_object_arn}",
    ]
  }

  statement {
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ObjectOwnerOverrideToBucketOwner",
    ]

    resources = [
      "${local.dest_bucket_object_arn}",
    ]
  }
}

resource "aws_iam_role" "source_replication" {
  provider           = aws.source
  name               = "${local.replication_name}-replication-role"
  assume_role_policy = data.aws_iam_policy_document.source_replication_role.json
  path               = "/service-role/s3repl/"
}

resource "aws_iam_policy" "source_replication" {
  provider = aws.source
  name     = "${local.replication_name}-replication-policy"
  policy   = data.aws_iam_policy_document.source_replication_policy.json
  path     = "/service-role/s3repl/"
}

resource "aws_iam_role_policy_attachment" "source_replication" {
  provider   = aws.source
  role       = aws_iam_role.source_replication.name
  policy_arn = aws_iam_policy.source_replication.arn
}

# S3 source bucket

locals {
  source_enable_noncurrent_exp_7d  = "${contains(list(var.expire_old_dest_93d,var.expire_old_versions_7d), "true")}"
  source_enable_noncurrent_exp_93d = "${contains(list(var.expire_old_source_93d,var.expire_old_versions_93d), "true")}"
  source_enable_EXPIRE_ALL_186DAYS = "${contains(list(var.EXPIRE_SOURCE_186DAYS,var.EXPIRE_ALL_186DAYS), "true")}"
}

resource "aws_s3_bucket" "source" {
  provider = aws.source
  bucket   = var.source_bucket_name
  region   = var.source_region

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "DELETE_186"
    enabled = local.source_enable_EXPIRE_ALL_186DAYS

    expiration {
      days = 186
    }
  }

  lifecycle_rule {
    id      = "expire_93"
    enabled = local.source_enable_noncurrent_exp_93d

    noncurrent_version_expiration {
      days = 93
    }
  }

  lifecycle_rule {
    id      = "expire_7"
    enabled = local.dest_enable_noncurrent_exp_7d

    noncurrent_version_expiration {
      days = 7
    }
  }

  replication_configuration {
    role = aws_iam_role.source_replication.arn

    rules {
      id     = local.replication_name
      status = "Enabled"
      prefix = var.replicate_prefix

      destination {
        bucket        = local.dest_bucket_arn
        storage_class = var.dest_storage_class

        access_control_translation {
          owner = "Destination"
        }

        account_id = data.aws_caller_identity.dest.account_id
      }
    }
  }

  lifecycle {
    ignore_changes = [
      server_side_encryption_configuration
    ]
  }
}
