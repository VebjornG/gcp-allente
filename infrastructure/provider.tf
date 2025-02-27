terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

# Use Application Default Credentials or Workload Identity Federation instead of a service account key file
provider "google" {
  project = var.project_id
  region  = var.region
}