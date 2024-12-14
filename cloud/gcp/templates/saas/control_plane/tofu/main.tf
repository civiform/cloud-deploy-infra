provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  services_ip_range_name = "services-range"
  pods_ip_range_name     = "pods-range"
}

resource "google_compute_network" "civiform" {
  name                     = var.network_name
  description              = "VPC network for the application."
  enable_ula_internal_ipv6 = true
  auto_create_subnetworks  = false
}

resource "google_compute_subnetwork" "civiform" {
  name             = var.subnetwork_name
  network          = google_compute_network.civiform.id
  ip_cidr_range    = "10.0.0.0/16"
  region           = var.region
  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "INTERNAL"
}

resource "google_container_cluster" "civiform" {
  name                     = var.cluster_name
  location                 = var.cluster_location
  deletion_protection      = var.cluster_deletion_protection
  network                  = google_compute_network.civiform.id
  subnetwork               = google_compute_subnetwork.civiform.id
  datapath_provider        = "ADVANCED_DATAPATH"
  enable_l4_ilb_subsetting = true

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  vertical_pod_autoscaling {
    enabled = true
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "STABLE"
  }

  ip_allocation_policy {
    stack_type = "IPV4_IPV6"
  }
}
