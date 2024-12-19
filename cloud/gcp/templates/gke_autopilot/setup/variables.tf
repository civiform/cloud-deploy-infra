variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Default region for the project"
  default     = "us-west1"
}

variable "cluster_name" {
  type        = string
  description = "Name of the GKE cluster to create"
  default     = "civiform-cluster"
}

variable "network_name" {
  type        = string
  description = "Name of the network used for the GKE cluster"
  default     = "civiform-vpc-network"
}

variable "subnetwork_name" {
  type        = string
  description = "Name of the subnetwork used for the GKE cluster"
  default     = "civiform-server-subnetwork"
}
