# CiviForm SaaS on GKE

This is a proof of concept with a lot of things missing before it's ready for prod.

## How to run the proof-of-concept

### Set up the control plane

1. Create a GCP account and project using the web console
2. Install deps:
  - `gcloud` CLI: https://cloud.google.com/sdk/docs/install
  - `tofu` CLI: https://opentofu.org/docs/intro/install/
  - `kubectl` CLI: https://kubernetes.io/docs/tasks/tools/
  - `helm` CLI: https://helm.sh/docs/intro/install/
  - `gcloud components install gke-gcloud-auth-plugin` - gcloud plugin for authorizing `kubectl` access to GKE
3. Authenticate: `gcloud auth application-default login`
4. `cd control_plane`
  - Run `./enable_apis.sh`, this will enable the GCP APIs tofu needs
5. `cd tofu`
  - Run `tofu init && tofu apply -var="project_id=<YOUR PROJECT ID>"`, this will create
    - a GKE cluster
    - a node pool called `np-control-plane` with one node for running external-dns
    - a service account for `np-control-plane`
6. Get cluster creds for `kubectl`: `gcloud container clusters get-credentials civiform-cluster <REGION>`
  - Make sure the creds work by fetching k8s info: `kubectl get namespaces`
7. Install external-dns in the cluster: `cd ../kubernetes && CLOUDFLARE_API_TOKEN=<TOKEN> ./install_external_dns.sh`

### Install a tenant

1. First, create the tenant's GCP resources. From the saas directory, `cd data_plane/tofu`
  - edit `demo.tfvars` with your project ID, make sure the region and cluster_location match what you used in setup 
  - `tofu init && tofu apply -var-file="demo.tfvars" -var="db_enable_public_ip4=true"`.
  - Save the output values somewhere
  - This will create tenant-specific:
    - tenant GCP service account
    - tenant Cloud SQL postgresql database
    - tenant nodepool for the server
  - Next we need to do some toil on the pg CLI because while the civiform service account has permission from GCP to connect to the DB, the PG database user it connects with has no internal permissions in PG, so we need to grant them. An alternative to the steps below that does not expose the DB to the internet for any period of time is to use Cloud SQL Studio in the GCP web console to execute the `GRANT` statements.
    - Inspect the tofu output and find the value for `db_username`, it will look like `civiform-cluster-sa@<YOUR PROJECT ID>.iam` unless you passed a variable for `cluster_service_account_name`. This is your `<CF PG UNAME>` value for the next commands.
    - Run `gcloud sql users set-password postgres --instance=civiform-tenant-<TENANT ID> --password="<CHOOSE A PASSWORD>"`
    - Run `gcloud sql connect civiform-db-<TENANT ID> --database=postgres --user=postgres`, login using the password you just set. Note: it is critical that you login as the `postgres` user, the following commands if run using your IAM user account will appear to succeed but fail silently. ASK ME HOW I KNOW.
    - Run `GRANT ALL PRIVILEGES ON DATABASE postgres TO "<CF PG UNAME>";`
    - Run `GRANT ALL PRIVILEGES ON SCHEMA public TO "<CF PG UNAME>";`
    - Run `tofu apply -var-file="demo.tfvars" -var="db_enable_public_ip4=false" -target="google_sql_database_instance.civiform_db"` to disable the DB public IP address
    - Alternative to the above: you can use Cloud SQL Studio in the GCP console to set the `postgres` user's password and execute the SQL statements using a browser UI.
2. Next, deploy the tenant's k8s resources. `cd ../kubernetes/tenant_chart`
  - Update `values.yaml` with the output values from `tofu apply` and the vars file in step (1)
  - `helm install <TENANT RELEASE NAME> .` to create the tenant's:
    - namespace
    - k8s Service account bound to the tenant's GCP service account
    - deployment running the CiviForm server
    - service referencing the server deployment
    - ingress with an l7 load balancer pointing to the service
