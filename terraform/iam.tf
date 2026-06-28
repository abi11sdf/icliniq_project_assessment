# ─── IAM Service Account ────────────────────────────────
# One dedicated SA for Cloud Run — minimal roles only
# Never use Editor/Owner/Viewer primitive roles

resource "google_service_account" "cloud_run_sa" {
  account_id   = "cloudrun-app-sa"
  display_name = "Cloud Run App Service Account"
  description  = "Minimal SA for Cloud Run — only what the app needs"
}

# Role 1: Read secrets from Secret Manager
resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Role 2: Connect to Cloud SQL
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Role 3: Write logs to Cloud Logging
resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Role 4: Write metrics to Cloud Monitoring
resource "google_project_iam_member" "metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# ─── CI/CD Service Account ──────────────────────────────
# Separate SA used by GitHub Actions to deploy
# Only gets what's needed to push images and deploy Cloud Run

resource "google_service_account" "cicd_sa" {
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions CI/CD Service Account"
  description  = "Used by GitHub Actions to push to GAR and deploy to Cloud Run"
}

resource "google_project_iam_member" "cicd_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}

resource "google_project_iam_member" "cicd_gar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}

resource "google_project_iam_member" "cicd_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}

# ─── Workload Identity Federation ───────────────────────
# Allows GitHub Actions to authenticate as cicd_sa WITHOUT a JSON key
# This is the secure way — no long-lived credentials stored in GitHub

resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions OIDC"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC Provider"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Map GitHub token claims to Google attributes
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  # Only allow tokens from YOUR specific GitHub repo
  attribute_condition = "attribute.repository == 'abi11sdf/icliniq_project_assessment'"
}

# Allow GitHub Actions (via OIDC) to impersonate the cicd_sa
resource "google_service_account_iam_member" "github_oidc_binding" {
  service_account_id = google_service_account.cicd_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/abi11sdf/icliniq_project_assessment"
}
