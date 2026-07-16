output "instance_name" {
  value = google_compute_instance.this.name
}

output "internal_ip" {
  value = google_compute_instance.this.network_interface[0].network_ip
}

output "service_account" {
  value = local.service_account
}

output "iap_ssh_command" {
  value = "gcloud compute ssh ${google_compute_instance.this.name} --zone=${var.zone} --tunnel-through-iap"
}
