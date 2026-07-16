output "bucket_names" {
  value = {
    for environment, bucket in google_storage_bucket.terraform_state : environment => bucket.name
  }
}
