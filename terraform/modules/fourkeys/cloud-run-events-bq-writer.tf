data "archive_file" "events_bq_writer_source" {
  type        = "zip"
  source_dir  = "../batch_events"
  output_path = "/tmp/batch_events.zip"
}

module "gcloud_build_batch_events_bq_writer" {
  source                 = "terraform-google-modules/gcloud/google"
  version                = "~> 2.0"
  create_cmd_entrypoint  = "gcloud"
  create_cmd_body        = "builds submit ../batch_events --tag=${local.events_bq_writer_container_url}:${data.archive_file.events_bq_writer_source.output_sha} --project=${var.project_id}"
  destroy_cmd_entrypoint = "gcloud"
  destroy_cmd_body       = "container images delete ${local.events_bq_writer_container_url}:${data.archive_file.events_bq_writer_source.output_sha} --quiet"
}

# resource "google_eventarc_trigger" "primary" {
#     name = "name"
#     location = "northamerica-northeast1"
	
# 	matching_criteria {
#     attribute = "bucket"
#     value     = "off-net-dev-events-archieve-local"
#     }
  
#     matching_criteria {
#         attribute = "type"
#         value = "google.cloud.storage.object.v1.finalized"
#     }
#     destination {
#         cloud_run_service {
#             service = google_cloud_run_service.batch_events_bq_writer.name
#             region = "northamerica-northeast1"
#         }
#     }
# }

resource "google_cloud_run_service" "batch_events_bq_writer" {
  name     = "batch_events_bq_writer"
  project  = var.project_id
  location = "northamerica-northeast1"

  metadata {
    annotations = {
      "client.knative.dev/user-image" = "${local.events_bq_writer_container_url}:${data.archive_file.events_bq_writer_source.output_sha}"
      "run.googleapis.com/ingress"    = "all"
      "autoscaling.knative.dev/minScale" = "1"
    }
  }

  template {
    metadata {
      annotations = {
        "client.knative.dev/user-image"  = "${local.events_bq_writer_container_url}:${data.archive_file.events_bq_writer_source.output_sha}"
        "run.googleapis.com/client-name" = "cloud-console"
      }
    }
    spec {
      containers {
        image = "${local.events_bq_writer_container_url}:${data.archive_file.events_bq_writer_source.output_sha}"
        env {
          name  = "PROJECT_NAME"
          value = var.project_id
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
    module.gcloud_build_batch_events_bq_writer
  ]

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["run.googleapis.com/operation-id"],
    ]
  }

  
}


# resource "google_cloud_run_service_iam_binding" "event_handler_noauth" {
#   location   = "northamerica-northeast1"
#   project    = var.project_id
#   service    = google_cloud_run_service.batch_events_bq_writer.name
#   role       = "roles/run.invoker"
#   members    = ["allUsers"]
#   depends_on = [google_cloud_run_service.batch_events_bq_writer]
# }