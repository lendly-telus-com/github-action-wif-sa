resource "google_bigquery_dataset" "dataset" {
  dataset_id    = "local_4keys"
  friendly_name = "local_4keys"
  description   = "This is a test description"
  location      = "northamerica-northeast1"
}

resource "google_bigquery_table" "batch_events" {
  dataset_id          = google_bigquery_dataset.dataset.dataset_id
  table_id            = "batch_events"
  deletion_protection = false
  schema              = (file("${path.module}/schemas/batch-events.json"))

  time_partitioning {
    type  = "DAY"
    field = "ingestion_time"
  }
}

resource "google_bigquery_table" "batch_logs" {
  dataset_id          = google_bigquery_dataset.dataset.dataset_id
  table_id            = "batch_logs"
  deletion_protection = false
  schema              = file("${path.module}/schemas/batch-logs.json")

  time_partitioning {
    type  = "DAY"
    field = "ingestion_time"
  }
}