data "google_storage_transfer_project_service_account" "events" {
  project = var.project_id
}

resource "google_storage_transfer_job" "batch_events_transfer_job" {
  description = "This will transfer GitHub events to the archive bucket every hour"
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
      bucket_name = "off-net-dev-events-station-local"
      path        = "webhook-event/github/"
    }

    gcs_data_sink {
      bucket_name = "off-net-dev-events-archive-local"
    }
  }
}

resource "google_storage_bucket_iam_member" "source_bucket_access_events" {
  bucket = "off-net-dev-events-station-local"
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:dora-wif@off-net-dev.iam.gserviceaccount.com"
}

resource "google_storage_bucket_iam_member" "destination_bucket_access_events" {
  bucket = "off-net-dev-events-archieve-local"
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:dora-wif@off-net-dev.iam.gserviceaccount.com"
}
