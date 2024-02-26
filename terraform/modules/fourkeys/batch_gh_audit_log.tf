data "archive_file" "batch_gh_audit_log_source" {
  type        = "zip"
  source_dir  = "../batch_gh_audit_log"
  output_path = "/tmp/batch_gh_audit_log.zip"
}

resource "google_storage_bucket_object" "batch_gh_audit_log_zip" {
  source       = data.archive_file.batch_gh_audit_log_source.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.batch_gh_audit_log_source.output_md5}.zip"
  bucket = google_storage_bucket.batch_gh_log_function_bucket.name
}

# data "google_storage_project_service_account" "gcs_account" {}

# resource "google_project_iam_member" "gcs-pubsub-publishing" {
#   project = var.project_id
#   role    = "roles/pubsub.publisher"
#   member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
# }

# resource "google_service_account" "gh-audit-log-account" {
#   account_id   = "gh-audit-log-sa"
#   display_name = "GH Audit Log Service Account"
# }

# Permissions on the service account used by the function and Eventarc trigger
# resource "google_project_iam_member" "invoking" {
#   project = var.project_id
#   role    = "roles/run.invoker"
#   member  = "serviceAccount:dora-wif@off-net-dev.iam.gserviceaccount.com"
#   depends_on = [google_project_iam_member.gcs-pubsub-publishing]
# }

resource "google_project_iam_member" "event-receiving" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:dora-wif@off-net-dev.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "artifactregistry-reader" {
  project = var.project_id
  role     = "roles/artifactregistry.reader"
  member   = "serviceAccount:dora-wif@off-net-dev.iam.gserviceaccount.com"
}

resource "google_cloudfunctions2_function" "batch_gh_audit_log_function" {
  depends_on = [
    google_project_iam_member.event-receiving,
    google_project_iam_member.artifactregistry-reader,
  ]

  name    = "batch_gh_audit_log"
  description = "Batch GH Audit Log"
  location = var.region

  build_config {
    runtime = "python310"
    entry_point = "persist_data"

    source {
      storage_source {
        bucket = google_storage_bucket.batch_gh_log_function_bucket.name
        object = google_storage_bucket_object.batch_gh_audit_log_zip.name
      }
    }
  }

  service_config {
    min_instance_count = 0
    max_instance_count = 3000

    available_memory = "1024M"

    ingress_settings = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email = google_service_account.gh-audit-log-account.email
  }

  event_trigger {
    trigger_region = var.region
    event_type = "google.cloud.storage.object.v1.finalized"
    retry_policy = "RETRY_POLICY_RETRY"
    service_account_email = "dora-wif@off-net-dev.iam.gserviceaccount.com"

    event_filters {
      attribute = "bucket"
      value     = "gcs://gh-audit-log-bucket"
    }
  }
}
