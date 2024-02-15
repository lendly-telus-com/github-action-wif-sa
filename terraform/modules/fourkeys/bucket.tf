resource "google_storage_bucket" "events_station_local" {
  name                        = "${var.project_id}-events-station-local"
  location                    = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "events_archieve_local" {
  name                        = "${var.project_id}-events-archieve-local"
  location                    = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "gh_audit_log_station_local" {
  name                        = "${var.project_id}-gh-audit-log-station-local"
  location                    = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "gh_audit_log_archieve_local" {
  name                        = "${var.project_id}-gh-audit-log-archieve-local"
  location                    = var.region
  uniform_bucket_level_access = true
}