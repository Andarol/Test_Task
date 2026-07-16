variable "project_id" {
  type        = string
  description = "Google Cloud project hosting the VPN gateway."
}

variable "name" {
  type        = string
  description = "WireGuard gateway name."
}

variable "region" {
  type        = string
  description = "Region containing the VPN gateway."
}

variable "zone" {
  type        = string
  description = "Zone containing the VPN gateway VM."
}

variable "network_name" {
  type        = string
  description = "Management VPC name."
}

variable "subnetwork_id" {
  type        = string
  description = "Management subnet used by the gateway."
}

variable "client_public_key" {
  type        = string
  description = "WireGuard public key of the single administrator client."
  sensitive   = true
}

variable "vpn_client_cidr" {
  type        = string
  description = "Route advertised back to WireGuard clients."
  default     = "10.250.0.0/24"
}

variable "server_address" {
  type        = string
  description = "WireGuard interface address on the gateway."
  default     = "10.250.0.1/24"
}

variable "client_address" {
  type        = string
  description = "Allowed address for the administrator peer."
  default     = "10.250.0.2/32"
}

variable "allowed_source_ranges" {
  type        = list(string)
  description = "Public source CIDRs allowed to establish WireGuard sessions."
  default     = ["0.0.0.0/0"]
}

variable "labels" {
  type        = map(string)
  description = "GCP resource labels."
  default     = {}
}
