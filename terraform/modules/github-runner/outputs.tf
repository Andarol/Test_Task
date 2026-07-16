output "instance_name" {
  value       = google_compute_instance.runner.name
  description = "Persistent self-hosted runner VM name."
}

output "instance_zone" {
  value       = google_compute_instance.runner.zone
  description = "Runner VM zone."
}

output "private_ip" {
  value       = google_compute_instance.runner.network_interface[0].network_ip
  description = "Runner private IP in the management subnet."
}

output "service_account_email" {
  value       = google_service_account.runner.email
  description = "GCP identity attached to the runner VM."
}

output "registration_secret_id" {
  value       = google_secret_manager_secret.registration.secret_id
  description = "Empty secret container used for the one-time registration token handoff."
}
