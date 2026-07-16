variable "project_id" {
  type = string
}

variable "state_bucket_names" {
  description = "Environment-specific GCS buckets used for Terraform remote state."
  type        = map(string)
}

variable "bucket_location" {
  type    = string
  default = "EU"
}
