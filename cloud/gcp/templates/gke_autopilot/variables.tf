variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "cluster_name" {
  type = string
  description = "Name of the GKE cluster to deploy the server in"
  default = "civiform-cluster"
}

variable "cluster_service_account_name" {
  type = string
  description = "Name of the GKE cluster's service account"
  default = "civiform-cluster-sa"
}

variable "server_image" {
  type        = string
  description = "Fully qualified CiviForm server Docker image tag to deploy"
  default     = "docker.io/civiform/civiform:latest"
}

variable "region" {
  type        = string
  default     = "us-west1"
  description = "Default region for the project"
}

variable "application_name_postfix" {
  type        = string
  default     = "civiform"
  description = "application name to be used as postfix to resources"
}

variable "db_tier_type" {
  type        = string
  description = "vm tier type to run db instance"
  default     = "db-custom-1-3840"
}

variable "port" {
  type        = string
  description = "Port the app is running on"
  default     = "9000"
}
