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


resource "google_storage_bucket_object" "load_gh_audit_log_zip" {
  source       = data.archive_file.load_gh_audit_log_source.output_path
  content_type = "application/zip"
  name   = "src-${data.archive_file.load_gh_audit_log_source.output_md5}.zip"
  bucket = google_storage_bucket.function_bucket.name
}