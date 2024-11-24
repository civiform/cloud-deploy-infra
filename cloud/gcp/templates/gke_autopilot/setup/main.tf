# google_client_config and kubernetes provider must be explicitly specified like the following.
data "google_client_config" "default" {}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

locals {
  gcp_services = [
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sql-component.googleapis.com",
    "storage-component.googleapis.com",
  ]

  services_ip_range_name = "services-range"
  pods_ip_range_name     = "pods-range"
}

resource "google_project_service" "gcp_services" {
  for_each = toset(local.gcp_services)
  project  = var.project_id
  service  = each.key
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

module "gke" {
  source                          = "terraform-google-modules/kubernetes-engine/google//modules/beta-autopilot-public-cluster"
  version                         = "34.0.0"
  project_id                      = var.project_id
  name                            = var.cluster_name
  service_account_name            = var.cluster_service_account_name
  region                          = var.region
  network                         = var.network_name
  subnetwork                      = var.subnetwork_name
  ip_range_pods                   = local.services_ip_range_name
  ip_range_services               = local.pods_ip_range_name
  release_channel                 = "STABLE"
  security_posture_mode           = "BASIC"
  http_load_balancing             = true
  enable_vertical_pod_autoscaling = true
  horizontal_pod_autoscaling      = true
  deletion_protection             = false

  depends_on = [google_project_service.gcp_services]
}
