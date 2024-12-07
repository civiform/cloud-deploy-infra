#! /usr/bin/env bash

set -e
set -x

gcloud services enable "cloudkms.googleapis.com"
gcloud services enable "cloudresourcemanager.googleapis.com"
gcloud services enable "compute.googleapis.com"
gcloud services enable "container.googleapis.com"
gcloud services enable "iam.googleapis.com"
gcloud services enable "iamcredentials.googleapis.com"
gcloud services enable "servicenetworking.googleapis.com"
gcloud services enable "sql-component.googleapis.com"
gcloud services enable "sqladmin.googleapis.com"
gcloud services enable "storage-component.googleapis.com"
