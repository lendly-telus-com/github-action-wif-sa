data "archive_file" "batch_events_handler_source" {
  type        = "zip"
  source_dir  = "../batch_events_handler"
  output_path = "/tmp/batch_events_handler.zip"
}

module "gcloud_build_batch_events_handler" {
  source                 = "terraform-google-modules/gcloud/google"
  version                = "~> 2.0"
  create_cmd_entrypoint  = "gcloud"
  create_cmd_body        = "builds submit ../batch_events_handler --tag=${local.batch_events_handler_gar_url}:${data.archive_file.batch_events_handler_source.output_sha} --project=${var.project_id} --gcs-log-dir=gs://tf-batch-events-hanlder-logs"
  destroy_cmd_entrypoint = "gcloud"
  destroy_cmd_body       = "container images delete ${local.batch_events_handler_gar_url}:${data.archive_file.batch_events_handler_source.output_sha} --quiet"
}

resource "google_cloud_run_service" "batch_events_handler_reload" {
  name     = "batch-events-handler-reload"
  project  = var.project_id
  location = "us-central1"

  template {
    metadata {
      annotations = {
        "client.knative.dev/user-image"        = "${local.batch_events_handler_gar_url}:${data.archive_file.batch_events_handler_source.output_sha}"
        "run.googleapis.com/client-name"       = "cloud-console"
        "autoscaling.knative.dev/minScale"     = "1"
      }      
    }
    spec {
      containers {
        image = "${local.batch_events_handler_gar_url}:${data.archive_file.batch_events_handler_source.output_sha}"
        env {
          name  = "project-name"
          value = var.project_id
        }
        resources {
          limits = {
            memory = "1024Mi"
          }
        }
      }
      service_account_name = local.compute_engine_service_account
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true
  depends_on = [
    module.gcloud_build_batch_events_handler
  ]

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["run.googleapis.com/operation-id"],
    ]
  }
}

resource "google_cloud_run_service_iam_binding" "batch_events_handler_noauth" {
   location   = "us-central1"
   project    = var.project_id
   service    = google_cloud_run_service.batch_events_handler_reload.name
   role       = "roles/run.invoker"
   members    = ["allUsers"]
   depends_on = [google_cloud_run_service.batch_events_handler_reload]
}


