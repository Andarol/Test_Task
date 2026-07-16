terraform {
  required_version = ">= 1.10.0"
  required_providers {
    google = {
      source  = "hashicorp/google-beta"
      version = ">= 7.12.0, < 8.0.0"
    }
  }
}
