# ─── Cloud SQL (PostgreSQL) ──────────────────────────────

resource "google_sql_database_instance" "main" {
  name             = "assessment-db"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = "db-f1-micro" # smallest tier — good for assessment

    # ── Security: NO public IP ──────────────────────────
    ip_configuration {
      ipv4_enabled    = false # no public IP — traffic never leaves VPC
      private_network = google_compute_network.vpc.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled    = true
      start_time = "02:00" # backup at 2am UTC daily
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
  }

  # Prevent accidental deletion via terraform destroy
  deletion_protection = false # set true in real production

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# Create the database inside the instance
resource "google_sql_database" "app_db" {
  name     = var.db_name
  instance = google_sql_database_instance.main.name
}

# Create the database user
resource "google_sql_user" "app_user" {
  name     = var.db_user
  instance = google_sql_database_instance.main.name
  password = var.db_password # comes from terraform.tfvars → Secret Manager
}
