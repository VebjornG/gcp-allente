#GCP provider
provider "google" {
  credentials = file(var.gcp_allente_test_SA) # If using using a service account, otherwise omit this
  project     = var.project_id
  region      = var.region
}