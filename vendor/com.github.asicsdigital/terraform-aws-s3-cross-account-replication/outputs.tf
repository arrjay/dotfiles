# Destination bucket policy to add manually

output "dest_bucket_policy_json" {
  value = "${var.create_dest_bucket == "true" ? "not needed" : data.aws_iam_policy_document.dest_bucket_policy.json}"
}
