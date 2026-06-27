# DevSecOps Assessment — Secure Node.js Deployment on GCP

> **Assignment:** Secure Deployment of a Containerized Node.js Application on Google Cloud using DevSecOps Principles

---

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [Setup & Deployment Steps](#setup--deployment-steps)
- [Security Measures](#security-measures)
- [Alerting Setup](#alerting-setup)
- [Assumptions](#assumptions)

---

## Architecture Overview

```
GitHub Push
    │
    ▼
GitHub Actions CI
├── ESLint (lint)
├── Jest (unit tests + coverage)
├── Trivy (Docker image vulnerability scan)
├── Docker Build → push to Artifact Registry
└── Terraform fmt + validate + tflint
    │
    ▼ (only on main branch, CI success)
GitHub Actions CD
└── gcloud run deploy → Cloud Run
                            │
                            │ VPC Connector (private)
                            ▼
                        Cloud SQL (PostgreSQL)
                        Private IP — never public
                            │
                        Secret Manager
                        DB credentials injected at runtime
                            │
                        Cloud Monitoring
                        CPU/Memory alerts → Google Chat + Email
```

---

## Repository Structure

```
devsecops-assessment/
├── app/
│   ├── server.js               # Express REST API
│   ├── package.json
│   ├── .env.example            # template — never commit .env
│   ├── .eslintrc.json
│   └── __tests__/
│       └── server.test.js      # Jest unit tests
├── Dockerfile                  # Multi-stage, non-root user
├── .dockerignore
├── terraform/
│   ├── main.tf                 # Provider + GCS backend
│   ├── variables.tf
│   ├── outputs.tf
│   ├── vpc.tf                  # VPC + subnet + VPC connector
│   ├── cloudsql.tf             # PostgreSQL, private IP only
│   ├── iam.tf                  # Service accounts + OIDC
│   ├── secretmanager.tf        # All credentials stored here
│   ├── artifact_registry.tf    # Docker registry
│   ├── cloudrun.tf             # Cloud Run service
│   ├── monitoring.tf           # Alerts + log metrics
│   └── terraform.tfvars.example
├── .github/
│   └── workflows/
│       ├── ci.yml              # Lint → Test → Scan → Build → Push
│       └── cd.yml              # Deploy on CI success (main only)
└── README.md
```

---

## Setup & Deployment Steps

### Prerequisites
- GCP project with billing enabled
- `gcloud` CLI installed and authenticated
- Terraform >= 1.5 installed
- Docker installed
- GitHub repository created

### 1. GCP Initial Setup

```bash
# Set your project
gcloud config set project YOUR_PROJECT_ID

# Create GCS bucket for Terraform remote state
gsutil mb -p YOUR_PROJECT_ID gs://YOUR_PROJECT_ID-tfstate
gsutil versioning set on gs://YOUR_PROJECT_ID-tfstate
```

### 2. Configure Terraform

```bash
cd terraform

# Copy and fill in your values
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project_id, db_password, alert_email, etc.

# Update backend bucket in main.tf
# Replace: bucket = "YOUR_PROJECT_ID-tfstate"

# Update GitHub repo in iam.tf
# Replace: YOUR_GITHUB_USERNAME/devsecops-assessment
```

### 3. Deploy Infrastructure

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

This provisions in order:
- VPC + private subnet + VPC connector
- Cloud SQL PostgreSQL (private IP, no public access)
- Secret Manager secrets (DB credentials)
- IAM service accounts (minimal roles)
- Artifact Registry (Docker registry)
- Cloud Run service (secrets injected at runtime)
- Monitoring alerts (CPU + memory + error rate)

### 4. Configure GitHub Secrets

After `terraform apply`, run:

```bash
# Get Workload Identity Provider
terraform output -raw workload_identity_provider

# Get service account email
terraform output -raw cicd_service_account
```

Add these 3 secrets in GitHub → Settings → Secrets → Actions:

| Secret | Value |
|--------|-------|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `WIF_PROVIDER` | Output from terraform above |
| `WIF_SERVICE_ACCOUNT` | `github-actions-sa@PROJECT_ID.iam.gserviceaccount.com` |

### 5. Push to GitHub

```bash
git add .
git commit -m "Initial DevSecOps assessment deployment"
git push origin main
```

CI/CD triggers automatically. CI runs on every push. CD deploys on CI success to `main` only.

### 6. Verify Deployment

```bash
# Get Cloud Run URL
terraform output cloud_run_url

# Test endpoints
curl https://YOUR_CLOUD_RUN_URL/health
curl https://YOUR_CLOUD_RUN_URL/items
curl -X POST https://YOUR_CLOUD_RUN_URL/items \
  -H "Content-Type: application/json" \
  -d '{"name": "test item", "description": "hello"}'
```

---

## Security Measures

### IAM & Least Privilege
- **No primitive roles used** (no Owner, Editor, Viewer)
- Two dedicated service accounts:
  - `cloudrun-app-sa` — only `secretmanager.secretAccessor`, `cloudsql.client`, `logging.logWriter`, `monitoring.metricWriter`
  - `github-actions-sa` — only `run.admin`, `artifactregistry.writer`, `iam.serviceAccountUser`
- All roles scoped to project level minimum required

### Workload Identity Federation (OIDC)
- GitHub Actions authenticates to GCP via OIDC — **no JSON key stored anywhere**
- Short-lived tokens exchanged per workflow run
- Attribute condition restricts access to this specific GitHub repo only

### Network Security
- Cloud SQL has **no public IP** (`ipv4_enabled = false`)
- All traffic between Cloud Run and Cloud SQL stays inside the VPC — never touches the public internet
- VPC Access Connector bridges Cloud Run (serverless) to the private VPC
- VPC egress set to `PRIVATE_RANGES_ONLY`

### Secret Management
- All credentials stored in **Google Secret Manager**
- Secrets injected as environment variables at Cloud Run runtime
- Secrets never appear in code, logs, CI/CD configs, or Docker images
- `terraform.tfvars` is in `.gitignore` — never committed

### Container Security
- **Multi-stage Dockerfile** — production image contains no dev tools or test files
- **Non-root user** — app runs as `appuser`, not root
- **Trivy scan** in CI — CRITICAL/HIGH vulnerabilities fail the pipeline
- `.dockerignore` excludes `.env`, `node_modules`, terraform files from build context
- `npm ci --omit=dev` in production stage — no devDependencies in image

### CI/CD Security
- Lint + tests must pass before Docker build
- Security scan must pass before image push
- CD only triggers on CI success on `main` branch
- Post-deployment health check — rolls back automatically if `/health` fails

---

## Alerting Setup

All alerts provisioned via Terraform (`terraform/monitoring.tf`) — no manual console configuration.

### Notification Channels
| Channel | Type | Used for |
|---------|------|----------|
| Google Chat webhook | Webhook | Warning alerts (70%) |
| Email | Email | Critical alerts (80%) |

### Alert Policies

| Policy | Metric | Threshold | Duration | Channel |
|--------|--------|-----------|----------|---------|
| CPU Warning | `run.googleapis.com/container/cpu/utilizations` | >70% | 60s | Google Chat |
| CPU Critical | `run.googleapis.com/container/cpu/utilizations` | >80% | 5 min | Email |
| Memory Warning | `run.googleapis.com/container/memory/utilizations` | >70% | 60s | Google Chat |
| Memory Critical | `run.googleapis.com/container/memory/utilizations` | >80% | 5 min | Email |
| Error Rate | App logs severity>=ERROR | >10 in 5 min | 0s | Both |

**Duration field explained:** The condition must remain true for the full duration before an alert fires. This prevents alert spam from brief spikes — a 2-second CPU burst at 75% will not trigger the warning alert.

---

## Assumptions

1. **GCP project exists** with billing enabled and owner access available for initial setup.

2. **Terraform state** is stored in GCS (not local) to support team collaboration and prevent state conflicts.

3. **Cloud SQL tier `db-f1-micro`** is used for assessment purposes. Production would use a higher tier with read replicas.

4. **`deletion_protection = false`** on Cloud SQL for easy cleanup after assessment. Set to `true` in production.

5. **`min_instance_count = 0`** on Cloud Run scales to zero to minimize cost during assessment. Production would set minimum 1.

6. **Single region deployment** (`us-central1`). Production would use multi-region with load balancing.

7. **OIDC Workload Identity Federation** is used instead of JSON keys. If OIDC cannot be configured in the target environment, the fallback is a JSON key stored as a GitHub Secret — but this is not recommended.

8. **Public Cloud Run endpoint** — the service allows unauthenticated access since it's a demo REST API. Production would add authentication (e.g. Firebase Auth, IAP, or API Gateway).

9. **No custom domain** configured — Cloud Run's auto-generated URL is used for assessment.

10. **SSL between app and Cloud SQL** is not enforced at the application layer since both services communicate over the private VPC. SSL at the transport layer is handled by GCP internally.
