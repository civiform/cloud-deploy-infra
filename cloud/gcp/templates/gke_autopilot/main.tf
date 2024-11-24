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

data "google_container_cluster" "civiform_cluster" {
  name     = var.cluster_name
  location = var.region
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.civiform_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token

  // protect traffic to the KCP with TLS
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.civiform_cluster.master_auth[0].cluster_ca_certificate,
  )

  // The access token is stored in TF state but expires hourly, this plugin refreshes it on each Terraform apply
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
}

locals {
  server_port_name       = "http-server"
  services_ip_range_name = "services-range"
  pods_ip_range_name     = "pods-range"
  fully_qualified_service_account = "${var.cluster_service_account_name}@${var.project_id}.iam.gserviceaccount.com"
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
          }

          liveness_probe {
            http_get {
              path = "/playIndex"
              port = var.port
            }

            initial_delay_seconds = 60
            period_seconds        = 10
          }

          env {
            name  = "PORT"
            value = var.port
          }
          env {
            name = "CIVIFORM_APPLICANT_IDP"
            value = "disabled"
          }
          env {
            name = "APPLICANT_OIDC_CLIENT_ID"
            value = "client"
          }
          env {
            name = "APPLICANT_OIDC_CLIENT_SECRET"
            value = "notarealsecret"
          }
          env {
            name = "APPLICANT_OIDC_DISCOVERY_URI"
            value = "https://civiform-staging.us.auth0.com/.well-known/openid-configuration"
          }
          env {
            name = "CIVIFORM_APPLICANT_IDP"
            value = "auth0"
          }
          env {
            name = "WHITELABEL_CIVIC_ENTITY_SHORT_NAME"
            value = "CF on GCP"
          }
          env {
            name = "WHITELABEL_CIVIC_ENTITY_FULL_NAME"
            value = "CiviForm on GCP"
          }
          env {
            name = "SECRET_KEY"
            value = "K5SgucxBYC3xJwNcGWZV1Y7uASmrc"
          }
          env {
            name  = "DB_JDBC_STRING"
            value = "jdbc:postgresql:///${module.database.pg_db_name}?cloudSqlInstance=${module.database.connection_name}&socketFactory=com.google.cloud.sql.postgres.SocketFactory"
          }
          env {
            name  = "DB_USERNAME"
            value = module.database.user
          }
          env {
            // A non-empty DB password is required to pass pg driver validation,
            // but the cloud IAM connector ignores it and uses IAM which is more secure
            // https://github.com/GoogleCloudPlatform/cloud-sql-jdbc-socket-factory/blob/main/docs/jdbc.md#iam-authentication
            name  = "DB_PASSWORD"
            value = "ignored"
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

module "database" {
  source          = "./modules/database"
  region          = var.region
  tier_type       = var.db_tier_type
  service_account = local.fully_qualified_service_account
}
