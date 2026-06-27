output "cloud_run_url" {
  description = "Public URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.app.uri
}

output "artifact_registry_url" {
  description = "Docker image push URL for CI/CD"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}/app"
}

output "cloud_sql_private_ip" {
  description = "Private IP of Cloud SQL — only reachable inside VPC"
  value       = google_sql_database_instance.main.private_ip_address
  sensitive   = true
}
