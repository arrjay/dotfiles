# S3 destination bucket

locals {
  dest_enable_noncurrent_exp_7d  = "${contains(list(var.expire_old_dest_7d,var.expire_old_versions_7d), "true")}"
  dest_enable_noncurrent_exp_93d = "${contains(list(var.expire_old_dest_93d,var.expire_old_versions_93d), "true")}"
  dest_enable_EXPIRE_ALL_186DAYS = "${contains(list(var.EXPIRE_DEST_186DAYS,var.EXPIRE_ALL_186DAYS), "true")}"
}

data "aws_iam_policy_document" "dest_bucket_policy" {
  statement {
    sid = "replicate-objects-from-${data.aws_caller_identity.source.account_id}-to-prefix-${var.replicate_prefix}"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ObjectOwnerOverrideToBucketOwner",
    ]

    resources = [
      "${local.dest_bucket_object_arn}",
    ]

    principals {
      type = "AWS"

      identifiers = [
        "${local.source_root_user_arn}",
      ]
    }
  }
}

resource "aws_s3_bucket" "dest" {
  count    = var.create_dest_bucket == "true" ? 1 : 0
  provider = aws.dest
  bucket   = var.dest_bucket_name
  region   = var.dest_region
  policy   = data.aws_iam_policy_document.dest_bucket_policy.json

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "DELETE_186"
    enabled = local.dest_enable_EXPIRE_ALL_186DAYS

    expiration {
      days = 186
    }
  }

  lifecycle_rule {
    id      = "expire_93"
    enabled = local.dest_enable_noncurrent_exp_93d

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

  lifecycle {
    ignore_changes = [
      server_side_encryption_configuration
    ]
  }
}
