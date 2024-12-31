variable "tf_state_bucket_name" {
  type        = string
  description = "Bucket name for storing the TF state file"
}

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Region for the project"
  default     = "us-west1"
}

variable "cluster_deletion_protection" {
  type        = bool
  description = "Deletion protection enabled on the cluster"
  default     = true
}

variable "cluster_location" {
  type        = string
  description = "Location for the project, same as region for a regional cluster"
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

variable "min_node_count" {
  type        = number
  description = "Minimum number of nodes in the tenant's nodepool, may scale higher"
  default     = 1
}
