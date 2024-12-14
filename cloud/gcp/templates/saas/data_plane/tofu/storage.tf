resource "google_kms_key_ring" "keyring" {
  name     = "civiform-kms-tenant-${var.tenant_id}"
  location = var.region
}

resource "google_kms_crypto_key" "storage_key" {
  name            = "civiform-gcs-key-tenant-${var.tenant_id}"
  key_ring        = google_kms_key_ring.keyring.id
  rotation_period = "604800s" // 7 days

  lifecycle {
    prevent_destroy = false
  }
}

# Invoking its name brings it into existence
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account
data "google_storage_project_service_account" "gcs_account" {}

locals {
  bucket_name_prefix = "tenant-${var.tenant_id}"
}

resource "google_kms_crypto_key_iam_binding" "kms_binding" {
  crypto_key_id = google_kms_crypto_key.storage_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members       = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

resource "google_storage_bucket" "applicant_files" {
  name          = "${local.bucket_name_prefix}-applicant-files"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.storage_key.id
  }

  depends_on = [
    google_kms_crypto_key_iam_binding.kms_binding
  ]
}

resource "google_storage_bucket_iam_binding" "object_user_binding" {
  bucket  = google_storage_bucket.applicant_files.name
  role    = "roles/storage.objectUser"
  members = ["serviceAccount:${google_service_account.civiform_gsa.email}"]

  condition {
    title       = "Tenant-scoped access"
    description = "Tenant service accounts only permitted access to their own buckets"
    expression  = <<EOT
resource.type == 'storage.googleapis.com/Object' &&
resource.name.startsWith('projects/_/buckets/${local.bucket_name_prefix}')
EOT
  }
}

# Needed for generating signed URLs for end-users
# https://cloud.google.com/storage/docs/access-control/signed-urls
# https://cloud.google.com/storage/docs/access-control/signing-urls-with-helpers#required-roles
# "If you use a service account attached to a compute instance for authentication,
# the service account must have this role to impersonate itself and you must modify commands to
# impersonate the service account used to sign the URL."
resource "google_service_account_iam_binding" "token_creator_binding" {
  service_account_id = google_service_account.civiform_gsa.name
  role               = "roles/iam.serviceAccountTokenCreator"

  members = ["serviceAccount:${google_service_account.civiform_gsa.email}"]

  condition {
    title       = "Tenant-scoped access"
    description = "Tenant service accounts only permitted access to their own buckets"
    expression  = <<EOT
resource.type == 'storage.googleapis.com/Bucket' &&
resource.name.startsWith('projects/_/buckets/${local.bucket_name_prefix}')
EOT
  }
}
