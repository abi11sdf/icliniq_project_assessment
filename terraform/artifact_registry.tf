# ─── Artifact Registry ──────────────────────────────────
# Private Docker registry — stores your container images
# CI/CD pushes here, Cloud Run pulls from here

resource "google_artifact_registry_repository" "app" {
  location      = var.region
  repository_id = "assessment-app"
  description   = "Docker images for devsecops assessment app"
  format        = "DOCKER"

  depends_on = [google_project_service.apis]
}
