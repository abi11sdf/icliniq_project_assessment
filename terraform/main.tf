# ─── Provider Configuration ─────────────────────────────
terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Remote state — store tfstate in GCS bucket (not local, not in git)
  # Create this bucket manually once before running terraform init
  # gsutil mb -p YOUR_PROJECT_ID gs://YOUR_PROJECT_ID-tfstate
  backend "gcs" {
    bucket = "devsecops-project-500708-tfstate" # ← replace before init
    prefix = "devsecops-assessment"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
