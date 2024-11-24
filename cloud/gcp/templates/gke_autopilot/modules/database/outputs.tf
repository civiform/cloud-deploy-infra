output "connection_name" {
  value = google_sql_database_instance.civiform_db.connection_name
}

output "pg_db_name" {
  value = google_sql_database_instance.civiform_db.name
}

output "user" {
  value = google_sql_user.civiform_user.name
}
