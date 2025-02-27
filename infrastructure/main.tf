# Enable required APIs
resource "google_project_service" "secretmanager" {
  service = "secretmanager.googleapis.com"
  disable_dependent_services = false
}

resource "google_project_service" "cloudrun" {
  service = "run.googleapis.com"
  disable_dependent_services = false
}

resource "google_project_service" "artifactregistry" {
  service = "artifactregistry.googleapis.com"
  disable_dependent_services = false
}

# Create Terraform Service Account with more minimal permissions
resource "google_service_account" "terraform_sa" {
  account_id   = "terraform-sa"
  display_name = "Terraform Service Account"
}

# Create Cloud Run Service Account
resource "google_service_account" "cloud_run_sa" {
  account_id   = "cloud-run-sa"
  display_name = "Cloud Run Service Account"
}

# Assign more limited roles to the Terraform service account
resource "google_project_iam_member" "terraform_sa_roles" {
  for_each = toset([
    "roles/artifactregistry.admin",       # Manage Artifact Registry
    "roles/run.admin",                    # Full control over Cloud Run
    "roles/iam.serviceAccountUser",       # Allows Terraform to use the service account
    "roles/secretmanager.admin"           # Manage Secret Manager
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform_sa.email}"
}


/* # Grant Cloud Run permissions
resource "google_project_iam_member" "cloud_run_permissions" {
  for_each = toset([
    "roles/artifactregistry.reader",       # Read from Artifact Registry
    "roles/secretmanager.secretAccessor"   # Access secrets
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
} */

# Grant permissions to the Cloud Build service account
resource "google_project_iam_member" "cloudbuild_permissions" {
  for_each = toset([
    "roles/serviceusage.serviceUsageAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/artifactregistry.admin",
    "roles/run.admin",
    "roles/cloudbuild.builds.builder",
    "roles/secretmanager.admin"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:923078808085@cloudbuild.gserviceaccount.com"
}

# Create Artifact Registry
resource "google_artifact_registry_repository" "portainer_repo" {
  depends_on = [google_project_service.artifactregistry]
  repository_id = "arvebgilpctest"
  location = var.region
  format   = "DOCKER"
}

# Create Secret for Service Account Key
resource "google_secret_manager_secret" "cloud_run_sa_key" {
  depends_on  = [google_project_service.secretmanager]
  secret_id   = "cloud-run-sa-key"
  replication {
    automatic = true
  }
}

# Create Service Account Key
resource "google_service_account_key" "cloud_run_sa_key" {
  service_account_id = google_service_account.cloud_run_sa.name
}

# Store Service Account Key in Secret Manager
resource "google_secret_manager_secret_version" "cloud_run_sa_key_version" {
  secret      = google_secret_manager_secret.cloud_run_sa_key.id
  secret_data = base64decode(google_service_account_key.cloud_run_sa_key.private_key)
}

# Cloud Run Deployment for Portainer
resource "google_cloud_run_service" "portainer" {
  depends_on = [google_project_service.cloudrun]
  name     = "run-vebgil-pc-test"
  location = var.region
  
  template {
    spec {
      service_account_name = google_service_account.cloud_run_sa.email
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/arvebgilpctest/portainer:latest"
        
        ports {
          container_port = 9000
        }
        
        # Mount service account key from Secret Manager
        env {
          name  = "GOOGLE_APPLICATION_CREDENTIALS"
          value = "/secrets/sa-key/key.json"
        }
        
        volume_mounts {
          name = "sa-key-volume"
          mount_path = "/secrets/sa-key"
        }
      }
      
      volumes {
        name = "sa-key-volume"
        secret {
          secret_name = google_secret_manager_secret.cloud_run_sa_key.secret_id
          items {
            key = "latest"
            path = "key.json"
          }
        }
      }
    }
  }
}


# Make the Portainer service publicly accessible
resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_service.portainer.location
  service  = google_cloud_run_service.portainer.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Output the URL of the deployed service
output "portainer_url" {
  value = google_cloud_run_service.portainer.status[0].url
}

/* # Create Service Account which is used to deploy resources.
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

 # Create Cloud SQL (PostgreSQL) Instance
resource "google_sql_database_instance" "postgresql" {
  name = "sql-instance"
  region = "europe-north1"

  database_version = "POSTGRES_16"

  settings {
    tier = "db-f1-micro"
  }
} 

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
        }
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