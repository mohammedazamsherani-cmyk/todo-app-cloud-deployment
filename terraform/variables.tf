variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Region for Cloud Run, Cloud SQL and Artifact Registry"
  type        = string
  default     = "europe-west1"
}

variable "app_name" {
  description = "Base name used for the Cloud Run service, AR repo, SQL instance, etc."
  type        = string
  default     = "todoapp"
}

variable "image" {
  description = "Image for the first deploy only. Afterwards Cloud Build rolls out new images and Terraform ignores image changes. Defaults to Google's hello image so apply works before the first build."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "db_tier" {
  description = "Cloud SQL machine tier (smallest shared-core by default)"
  type        = string
  default     = "db-f1-micro"
}

variable "db_name" {
  description = "Application database name"
  type        = string
  default     = "todoapp"
}

variable "db_user" {
  description = "Application database user"
  type        = string
  default     = "todoapp"
}

variable "invoker_members" {
  description = "Principals granted roles/run.invoker, e.g. [\"user:interviewer@example.com\"]"
  type        = list(string)
  default     = []
}

# ---------- CI/CD trigger (optional) ----------
variable "github_owner" {
  description = "GitHub user/org that owns the repo. Leave empty to skip creating the Cloud Build trigger."
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = ""
}
