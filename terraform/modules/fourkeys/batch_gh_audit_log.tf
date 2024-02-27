resource "google_storage_bucket" "function_bucket" {
  name                        = "${var.project_id}-function-source"
  location                    = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "trigger-bucket" {
  name     = "batch-gh-log-audit-source-bucket"
  location = var.region
  uniform_bucket_level_access = true
}

data "archive_file" "gh_log_cf" {
  type        = "zip"
  source_dir  = "../batch_gh_audit_log"
  output_path = "/tmp/batch_gh_audit_log.zip"
}

resource "google_storage_bucket_object" "load_gh_audit_log_zip" {
  source       = data.archive_file.gh_log_cf.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.gh_log_cf.output_md5}.zip"
  bucket = google_storage_bucket.function_bucket.name
}

resource "google_cloudfunctions2_function" "batch_gh_audit_log_function" {
  name    = "batch_gh_audit_log"
  description = "Batch GH Audit Log"
  location = var.region
  

  build_config {
    runtime = "python310"
    entry_point = "persist_data"

    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket.name
        object = google_storage_bucket_object.load_gh_audit_log_zip.name
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
