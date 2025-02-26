# Create Service Account which is used to deploy resources.
# The way it does this is by using the credentials of the service account to authenticate with GCP.
resource "google_service_account" "terraform_sa" {
  account_id   = "terraform-sa"
  display_name = "Terraform Service Account"
}

# Create Service Account which is used by Cloud Run to deploy resources.
resource "google_service_account" "cloud_run_sa" {
  account_id   = "cloud-run-sa"
  display_name = "Cloud Run Service Account"
}


# Assign roles to the service account and grant permissions to deploy resources.
resource "google_project_iam_member" "terraform_sa_roles" {
  for_each = toset([
    "roles/owner",                        # Grants full access to most resources
    "roles/artifactregistry.admin",       # Manage Artifact Registry
    "roles/bigquery.admin",               # Full control over BigQuery
    "roles/run.admin",                    # Full control over Cloud Run
    "roles/iam.serviceAccountUser"        # Allows Terraform to use the service account
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform_sa.email}"
}

# Grant cloud run permission to pull from artifact registry
resource "google_project_iam_member" "cloud_run_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Create Artifact Registry
resource "google_artifact_registry_repository" "arvebgilpctest" {
  repository_id = "arvebgilpctest"
  location = var.region
  format   = "DOCKER"
}

/* # Create Cloud SQL (PostgreSQL) Instance
resource "google_sql_database_instance" "postgresql" {
  name = "sql-instance"
  region = "europe-north1"

  database_version = "POSTGRES_16"

  settings {
    tier = "db-f1-micro"
  }
} */

# Enable BigQuery API
resource "google_project_service" "bigquery" {
  service = "bigquery.googleapis.com"
}

# Create BigQuery Instance
resource "google_bigquery_dataset" "bq-vebgil_pc_test" {
  dataset_id = "bqvebgilpctest"
  project    = var.project_id
  location   = var.region
}

# Cloud Run Deployment
resource "google_cloud_run_service" "run-vebgil-pc-test" {
  name     = "run-vebgil-pc-test"
  location = var.region
  template {
    spec {
      service_account_name = google_service_account.cloud_run_sa.email
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/arvebgilpctest/portainer:latest"
        /* env {
          name  = "DB_HOST"
          value = "/cloudsql/allente-training:europe-north1:sql-vebgil-pc-test"
        }
        env {
          name  = "DB_USER"
          value = "postgres"
        }
        env {
          name  = "DB_PASSWORD"
          value_from {
            secret_key_ref {
              name = "sec-db-password"
              key  = "password"
            }
          }
        } */
      }
    }
  }
}

# Secret Manager (already done)
/* resource "google_secret_manager_secret" "db_password" {
  secret_id = "sec-db-password"
  replication {
    automatic = true
  }
} */

/* resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = "your-db-password" # Or load from a file securely
}
 */