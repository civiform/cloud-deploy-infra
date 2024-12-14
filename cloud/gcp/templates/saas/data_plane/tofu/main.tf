provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

data "google_container_cluster" "civiform_cluster" {
  name     = var.cluster_name
  location = var.cluster_location
}

data "google_compute_network" "civiform_network" {
  name = var.network_name
}

# We use GCP IAM via GKE Workload Identity Federation to authorize civiform server access to the
# database and other non-k8s GCP resources. This involves:
# 1. a GCP service account (https://cloud.google.com/iam/docs/service-account-overview)
#    - this is the account we attach permissions to, such as roles/cloudsql.client for db access
# 2. a kubernetes service account (https://kubernetes.io/docs/concepts/security/service-accounts/)
#    - this is the k8s role associated with k8s deployment running the civiform server
# 3. binding the two accounts together so GCP resources authorize requests from (2) as if they're coming from (1)
#
# Note that the k8s serice account doesn't exist when tofu first runs and is created with kubectl.
#
# For more info read https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity
resource "google_service_account" "tenant" {
  account_id   = "civiform-tenant-sa-${var.tenant_id}"
  display_name = "Tenant SA ${var.tenant_id}"
}

resource "google_service_account_iam_member" "gsa_workload_identity_user" {
  service_account_id = google_service_account.tenant.id
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.tenant_k8s_namespace}/${var.tenant_ksa_name}]"
}

resource "google_project_iam_member" "gsa_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.tenant.email}"
}

resource "google_project_iam_member" "gsa_node_account" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.tenant.email}"
}

resource "google_container_node_pool" "server" {
  name       = "np-tenant-${var.tenant_id}"
  cluster    = var.cluster_name
  location   = var.cluster_location
  node_count = var.min_node_count

  node_config {
    preemptible  = var.use_preemptible_nodes
    machine_type = var.node_machine_type

    # Kubernetes labels to set on all nodes in the pool
    labels = {
      node_pool_tenant_id = var.tenant_id
    }

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.tenant.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
