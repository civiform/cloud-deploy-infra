# Set Up Access/Connection
  # See Dump File
# Truncate all tables
  # e.g. psql -U username -d mydatabase -c 'SELECT * FROM mytable'
  # https://www.postgresql.org/docs/13/app-psql.html
  # TRUNCATE TABLE files CASCADE;
  # TRUNCATE TABLE applications CASCADE;
  # TRUNCATE TABLE applicants CASCADE;
  # TRUNCATE TABLE accounts CASCADE;
  # TRUNCATE TABLE programs CASCADE;
  # TRUNCATE TABLE questions;
  # TRUNCATE TABLE versions CASCADE;
  # TRUNCATE TABLE versions_programs CASCADE;
  # TRUNCATE TABLE versions_questions CASCADE;
  # TRUNCATE TABLE questions CASCADE;
# Provide access to a pg_dump file (copy from local computer)
# Run the pg_restore command e.g. /usr/local/pgsql-12/pg_restore --host "dkatz-dev2-civiform-db.cfi9ipzsvec3.us-east-2.rds.amazonaws.com" --port "5432" --username "db_admin_Sf5PtqR" --dbname "postgres" --clean --no-privileges --no-owner -v -d postgres --region us-east-2 --verbose "/var/lib/pgadmin/storage/k6yQPo1dvF_default.login/program_data.dump"
# Give the password
# Verify