data "archive_file" "gh_log_cf" {
  type        = "zip"
  source_dir  = "../batch_gh_audit_log"
  output_path = "/tmp/batch_gh_audit_log.zip"
}

module "gcloud_build_batch_gh_log_cf" {
  source                 = "terraform-google-modules/gcloud/google"
  version                = "~> 2.0"
  create_cmd_entrypoint  = "gcloud"
  create_cmd_body        = "builds submit ../batch_gh_audit_log --tag=${local.gh_log_cf_url}:${data.archive_file.gh_log_cf.output_sha} --project=${var.project_id} --gcs-log-dir=gs://tf-cloud-build-logs"
  destroy_cmd_entrypoint = "gcloud"
  destroy_cmd_body       = "container images delete ${local.gh_log_cf_url}:${data.archive_file.gh_log_cf.output_sha} --quiet"
}



resource "google_storage_bucket" "trigger-bucket" {
  name     = "batch-gh-log-audit-source-bucket"
  location = var.region
  uniform_bucket_level_access = true
}


resource "google_cloudfunctions2_function" "batch_gh_audit_log_function" {
  name    = "batch_gh_audit_log"
  description = "Batch GH Audit Log"
  location = var.region
  depends_on  = [module.gcloud_build_batch_gh_log_cf]

  build_config {
    runtime = "python310"
    entry_point = "persist_data"
  }

  service_config {
    min_instance_count = 0
    max_instance_count = 3000

    available_memory = "1024M"

    ingress_settings = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email = "dora-wif@off-net-dev.iam.gserviceaccount.com"
  }

  event_trigger {
    trigger_region = var.region
    event_type = "google.cloud.storage.object.v1.finalized"
    retry_policy = "RETRY_POLICY_RETRY"
    service_account_email = "dora-wif@off-net-dev.iam.gserviceaccount.com"

    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.trigger-bucket.name
    }
  }
}
