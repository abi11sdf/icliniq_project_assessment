variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"
}

variable "db_name" {
  description = "Cloud SQL database name"
  type        = string
  default     = "appdb"
}

variable "db_user" {
  description = "Cloud SQL database user"
  type        = string
  default     = "appuser"
}

variable "db_password" {
  description = "Cloud SQL database password — stored in Secret Manager, never in code"
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email address for monitoring alerts"
  type        = string
}

variable "google_chat_webhook" {
  description = "Google Chat webhook URL for warning alerts"
  type        = string
  sensitive   = true
}

variable "image_tag" {
  description = "Docker image tag to deploy to Cloud Run"
  type        = string
  default     = "latest"
}
