data "google_project" "project" {
  project_id = var.project_id
}

locals {
  compute_engine_service_account     = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"
  cloudbuild_service_account         = "${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
  event_handler_container_url        = format("gcr.io/%s/event-handler", var.project_id)
  organization_fetcher_container_url = format("gcr.io/%s/organization_fetcher", var.project_id)
  events_bq_writer_container_url     = format("gcr.io/%s/events_bq_writer", var.project_id)
}