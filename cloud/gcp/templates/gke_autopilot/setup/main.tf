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
  name    = var.subnetwork_name
  network = google_compute_network.civiform.id

  ip_cidr_range = "10.0.0.0/16"
  region        = var.region

  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "EXTERNAL"

  secondary_ip_range {
    range_name    = local.services_ip_range_name
    ip_cidr_range = "192.168.0.0/24"
  }

  secondary_ip_range {
    range_name    = local.pods_ip_range_name
    ip_cidr_range = "192.168.1.0/24"
  }
}

resource "google_container_cluster" "civiform" {
  name = var.cluster_name

  location                 = var.region
  enable_autopilot         = true
  enable_l4_ilb_subsetting = true
  deletion_protection      = false
  network                  = google_compute_network.civiform.id
  subnetwork               = google_compute_subnetwork.civiform.id

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "STABLE"
  }

  ip_allocation_policy {
    stack_type                    = "IPV4_IPV6"
    services_secondary_range_name = google_compute_subnetwork.civiform.secondary_ip_range[0].range_name
    cluster_secondary_range_name  = google_compute_subnetwork.civiform.secondary_ip_range[1].range_name
  }
}
