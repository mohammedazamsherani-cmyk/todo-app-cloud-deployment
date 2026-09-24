resource "google_sql_database_instance" "main" {
  name                = "${var.app_name}-pg"
  database_version    = "POSTGRES_16"
  region              = var.region
  deletion_protection = false # demo project: allow `terraform destroy`

  settings {
    edition           = "ENTERPRISE" # shared-core tiers are not available on Enterprise Plus
    tier              = var.db_tier
    availability_type = "ZONAL"
    disk_size         = 10
    disk_autoresize   = false

    # Public IP but NO authorized networks: the only way in is the Cloud SQL Auth Proxy /
    # connector (IAM-authorized), which Cloud Run uses via the /cloudsql unix socket.
    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled = false
    }
  }
}

resource "google_sql_database" "app" {
  name     = var.db_name
  instance = google_sql_database_instance.main.name
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "google_sql_user" "app" {
  name     = var.db_user
  instance = google_sql_database_instance.main.name
  password = random_password.db.result
}

# ---------- DB password in Secret Manager ----------
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.app_name}-db-password"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}
