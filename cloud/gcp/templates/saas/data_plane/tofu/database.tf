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
  name                = "civiform-tenant-${var.tenant_id}"
  region              = var.region
  database_version    = var.postgres_version
  deletion_protection = var.db_deletion_protection

  settings {
    tier    = var.db_tier_type
    edition = "ENTERPRISE"

    ip_configuration {
      # While "ipv4" here does mean a *public* IP address, which is more than a little unsettling,
      # GCP blocks connections to it that don't come from authorized networks or IAM-authenticated
      # principals. Still though, the only need for a public ipv4 is during setup when we connect
      # to grant DB privileges to the service account PG user. Once that task is taken care of
      # some other way -- probably via a k8s job that runs as part of setup and connects via GCP
      # private networking just like the server does -- then at no point will it be necessary for
      # the DB to have a public IP address.
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

  timeouts {
    create = "30m"
  }
}

# https://github.com/hashicorp/terraform-provider-google/issues/14233
resource "time_sleep" "wait_after_db_create" {
  depends_on      = [google_sql_database_instance.civiform_db]
  create_duration = "60s"
}

# Allows the service account to login as a Postgres user
# See https://cloud.google.com/sql/docs/postgres/iam-roles
resource "google_sql_user" "civiform_user" {
  name     = trimsuffix(google_service_account.tenant.email, ".gserviceaccount.com")
  instance = google_sql_database_instance.civiform_db.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"

  depends_on = [
    time_sleep.wait_after_db_create
  ]
}

# Allows the service account to connect to and fetch metadata about the DB instance
resource "google_project_iam_binding" "db_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"

  members = [
    "serviceAccount:${google_service_account.tenant.email}",
  ]

  condition {
    title       = "Tenant-scoped access"
    description = "Tenant service accounts only permitted access to their own database"
    expression  = <<EOT
resource.type == 'sqladmin.googleapis.com/Instance' &&
resource.name == 'projects/${var.project_id}/instances/${google_sql_database_instance.civiform_db.name}'
EOT
  }
}

# Allows the service account to connect to and fetch metadata about the DB instance
# See https://cloud.google.com/sql/docs/postgres/iam-roles
resource "google_project_iam_binding" "db_user" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"

  members = [
    "serviceAccount:${google_service_account.tenant.email}",
  ]

  condition {
    title       = "Tenant-scoped access"
    description = "Tenant service accounts only permitted access to their own database"
    expression  = <<EOT
resource.type == 'sqladmin.googleapis.com/Instance' &&
resource.name == 'projects/${var.project_id}/instances/${google_sql_database_instance.civiform_db.name}'
EOT
  }
}
