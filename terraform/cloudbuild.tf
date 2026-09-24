# Push-to-main trigger. Requires the GitHub repo to be connected to Cloud Build once by hand
# (Console -> Cloud Build -> Triggers -> Connect repository -> GitHub (Cloud Build GitHub App)).
resource "google_cloudbuild_trigger" "main" {
  count = var.github_owner != "" && var.github_repo != "" ? 1 : 0

  name        = "${var.app_name}-push-main"
  description = "Build, push and deploy ${var.app_name} on push to main"
  location    = "global"
  filename    = "cloudbuild.yaml"

  service_account = google_service_account.cloudbuild.id

  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = "^main$"
    }
  }

  substitutions = {
    _REGION  = var.region
    _AR_REPO = google_artifact_registry_repository.app.repository_id
    _IMAGE   = var.app_name
    _SERVICE = google_cloud_run_v2_service.app.name
  }

  depends_on = [
    google_project_iam_member.cloudbuild_roles,
    google_artifact_registry_repository_iam_member.cloudbuild_writer,
    google_service_account_iam_member.cloudbuild_act_as_run,
  ]
}
