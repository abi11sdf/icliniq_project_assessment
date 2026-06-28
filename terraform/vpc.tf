# ─── VPC & Networking ───────────────────────────────────

# Enable required GCP APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "vpcaccess.googleapis.com",
    "servicenetworking.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iamcredentials.googleapis.com"
  ])
  service            = each.value
  disable_on_destroy = false
}

# Custom VPC — never use the default VPC in production
resource "google_compute_network" "vpc" {
  name                    = "assessment-vpc"
  auto_create_subnetworks = false # we control subnets manually
  depends_on              = [google_project_service.apis]
}

# Private subnet for Cloud Run and Cloud SQL
resource "google_compute_subnetwork" "private" {
  name          = "assessment-private-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  # Private Google Access — allows resources to reach Google APIs without public IP
  private_ip_google_access = true
}

# Reserved IP range for Cloud SQL private IP (VPC peering)
resource "google_compute_global_address" "private_ip_range" {
  name          = "assessment-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

# VPC peering connection — allows Cloud SQL to get a private IP in our VPC
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
  depends_on              = [google_project_service.apis]
}

# Serverless VPC Access Connector — allows Cloud Run to talk to the private VPC
# Cloud Run is serverless so it needs this bridge to reach Cloud SQL's private IP
resource "google_vpc_access_connector" "connector" {
  name          = "assessment-connector"
  region        = var.region
  ip_cidr_range = "10.8.0.0/28" # small range just for the connector
  network       = google_compute_network.vpc.id
  depends_on    = [google_project_service.apis]
}
