data "archive_file" "load_gh_audit_log_source" {
  type        = "zip"
  source_dir  = "../batch_gh_audit_log"
  output_path = "/tmp/batch_gh_audit_log.zip"
}

resource "google_storage_bucket" "function_bucket" {
  name                        = "${var.project_id}-function-gh-log-source"
  location                    = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "dump_logs" {
  name                        = "${var.project_id}-batch-gh-audit-logs"
  location                    = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "load_gh_audit_log_zip" {
  source       = data.archive_file.load_gh_audit_log_source.output_path
  content_type = "application/zip"
  name   = "src-${data.archive_file.load_gh_audit_log_source.output_md5}.zip"
  bucket = google_storage_bucket.function_bucket.name
}

resource "google_cloudfunctions2_function" "function" {
  name = "batch-gh-log-handler"
  location = var.region
  description = "a new function"

  build_config {
    runtime = "python310"
    entry_point = "persist_data" 
    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket.name
        object = google_storage_bucket_object.load_gh_audit_log_zip.name
      }
    }
  }

  service_config {
    max_instance_count  = 1
    available_memory    = "1024M"
    timeout_seconds     = 60
  }
}

resource "google_eventarc_trigger" "cf_gh_log_trigger" {
    name = "cf-gh-log-trigger"
    location = var.region
	
	matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.dump_logs.name
    }
  
    matching_criteria {
        attribute = "type"
        value = "google.cloud.storage.object.v1.finalized"
    }

    service_account = local.compute_engine_service_account
    
    destination {
        cloud_run_service {
            service = google_cloudfunctions2_function.function.name
            region = var.region
            path = "/persist_data"
        }
    }
}

