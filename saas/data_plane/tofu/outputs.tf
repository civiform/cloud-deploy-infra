output "db_connection_name" {
  value = google_sql_database_instance.civiform_db.connection_name
}

output "db_username" {
  value = google_sql_user.civiform_user.name
}

output "gsa_email" {
  value = google_service_account.tenant.email
}

output "node_pool_name" {
  value = google_container_node_pool.server.name
}

output "applicant_files_bucket_name" {
  value = google_storage_bucket.applicant_files.name
}
