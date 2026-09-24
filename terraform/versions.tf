terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Optional: keep state in GCS instead of locally.
  # Create the bucket by hand first (gcloud storage buckets create gs://<PROJECT_ID>-tfstate), then uncomment.
  # backend "gcs" {
  #   bucket = "<PROJECT_ID>-tfstate"
  #   prefix = "todoapp"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
