resource "google_sql_database_instance" "civiform_db" {
  name             = "civiform-db"
  region           = var.region
  database_version = var.postgres_version

  settings {
    tier = var.tier_type
    edition = "ENTERPRISE"

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    ip_configuration {
      ipv4_enabled = true
    }
  }
}

resource "google_sql_user" "civiform_user" {
  name     = trimsuffix(var.service_account, ".gserviceaccount.com")
  instance = google_sql_database_instance.civiform_db.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}
