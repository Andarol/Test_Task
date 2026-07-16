variable "project_id" {
  type        = string
  description = "Google Cloud project shared by bootstrap and runtime environments."
}

variable "region" {
  type        = string
  description = "Management region."
  default     = "europe-west3"
}

variable "zone" {
  type        = string
  description = "Zone containing the runner and VPN VMs."
  default     = "europe-west3-a"
}

variable "management_cidr" {
  type        = string
  description = "Subnet for the bootstrap runner and VPN gateway."
  default     = "10.0.0.0/24"
}

variable "private_service_ranges" {
  type = map(object({
    cidr = string
  }))
  description = "Per-environment Private Service Access ranges on the shared VPC."
}

variable "github_repository_url" {
  type        = string
  description = "Repository registered on the self-hosted runner."
}

variable "wireguard_client_public_key" {
  type        = string
  description = "Administrator WireGuard client public key."
  sensitive   = true
}

variable "wireguard_allowed_source_ranges" {
  type        = list(string)
  description = "Internet source ranges allowed to reach UDP/51820."
  default     = ["0.0.0.0/0"]
}

variable "runner_machine_type" {
  type        = string
  description = "Self-hosted runner VM machine type."
  default     = "e2-standard-4"
}
