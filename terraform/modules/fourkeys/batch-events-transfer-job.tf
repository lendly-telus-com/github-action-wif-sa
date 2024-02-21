resource "google_storage_transfer_job" "batch_events_transfer_job" {
  name        = "batch-events-transfer-job"
  description = "This will transfer GitHub events in archive bucket every hour"
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
      bucket_name = "off-net-dev-events-station-local"
      path        = "webhook-event/github/"
    }

    gcs_data_sink {
      bucket_name = "off-net-dev-events-archive-local"
    }
  }
}


