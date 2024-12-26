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
  - `cloud-sql-proxy` CLI: https://cloud.google.com/sql/docs/mysql/sql-proxy#install - after downloading, ensure it is available on your shell PATH
  - `gcloud components install gke-gcloud-auth-plugin` - gcloud plugin for authorizing `kubectl` access to GKE
3. Authenticate: `gcloud auth application-default login`
4. `cd control_plane`
  - Run `./enable_apis.sh`, this will enable the GCP APIs tofu needs
5. Create a bucket to store tf state in
  - Read the basics about bucket naming: https://cloud.google.com/storage/docs/buckets#naming
  - In particular: BUCKET NAMES ARE PUBLICLY VISIBLE AND MUST BE GLOBALLY UNIQUE
  - `gcloud storage buckets create gs://<BUCKET NAME> --project=<PROJECT ID> --location=<LOCATION>`
  - Save the bucket name
6. `cd tofu`
  - Run `tofu init -var="tf_state_bucket_name=<BUCKET>" && tofu apply -var="tf_state_bucket_name=<BUCKET>" -var="project_id=<YOUR PROJECT ID>"`, this will create
    - a GKE cluster
    - a node pool called `np-control-plane` with one node for running external-dns
    - a service account for `np-control-plane`
7. Get cluster creds for `kubectl`: `gcloud container clusters get-credentials civiform-cluster --location <CLUSTER LOCATION>`
  - Make sure the creds work by fetching k8s info: `kubectl get namespaces`
8. Install external-dns in the cluster: `cd ../kubernetes && CLOUDFLARE_API_TOKEN=<TOKEN> ./install_external_dns.sh`

### Turnup a tenant

#### Using automation

1. Write a tenant config file, see `demo_tenant_config.yaml` for an example
2. Run the turnup script from the root `saas` directory `./civ turnup-tenant --tenant_config=tenant_config.yaml`

#### Manually

1. First, create the tenant's GCP resources. From the saas directory, `cd data_plane/tofu`
  - edit `demo.tfvars` with your project ID and bucket name, make sure the region and cluster_location match what you used in setup 
  - `tofu init -var-file="demo.tfvars" && tofu apply -var-file="demo.tfvars" -var="db_enable_public_ip4=true"`.
  - Save the output values somewhere
  - This will create tenant-specific:
    - tenant GCP service account
    - tenant Cloud SQL postgresql database
    - tenant nodepool for the server
  - Next we need to do some toil because while the tenant service account has permission from GCP to connect to the DB instance, the PG database user it connects with has no internal permissions in PG, so we need to grant all database and public schema privileges for the `postgres` internal database to the service account user. Nota bene it's critical that the `postgres` user account performs these grants, otherwise they will appear to succeed but fail silently (the DB logs in the GCP console will reveal "no permissions changed" when this happens). Alternative to running the script in the steps below: you can use Cloud SQL Studio in the GCP console to set the `postgres` user's password and execute the SQL statements using a browser UI.
    1. Inspect the tofu output and find the values for `db_username` (it will look like `civiform-cluster-sa@<YOUR PROJECT ID>.iam` -- it's the service account name **without** `gserviceaccount.com` suffix) and `db_connection_name`. These are your `<DB UNAME>` and `<DB CONN>` values for the next command.
    2. `cd ..` then run `./service_account_db_grants <DB CONN> <DB UNAME>`
    3. Run `tofu apply -var-file="demo.tfvars" -var="db_enable_public_ip4=false" -target="google_sql_database_instance.civiform_db"` to disable the DB public IP address
2. Next, deploy the tenant's k8s resources. `cd kubernetes/tenant_chart`
  - Update `values.yaml` with the output values from `tofu apply` and the vars file in step (1)
  - `helm install <TENANT RELEASE NAME> .` to create the tenant's:
    - namespace
    - k8s Service account bound to the tenant's GCP service account
    - deployment running the CiviForm server
    - service referencing the server deployment
    - ingress with an l7 load balancer pointing to the service
