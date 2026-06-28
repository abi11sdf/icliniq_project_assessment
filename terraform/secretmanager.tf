# ─── Secret Manager ─────────────────────────────────────
# Store all sensitive values here — Cloud Run reads them at runtime
# Secrets are NEVER in code, logs, or CI/CD configs

# DB Password secret
resource "google_secret_manager_secret" "db_password" {
  secret_id = "db-password"
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password # comes from terraform.tfvars (never committed)
}

# DB Host secret (Cloud SQL private IP)
resource "google_secret_manager_secret" "db_host" {
  secret_id = "db-host"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_host" {
  secret      = google_secret_manager_secret.db_host.id
  secret_data = google_sql_database_instance.main.private_ip_address
}

# DB Name secret
resource "google_secret_manager_secret" "db_name" {
  secret_id = "db-name"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_name" {
  secret      = google_secret_manager_secret.db_name.id
  secret_data = var.db_name
}

# DB User secret
resource "google_secret_manager_secret" "db_user" {
  secret_id = "db-user"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_user" {
  secret      = google_secret_manager_secret.db_user.id
  secret_data = var.db_user
}
