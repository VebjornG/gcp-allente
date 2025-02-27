/* variable "gcp_allente_test_SA" {
  description = "The path to the service account key file for the GCP project"
  default     = "allente-training-sa.json"
  type        = string
} */

variable "project_id" {
  description = "The GCP project ID"
  default     = "allente-training"
  type        = string
}

variable "region" {
  description = "The GCP region"
  default     = "europe-north1"
  type        = string
}