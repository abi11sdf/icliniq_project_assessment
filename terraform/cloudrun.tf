# ─── Cloud Run ──────────────────────────────────────────
# Serverless container platform — auto-scales, pay per request
# Pulls image from GAR, secrets from Secret Manager, connects to SQL via VPC

resource "google_cloud_run_v2_service" "app" {
  name     = "assessment-app"
  location = var.region

  template {
    # Use the dedicated minimal service account — not the default compute SA
    service_account = google_service_account.cloud_run_sa.email

    # Connect to VPC so the app can reach Cloud SQL's private IP
    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"   # only private traffic goes through VPC
    }

    scaling {
      min_instance_count = 0    # scale to zero when no traffic (saves cost)
      max_instance_count = 3
    }

    containers {
      # Image pushed by CI/CD — tag comes from GitHub Actions
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}/app:${var.image_tag}"

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      # ── Secrets injected as env vars at runtime ─────
      # The app reads process.env.DB_* — Cloud Run fills them from Secret Manager
      # Secrets are NEVER baked into the image

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "DB_HOST"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_host.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "DB_NAME"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_name.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "DB_USER"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_user.secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "DB_SSL"
        value = "false"   # traffic stays inside VPC — SSL at transport layer not needed
      }

      # Health check — Cloud Run uses this to know the container is ready
      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 5
        period_seconds        = 5
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        period_seconds    = 30
        failure_threshold = 3
      }
    }
  }

  depends_on = [
    google_project_service.apis,
    google_vpc_access_connector.connector,
    google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_version.db_host,
    google_secret_manager_secret_version.db_name,
    google_secret_manager_secret_version.db_user,
  ]
}

# Allow public unauthenticated access to Cloud Run
# The app itself handles auth — the service is public-facing
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
