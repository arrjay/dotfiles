variable "source_region" {
  type        = string
  description = "AWS region for the source bucket"
}

variable "dest_region" {
  type        = string
  description = "AWS region for the destination bucket"
}

variable "source_bucket_name" {
  type        = string
  description = "Name for source s3 bucket"
}

variable "replicate_prefix" {
  type        = string
  description = "Prefix to replicate, default \"\" for all objects. Note if specifying, must end in a /"
  default     = ""
}

variable "dest_bucket_name" {
  type        = string
  description = "Name for dest s3 bucket"
}

variable "create_dest_bucket" {
  type        = string
  description = "Boolean for whether this module should create the destination bucket"
  default     = "true"
}

variable "replication_name" {
  type        = string
  description = "Short name to describe this replication"
}

variable "dest_storage_class" {
  type        = string
  description = "S3 Storage Class for Replicated Objects"
  default     = "STANDARD"
}

variable "EXPIRE_ALL_186DAYS" {
  type        = string
  description = "toggle for *all* object expiration - 186d"
  default     = "false"
}

variable "EXPIRE_SOURCE_186DAYS" {
  type        = string
  description = "toggle for source bucket object expiration - 186d"
  default     = "false"
}

variable "EXPIRE_DEST_186DAYS" {
  type        = string
  description = "toggle for destination bucket object expiration - 186d"
  default     = "false"
}

variable "expire_old_versions_93d" {
  type        = string
  description = "toggle for old version expiration - 93d"
  default     = "false"
}

variable "expire_old_source_93d" {
  type        = string
  description = "toggle for old source version expiration - 93d"
  default     = "false"
}

variable "expire_old_dest_93d" {
  type        = string
  description = "toggle for old destination version expiration - 93d"
  default     = "false"
}

variable "expire_old_source_31d" {
  type        = string
  description = "toggle for old source version expiration - 31d"
  default     = "false"
}

variable "expire_old_versions_7d" {
  type        = string
  description = "toggle for old version expiration - 7d"
  default     = "false"
}

variable "expire_old_dest_7d" {
  type        = string
  description = "toggle for old destination version expiration - 7d"
  default     = "false"
}

variable "expire_old_source_7d" {
  type        = string
  description = "toggle for old source version expiration - 7d"
  default     = "false"
}
