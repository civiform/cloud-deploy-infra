provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

data "google_container_cluster" "civiform_cluster" {
  name     = var.cluster_name
  location = var.region
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.civiform_cluster.endpoint}"
  token = data.google_client_config.default.access_token

  # Protect traffic to the Kubernetes control plane with TLS
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.civiform_cluster.master_auth[0].cluster_ca_certificate,
  )

  # The gcloud access token is stored in TF state but expires hourly,
  # this plugin refreshes it on each Terraform apply
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }

  # GKE Autopilot and GCP use k8s annotations to store info about autoscaling
  # and other features. Terraform will notice them and try to destroy them on
  # subsequent `apply` runs unless they're ignored.
  ignore_annotations = [
    "^autopilot\\.gke\\.io\\/.*",
    "^cloud\\.google\\.com\\/.*"
  ]
}

locals {
  server_port_name       = "http-server"
  services_ip_range_name = "services-range"
  pods_ip_range_name     = "pods-range"
  k8s_namespace          = "default"
  db_password            = "insecure"
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
# For more info read https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity
resource "google_service_account" "civiform_gsa" {
  account_id   = var.cluster_service_account_name
  display_name = "CF Service Account"
}

resource "kubernetes_service_account" "civiform_ksa" {
  metadata {
    name      = "civiform-ksa"
    namespace = local.k8s_namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.civiform_gsa.email
    }
  }
}

resource "google_service_account_iam_member" "gsa_workload_identity_user" {
  service_account_id = google_service_account.civiform_gsa.id
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${local.k8s_namespace}/${kubernetes_service_account.civiform_ksa.metadata[0].name}]"
}

resource "kubernetes_deployment_v1" "civiform_server" {
  metadata {
    name = "civiform-server-deployment"
  }

  spec {
    selector {
      match_labels = {
        app = "civiform-server"
      }
    }

    template {
      metadata {
        labels = {
          app = "civiform-server"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.civiform_ksa.metadata[0].name

        container {
          name  = "civiform-server-container"
          image = var.server_image

          port {
            container_port = var.port
            name           = local.server_port_name
          }

          security_context {
            allow_privilege_escalation = false
            privileged                 = false
            read_only_root_filesystem  = false

            capabilities {
              add = []
              drop = [
                "NET_RAW",
              ]
            }
          }

          liveness_probe {
            http_get {
              path = "/playIndex"
              port = var.port
            }

            period_seconds    = 10
            failure_threshold = 6
          }

          startup_probe {
            http_get {
              path = "/playIndex"
              port = var.port
            }

            initial_delay_seconds = 60
            failure_threshold     = 30
            period_seconds        = 30
          }

          env {
            name  = "PORT"
            value = var.port
          }
          env {
            name  = "CIVIFORM_APPLICANT_IDP"
            value = "disabled"
          }
          env {
            name  = "CIVIFORM_MODE"
            value = "dev"
          }
          env {
            name  = "APPLICANT_OIDC_CLIENT_ID"
            value = "client"
          }
          env {
            name  = "APPLICANT_OIDC_CLIENT_SECRET"
            value = "notarealsecret"
          }
          env {
            name  = "APPLICANT_OIDC_DISCOVERY_URI"
            value = "https://civiform-staging.us.auth0.com/.well-known/openid-configuration"
          }
          env {
            name  = "CIVIFORM_APPLICANT_IDP"
            value = "auth0"
          }
          env {
            name  = "WHITELABEL_CIVIC_ENTITY_SHORT_NAME"
            value = "CF on GCP"
          }
          env {
            name  = "WHITELABEL_CIVIC_ENTITY_FULL_NAME"
            value = "CiviForm on GCP"
          }
          env {
            name  = "SECRET_KEY"
            value = "inecureinsecureinsecureinsecureinsecureinsecureinsecure"
          }
          env {
            name  = "DB_JDBC_STRING"
            value = "jdbc:postgresql:///postgres?cloudSqlInstance=${google_sql_database_instance.civiform_db.connection_name}&socketFactory=com.google.cloud.sql.postgres.SocketFactory&ipTypes=PRIVATE&enableIamAuth=true&user=${google_sql_user.civiform_user.name}&sslmode=disable"
          }
          env {
            name  = "DB_USERNAME"
            value = google_sql_user.civiform_user.name
          }
          env {
            # A non-empty DB password is required to pass pg driver validation,
            # but the cloud IAM connector ignores it and uses IAM which is more secure
            # https://github.com/GoogleCloudPlatform/cloud-sql-jdbc-socket-factory/blob/main/docs/jdbc.md#iam-authentication
            name  = "DB_PASSWORD"
            value = local.db_password
          }
        }

        security_context {
          run_as_non_root = true

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        # Toleration is currently required to prevent perpetual diff:
        # https://github.com/hashicorp/terraform-provider-kubernetes/pull/2380
        toleration {
          effect   = "NoSchedule"
          key      = "kubernetes.io/arch"
          operator = "Equal"
          value    = "amd64"
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "civiform_server" {
  metadata {
    name = "civiform-server"
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = kubernetes_deployment_v1.civiform_server.spec[0].selector[0].match_labels.app
    }

    ip_family_policy = "RequireDualStack"

    port {
      port        = 80
      target_port = local.server_port_name
    }
  }
}

# The server connects to the database via private networking so that traffic is
# not exposed to the public internet.
resource "google_service_networking_connection" "db_network_connection" {
  network                 = data.google_compute_network.civiform_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.db_private_ip.name]
}

resource "google_compute_global_address" "db_private_ip" {
  name          = "db-private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = data.google_compute_network.civiform_network.id
}

# The instance automatically creates an internal postgresql DB called
# "postgres" which is what the server JDBC string specifies for use.
resource "google_sql_database_instance" "civiform_db" {
  name                = "civiform-db"
  region              = var.region
  database_version    = var.postgres_version
  deletion_protection = var.db_deletion_protection

  settings {
    tier    = var.db_tier_type
    edition = "ENTERPRISE"

    ip_configuration {
      # "ipv4" here means a *public* IP address
      ipv4_enabled = var.db_enable_public_ip4
      # The server connects to the database via private networking so that traffic is not
      # exposed to the public internet.
      private_network                               = data.google_compute_network.civiform_network.self_link
      enable_private_path_for_google_cloud_services = true
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
  }

  depends_on = [google_service_networking_connection.db_network_connection]
}

# Allows the service account to connect to and fetch metadata about the DB instance
resource "google_project_iam_binding" "db_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"

  members = [
    "serviceAccount:${google_service_account.civiform_gsa.email}",
  ]
}

# Allows the service account to connect to and fetch metadata about the DB instance
# See https://cloud.google.com/sql/docs/postgres/iam-roles
resource "google_project_iam_binding" "db_user" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"

  members = [
    "serviceAccount:${google_service_account.civiform_gsa.email}",
  ]
}

# Allows the service account to login to the DB instance
# See https://cloud.google.com/sql/docs/postgres/iam-roles
resource "google_sql_user" "civiform_user" {
  name     = trimsuffix(google_service_account.civiform_gsa.email, ".gserviceaccount.com")
  instance = google_sql_database_instance.civiform_db.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}
