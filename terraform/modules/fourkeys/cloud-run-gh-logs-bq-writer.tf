# data "archive_file" "gh_logs_bq_writer_source" {
#   type        = "zip"
#   source_dir  = "../batch_logs"
#   output_path = "/tmp/batch_logs.zip"
# }

# module "gcloud_build_batch_logs_bq_writer" {
#   source                 = "terraform-google-modules/gcloud/google"
#   version                = "~> 2.0"
#   create_cmd_entrypoint  = "gcloud"
#   create_cmd_body        = "builds submit ../batch_logs --tag=${local.gh_logs_bq_writer_container_url}:${data.archive_file.gh_logs_bq_writer_source.output_sha} --project=${var.project_id} --gcs-log-dir=gs://tf-cloud-build-gh-logs"
#   destroy_cmd_entrypoint = "gcloud"
#   destroy_cmd_body       = "container images delete ${local.gh_logs_bq_writer_container_url}:${data.archive_file.gh_logs_bq_writer_source.output_sha} --quiet"
# }


# resource "google_eventarc_trigger" "gh_logs_trigger" {
#     name = "gh-logs-trigger"
#     location = "northamerica-northeast1"
	
# 	matching_criteria {
#     attribute = "bucket"
#     value     = "off-net-dev-gh-audit-log-archieve-local"
#     }
  
#     matching_criteria {
#         attribute = "type"
#         value = "google.cloud.storage.object.v1.finalized"
#     }

#     service_account = "dora-wif@off-net-dev.iam.gserviceaccount.com"
    
#     destination {
#         cloud_run_service {
#             service = google_cloud_run_service.batch_logs_bq_writer.name
#             region = "northamerica-northeast1"
#             path = "/logs"
#         }
#     }
# }

# resource "google_cloud_run_service" "batch_logs_bq_writer" {
#   name     = "batch-logs-bq-writer"
#   project  = var.project_id
#   location = "northamerica-northeast1"

#   template {
#     metadata {
#       annotations = {
#         "client.knative.dev/user-image"        = "${local.gh_logs_bq_writer_container_url}:${data.archive_file.gh_logs_bq_writer_source.output_sha}"
#         "run.googleapis.com/client-name"       = "cloud-console"
#         "autoscaling.knative.dev/minScale"     = "1"
#       }
#     }
#     spec {
#       containers {
#         image = "${local.gh_logs_bq_writer_container_url}:${data.archive_file.gh_logs_bq_writer_source.output_sha}"
#         env {
#           name  = "project-name"
#           value = var.project_id
#         }
#         resources {
#           limits = {
#             memory = "1024Mi"
#           }
#         }
#       }
#       service_account_name = local.compute_engine_service_account
#     }
#   }

#   traffic {
#     percent         = 100
#     latest_revision = true
#   }

#   autogenerate_revision_name = true
#   depends_on = [
#     module.gcloud_build_batch_logs_bq_writer
#   ]

#   lifecycle {
#     ignore_changes = [
#       metadata[0].annotations["run.googleapis.com/operation-id"],
#     ]
#   }
# }

# resource "google_cloud_run_service_iam_binding" "bq_writer_noauth" {
#   location   = "northamerica-northeast1"
#   project    = var.project_id
#   service    = google_cloud_run_service.batch_logs_bq_writer.name
#   role       = "roles/run.invoker"
#   members    = ["allUsers"]
#   depends_on = [google_cloud_run_service.batch_logs_bq_writer]
# }