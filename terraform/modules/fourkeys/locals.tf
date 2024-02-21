data "google_project" "project" {
  project_id = var.project_id
}

locals {
  # compute_engine_service_account     = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"
  compute_engine_service_account     = "dora-wif@off-net-dev.iam.gserviceaccount.com"
  cloudbuild_service_account         = "${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
  event_handler_container_url        = format("gcr.io/%s/event-handler", var.project_id)
  organization_fetcher_container_url = format("gcr.io/%s/organization_fetcher", var.project_id)
  events_bq_writer_container_url     = format("gcr.io/%s/batch_events", var.project_id)
  gh_logs_bq_writer_container_url    = format("gcr.io/%s/batch_logs", var.project_id)
  test_artifact                      = format("northamerica-northeast1-docker.pkg.dev/off-net-dev/gcf-artifacts/%s/batch_logs", var.project_id)
}