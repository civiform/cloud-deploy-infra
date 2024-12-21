variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "tenant_id" {
  type        = string
  description = "Unique ID identifying the CiviForm SaaS tenant account"
}

variable "tenant_k8s_namespace" {
  type        = string
  description = "The tenant's k8s namespace"
}

variable "tenant_ksa_name" {
  type        = string
  description = "The tenant's k8s service account name"
}

variable "region" {
  type        = string
  description = "Default region for the project"
  default     = "us-west1"
}

variable "cluster_location" {
  type        = string
  description = "Default location for the existing cluster"
  default     = "us-west1"
}

variable "node_machine_type" {
  type        = string
  description = "GCE machine type for the node pool"
  default     = "e2-small"
}

variable "use_preemptible_nodes" {
  type        = bool
  description = "Whether the node pool will use preemptible nodes, which are less expensive"
  default     = true
}

variable "cluster_name" {
  type        = string
  description = "Name of the GKE cluster to deploy the server in"
  default     = "civiform-cluster"
}

variable "network_name" {
  type        = string
  description = "Name of the VPC network"
  default     = "civiform-vpc-network"
}

variable "server_image" {
  type        = string
  description = "Fully qualified CiviForm server Docker image tag to deploy"
  default     = "docker.io/civiform/civiform:latest"
}

variable "min_node_count" {
  type        = number
  description = "Minimum number of nodes in the tenant's nodepool, may scale higher"
  default     = 1
}

variable "db_enable_public_ip4" {
  type        = bool
  description = "Whether to configure a public IPv4 address for the database"
  default     = false
}

variable "db_tier_type" {
  type        = string
  description = "vm tier type to run db instance"
  default     = "db-f1-micro" # $8/mo in us-central1, https://cloud.google.com/sql/pricing
}

variable "db_deletion_protection" {
  type        = bool
  description = "The database cannot be deleted while deletion protection is enabled"
  default     = true
}

variable "port" {
  type        = string
  description = "Port the app is running on"
  default     = "9000"
}

variable "postgres_version" {
  type        = string
  description = "version of postgres to use"
  default     = "POSTGRES_16"
}
