output "cloud_run_url" {
  value = google_cloud_run_v2_service.app.uri
}

output "artifact_registry_repo" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}

output "cloudsql_connection_name" {
  value = google_sql_database_instance.main.connection_name
}

output "cloudbuild_service_account" {
  value = google_service_account.cloudbuild.email
}

output "run_service_account" {
  value = google_service_account.run.email
}
