# CiviForm on GKE

This is a proof of concept for deploying CiviForm on GKE and has not been integrated with the civiform deployment system.

## How to run the proof-of-concept

1. Create a GCP account and project using the web console
2. Install `gcloud` CLI: https://cloud.google.com/sdk/docs/install
3. Authenticate: `gcloud auth application-default login`
4. `cd` into the `setup` subdir 
5. Run `./enable_apis.sh`, this will enable the GCP APIs terraform needs for civiform
6. Run `terraform init && terraform apply -var="project_id=<YOUR PROJECT ID>"`, this will create a VPC network and a GKE cluster
7. `cd ..` back to this directory and run `terraform init && terraform apply -var="project_id=<YOUR PROJECT ID>" -var="db_enable_public_ip4=true"`.
  - This will create:
    - GCP and k8s service accounts for civiform
    - a Cloud SQL postgresql database
    - a k8s deployment running the civiform server
    - a k8s service exposing the civiform server via an ipv4 load balancer
  - The apply may time out because the service never becomes healthy, we need to do some toil on the pg CLI
    - This is because, while the civiform service account has permission from GCP to connect to the DB, the PG database user it connects with has no internal permissions in PG, so we need to grant them.
    - Inspect the terraform plan output and find the creation plan for `google_sql_user.civiform_user`
    - Save the value for `name`, it will look like `civiform-cluster-sa@<YOUR PROJECT ID>.iam` unless you passed a variable for `cluster_service_account_name`. This is your `<CF PG UNAME>` value for the next commands.
    - Run `gcloud sql users set-password postgres --instance=civiform-db --password="<CHOOSE A PASSWORD>"`
    - Run `gcloud sql connect civiform-db --database=postgres --user=postgres`, login using the password you just set 
    - Run `GRANT ALL PRIVILEGES ON DATABASE postgres to "<CF PG UNAME>";`
    - Run `GRANT ALL PRIVILEGES ON SCHEMA public to "<CF PG UNAME>";`
    - The civiform server should be able to execute queries now and stop crashlooping
  - Run `terraform apply -var="project_id=<YOUR PROJECT ID>" -var="db_enable_public_ip4=false" -target="google_sql_database_instance.civiform_db"` to disable the DB public IP address
