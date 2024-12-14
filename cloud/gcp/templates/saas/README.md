# CiviForm SaaS on GKE

This is a proof of concept with a lot of things missing before it's ready for prod.

## How to run the proof-of-concept

IN PROGRESS, STEPS BELOW ARE INCOMPLETE

1. Create a GCP account and project using the web console
2. Install deps:
  - `gcloud` CLI: https://cloud.google.com/sdk/docs/install
  - `tofu` CLI: https://opentofu.org/docs/intro/install/
  - `kubectl` CLI: https://kubernetes.io/docs/tasks/tools/
  - `gcloud components install gke-gcloud-auth-plugin` - gcloud plugin for authorizing kubectl access to GKE
3. Authenticate: `gcloud auth application-default login`
4. `cd control_plane`
  - Run `./enable_apis.sh`, this will enable the GCP APIs tofu needs
5. `cd tofu`
  - Run `tofu init && tofu apply -var="project_id=<YOUR PROJECT ID>"`, this will create a VPC network and a GKE cluster
6. `cd ../kubernetes`
  - Run `CLOUDFLARE_API_TOKEN=<TOKEN> CLOUDFLARE_ ./install_external_dns.sh`
7. `cd ../data_plane/tofu`
  - `tofu init && tofu apply -var="project_id=<YOUR PROJECT ID>" -var="db_enable_public_ip4=true"`.
  - Save the output values
  - This will create tenant-specific:
    - GCP service account
    - a Cloud SQL postgresql database
  - Next we need to do some toil on the pg CLI because while the civiform service account has permission from GCP to connect to the DB, the PG database user it connects with has no internal permissions in PG, so we need to grant them. An alternative to the steps below that does not expose the DB to the internet for any period of time is to use Cloud SQL Studio in the GCP web console to execute the `GRANT` statements.
    - Inspect the tofu plan output and find the creation plan for `google_sql_user.civiform_user`
    - Save the value for `name`, it will look like `civiform-cluster-sa@<YOUR PROJECT ID>.iam` unless you passed a variable for `cluster_service_account_name`. This is your `<CF PG UNAME>` value for the next commands.
    - Run `gcloud sql users set-password postgres --instance=civiform-db --password="<CHOOSE A PASSWORD>"`
    - Run `gcloud sql connect civiform-db --database=postgres --user=postgres`, login using the password you just set. Note: it is critical that you login as the `postgres` user, the following commands if run using your IAM user account will appear to succeed but fail silently. ASK ME HOW I KNOW.
    - Run `GRANT ALL PRIVILEGES ON DATABASE postgres TO "<CF PG UNAME>";`
    - Run `GRANT ALL PRIVILEGES ON SCHEMA public TO "<CF PG UNAME>";`
    - The civiform server should be able to execute queries now and stop crashlooping
    - Run `tofu apply -var="project_id=<YOUR PROJECT ID>" -var="db_enable_public_ip4=false" -target="google_sql_database_instance.civiform_db"` to disable the DB public IP address
8. `cd ../kubernetes/tenant_chart`
  - Update `values.yaml` with the output values from the first `tofu apply` for the tenant
  - `helm install -f values.yaml <TENANT RELEASE NAME> .` to create for the tenant k8s resources:
    - Namespace
    - Service account bound to the tenant's GCP service account
    - Deployment running the civiform server
    - Service referencing the server deployment
    - Ingress with an l7 load balancer pointing to the service
