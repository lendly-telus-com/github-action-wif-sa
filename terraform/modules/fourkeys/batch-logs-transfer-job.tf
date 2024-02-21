resource "google_storage_transfer_job" "batch_logs_transfer_job" {  
  description = "This will transfer GitHub LOGS in archive bucket every hour"
  project     = "${var.project_id}"

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
      bucket_name = "off-net-dev-gh-audit-log-station-local"
      path        = "fourkeys/audit-logs/"
    }

    gcs_data_sink {
      bucket_name = "off-net-dev-gh-audit-log-archieve-local"
    }
  }
}


