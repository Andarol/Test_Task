variable "project_id" {
  type        = string
  description = "Google Cloud project hosting the self-hosted runner."
}

variable "name" {
  type        = string
  description = "Runner VM and service-account name prefix."
}

variable "zone" {
  type        = string
  description = "Zone containing the persistent bootstrap runner."
}

variable "subnetwork_id" {
  type        = string
  description = "Management subnetwork used by the private runner VM."
}

variable "github_repository_url" {
  type        = string
  description = "Repository URL passed to actions/runner config.sh."
}

variable "runner_labels" {
  type        = list(string)
  description = "Additional GitHub runner labels."
  default     = ["gcp", "ci", "europe-west3"]
}

variable "runner_version" {
  type        = string
  description = "Pinned GitHub Actions runner version."
  default     = "2.335.1"
}

variable "runner_archive_sha256" {
  type        = string
  description = "SHA-256 of the pinned linux-x64 runner archive."
  default     = "4ef2f25285f0ae4477f1fe1e346db76d2f3ebf03824e2ddd1973a2819bf6c8cf"
}

variable "machine_type" {
  type        = string
  description = "Runner VM machine type."
  default     = "e2-standard-4"
}

variable "disk_size_gb" {
  type        = number
  description = "Runner boot disk capacity for BuildKit caches."
  default     = 100
}

variable "network_tags" {
  type        = list(string)
  description = "Network tags assigned to the runner VM."
  default     = ["github-runner"]
}

variable "labels" {
  type        = map(string)
  description = "GCP resource labels."
  default     = {}
}
