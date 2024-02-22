data "archive_file" "demo" {
  type        = "zip"
  source_dir  = "../batch_logs"
  output_path = "/tmp/batch_logs.zip"
}

module "test_artifact_registry_url_demo" {
  source                 = "terraform-google-modules/gcloud/google"
  version                = "~> 2.0"
  create_cmd_entrypoint  = "gcloud"
  create_cmd_body        = "builds submit ../batch_logs --tag=${local.test_artifact_registry_url}:${data.archive_file.demo.output_sha} --project=${var.project_id} --gcs-log-dir=gs://tf-cloud-build-gh-logs"
  destroy_cmd_entrypoint = "gcloud"
  destroy_cmd_body       = "container images delete ${local.test_artifact_registry_url}:${data.archive_file.demo.output_sha} --quiet"
}


resource "google_eventarc_trigger" "gh_logs_trigger_demo" {
    name = "gh-logs-trigger-demo"
    location = "northamerica-northeast1"
	
	matching_criteria {
    attribute = "bucket"
    value     = "off-net-dev-gh-audit-log-archieve-local"
    }
  
    matching_criteria {
        attribute = "type"
        value = "google.cloud.storage.object.v1.finalized"
    }

    service_account = "dora-wif@off-net-dev.iam.gserviceaccount.com"
    
    destination {
        cloud_run_service {
            service = google_cloud_run_service.batch_logs_bq_writer_demo.name
            region = "northamerica-northeast1"
            path = "/logs"
        }
    }
}

resource "google_cloud_run_service" "batch_logs_bq_writer_demo" {
  name     = "batch-logs-bq-writer-demo"
  project  = var.project_id
  location = "northamerica-northeast1"

  template {
    metadata {
      annotations = {
        "client.knative.dev/user-image"        = "${local.test_artifact_registry_url}:${data.archive_file.demo.output_sha}"
        "run.googleapis.com/client-name"       = "cloud-console"
        "autoscaling.knative.dev/minScale"     = "1"
      }
    }
    spec {
      containers {
        image = "${local.test_artifact_registry_url}:${data.archive_file.demo.output_sha}"
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
    module.test_artifact_registry_url_demo
  ]

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["run.googleapis.com/operation-id"],
    ]
  }
}

