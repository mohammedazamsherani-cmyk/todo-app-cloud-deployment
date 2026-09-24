# ---------- Runtime identity for Cloud Run ----------
resource "google_service_account" "run" {
  account_id   = "${var.app_name}-run"
  display_name = "Cloud Run runtime SA for ${var.app_name}"
}

resource "google_project_iam_member" "run_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.run.email}"
}

resource "google_secret_manager_secret_iam_member" "run_db_password" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run.email}"
}

# ---------- Identity Cloud Build runs as ----------
resource "google_service_account" "cloudbuild" {
  account_id   = "${var.app_name}-cloudbuild"
  display_name = "Cloud Build deployer SA for ${var.app_name}"
}

resource "google_project_iam_member" "cloudbuild_roles" {
  for_each = toset([
    "roles/run.developer",     # deploy new revisions
    "roles/logging.logWriter", # write build logs
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_artifact_registry_repository_iam_member" "cloudbuild_writer" {
  location   = google_artifact_registry_repository.app.location
  repository = google_artifact_registry_repository.app.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Cloud Build must be able to "act as" the runtime SA when deploying the service
resource "google_service_account_iam_member" "cloudbuild_act_as_run" {
  service_account_id = google_service_account.run.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloudbuild.email}"
}
