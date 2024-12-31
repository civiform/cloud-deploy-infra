# CiviForm SaaS on GKE

This is a proof of concept with a lot of things missing before it's ready for prod.

Code for managing resources is divided into `control_plane` and `data_plane` subdirs, see design doc for explanation of those terms. Both have their own subdirs for `tofu` and `kubernetes`, the former is for managing GCP resources (e.g. networks, GCP service accounts, storage buckets, databases, GKE node pools, etc) and the latter is for managing in-cluster kubernetes resources.

The `civ` executable and supporting `cli` subdir contain automation for tenant management. At the moment `civ` must be run manually by a privileged human user, which is a security concern because it requires operator laptops to have highly privileged API accesss along with tenant secrets on the hard drive. Building `civ.Dockerfile` with `cloudbuild.yaml` will build an image that can run `civ` in a container with the necessary dependencies. Still missing is a service account with necessary permissions to run it and a secure way to provide tenant config (including secrets) to it.

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
9. Prepare SSL
  - Create a DNS authorization for GCP: `gcloud certificate-manager dns-authorizations create <AUTH NAME> --domain=tenant.civiform.dev` where `<AUTH NAME>` is a unique name for the authorization given to GCP to create TLS certs for the domain.
  - Call `gcloud certificate-manager dns-authorizations describe <AUTH NAME>` and use the `data`, `name`, and `type` properties to create a record in CloudFlare to authorize GCP SSL certs. Disable CloudFlare DNS proxying so it's a DNS-only record. Note this step can take O(hours), you can do the next step while you wait and it'll block on this one.
  - Go to [certificate manager](https://console.cloud.google.com/security/ccm/list/certificates) and create a `*.tenant.civiform.dev ` cert, give it a unique name (you'll use this name in the next step and when turning up tenants).

### Turnup a tenant

Note that it can take awhile for managed SSL certs to become available O(hours) after initial turnup -- I don't know if that is only an issue after initial cert provisioning or if it'll be a delay experienced on every new domain turnup. There are alternative ways of managed SSL certs, the current approach is to provision a single wildcard cert that is shared among all domains/tenants.

Turnup steps:

1. Write a tenant config file, see `demo_tenant_config.yaml` for an example
2. From the root `saas` directory, run the turnup command passing your config file: `./civ tenant-turnup --tenant_config=tenant_config.yaml`

After turning up a tenant, check the SSL cert status first by finding it's name `kubectl get managedcertificate --namespace <TENANT NAMESPACE>` and then describing it `kubectl describe managedcertificate <SSL CERT NAME> --namespace <TENANT NAMESPACE>`. If `Certificate Status` is not `Active` then the domain name won't work.
