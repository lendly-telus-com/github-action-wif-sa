data "archive_file" "gh_log_handler_2" {
  type        = "zip"
  source_dir  = "../batch_gh_audit_log"
  output_path = "/tmp/batch_gh_audit_log.zip"
}

resource "google_storage_bucket" "trigger_bucket" {
  name     = "batch-gh-audit-logs"
  location = var.region
  uniform_bucket_level_access = true
}

module "gh_log_handler_registry_url" {
  source                 = "terraform-google-modules/gcloud/google"
  version                = "~> 2.0"
  create_cmd_entrypoint  = "gcloud"
  create_cmd_body        = "builds submit ../batch_gh_audit_log --tag=${local.gh_log_handler_url_2}:${data.archive_file.gh_log_handler_2.output_sha} --project=${var.project_id} --gcs-log-dir=gs://tf-cloud-build-gh-logs-handler"
  destroy_cmd_entrypoint = "gcloud"
  destroy_cmd_body       = "container images delete ${local.gh_log_handler_url_2}:${data.archive_file.gh_log_handler_2.output_sha} --quiet"
}


resource "google_eventarc_trigger" "gh_logs_handler" {
    name = "gh-logs-handler-eventrac"
    location = var.region
	
	matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.trigger_bucket.name
    }
  
    matching_criteria {
        attribute = "type"
        value = "google.cloud.storage.object.v1.finalized"
    }

    service_account = local.compute_engine_service_account
    
    destination {
        cloud_run_service {
            service = google_cloud_run_service.batch_logs_handler.name
            region = var.region
            path = "/persist_data"
        }
    }
}

resource "google_cloud_run_service" "batch_logs_handler" {
  name     = "batch-logs-handler"
  project  = var.project_id
  location = var.region

  template {
    metadata {
      annotations = {
        "client.knative.dev/user-image"        = "${local.gh_log_handler_url_2}:${data.archive_file.gh_log_handler.output_sha}"
        "run.googleapis.com/client-name"       = "cloud-console"
        "autoscaling.knative.dev/minScale"     = "1"
      }
    }
    spec {
      containers {
        image = "${local.gh_log_handler_url_2}:${data.archive_file.gh_log_handler.output_sha}"
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
    module.gh_log_handler_registry_url
  ]

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["run.googleapis.com/operation-id"],
    ]
  }
}

