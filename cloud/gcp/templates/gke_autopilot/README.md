# CiviForm on GKE

This is a proof of concept for deploying CiviForm on GKE and has not been integrated with the civiform deployment system.

## How to run the proof-of-concept

1. Create a GCP account and project using the web console
1. Install `gcloud` CLI: https://cloud.google.com/sdk/docs/install
1. Authenticate: `gcloud auth application-default login`
1. `cd` into the `setup` subdir and run `terraform init && terraform apply`, this will:
  - enable the GCP APIs needed for the proof of concept
  - create a network and subnetwork for the GKE cluster
  - create a GKE cluster
  - create a service account associated with the cluster
5. `cd` back to this directory and run `terraform init && terraform apply`, this will:
  - create a Cloud SQL postgres database with access granted to the cluster's service account
  - create a k8s deployment running the civiform server
  - create a k8s service exposing the civiform server via an ipv6 load balancer
