resource "google_storage_bucket" "source-bucket" {
  name     = "batch-gh-lo-gcf-source-bucket"
  location = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "object" {
  name   = "batch-gh-log-function-source.zip"
  bucket = google_storage_bucket.source-bucket.name
  source = "../batch_gh_audit_log/function-source.zip"  # Add path to the zipped function source code
}


resource "google_storage_bucket" "trigger-bucket" {
  name     = "batch-gh-log-audit-source-bucket"
  location = var.region
  uniform_bucket_level_access = true
}

# data "google_service_account" "gh-audit-log-account" {
#   account_id = "dora-wif"  # Assuming "dora-wif" is the existing service account ID
# }

# resource "google_project_iam_member" "gcs-pubsub-publishing" {
#   project = var.project_id
#   role    = "roles/pubsub.publisher"
#   member  = "serviceAccount:${data.google_service_account.gh-audit-log-account.email}"
# }

# resource "google_project_iam_member" "invoking" {
#   project = var.project_id
#   role    = "roles/run.invoker"
#   member  = "serviceAccount:${data.google_service_account.gh-audit-log-account.email}"
#   depends_on = [google_project_iam_member.gcs-pubsub-publishing]
# }

# resource "google_project_iam_member" "event-receiving" {
#   project = var.project_id
#   role    = "roles/eventarc.eventReceiver"
#   member  = "serviceAccount:${data.google_service_account.gh-audit-log-account.email}"
#   depends_on = [google_project_iam_member.invoking]
# }


# resource "google_project_iam_member" "artifactregistry-reader" {
#   project = var.project_id
#   role     = "roles/artifactregistry.reader"
#   member   = "serviceAccount:${data.google_service_account.gh-audit-log-account.email}"
#   depends_on = [google_project_iam_member.event-receiving]
# }

resource "google_cloudfunctions2_function" "batch_gh_audit_log_function" {
  name    = "batch_gh_audit_log"
  description = "Batch GH Audit Log"
  location = var.region

  build_config {
    runtime = "python310"
    entry_point = "persist_data"

    source {
      storage_source {
        bucket = google_storage_bucket.source-bucket.name
        object = google_storage_bucket_object.object.name
      }
    }
  }

  service_config {
    min_instance_count = 0
    max_instance_count = 3000

    available_memory = "1024M"

    ingress_settings = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email = "dora-wif@off-net-dev.iam.gserviceaccount.com"
  }

  event_trigger {
    trigger_region = var.region
    event_type = "google.cloud.storage.object.v1.finalized"
    retry_policy = "RETRY_POLICY_RETRY"
    service_account_email = "dora-wif@off-net-dev.iam.gserviceaccount.com"

    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.trigger-bucket.name
    }
  }
}
