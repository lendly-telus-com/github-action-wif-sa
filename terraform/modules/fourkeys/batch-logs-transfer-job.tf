data "google_storage_transfer_project_service_account" "logs" {
  project = var.project_id
}

data "google_storage_bucket" "gh_audit_log_station_local" {
  name          = "off-net-dev-gh-audit-log-station-local"  
}

data "google_storage_bucket" "gh_audit_log_archieve_local" {
  name          = "off-net-dev-gh-audit-log-archieve-local"  
}

resource "google_storage_bucket_iam_member" "source_bucket_access_logs" {
  bucket = "off-net-dev-gh-audit-log-station-local"
  role   = "roles/storage.admin"
  member = "serviceAccount:project-541105984323@storage-transfer-service.iam.gserviceaccount.com"
}

resource "google_storage_bucket_iam_member" "destination_bucket_access_logs" {
  bucket = "off-net-dev-gh-audit-log-archieve-local"
  role   = "roles/storage.admin"
  member = "serviceAccount:project-541105984323@storage-transfer-service.iam.gserviceaccount.com"
}

resource "google_storage_transfer_job" "batch_logs_transfer_job" {
  description = "This will transfer GitHub LOGS in archive bucket every hour"
  project     = var.project_id

  schedule {
    schedule_start_date {
      year  = 2024
      month = 2
      day   = 21
    }

    repeat_interval = "3600s" # Every hour
  }

  transfer_spec {
    gcs_data_source {
      bucket_name = google_storage_bucket.gh_audit_log_station_local.name
      path        = "fourkeys/audit-logs/"
    }
    transfer_options {
      delete_objects_from_source_after_transfer = true
      overwrite_objects_already_existing_in_sink = true
    }

    gcs_data_sink {
      bucket_name = google_storage_bucket.gh_audit_log_archieve_local.name
    }
  }

  depends_on = [google_storage_bucket_iam_member.source_bucket_access_logs,google_storage_bucket_iam_member.destination_bucket_access_logs]
}




