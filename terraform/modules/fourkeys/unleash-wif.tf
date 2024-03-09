resource "google_service_account" "unleash_sa" {
  account_id   = "unleash-sa"
  display_name = "Unleash Service Account"
  project      = "off-net-dev"
}
# TODO
resource "google_iam_workload_identity_pool" "pool" {
  workload_identity_pool_id = "unleash-pool"
}

resource "google_iam_workload_identity_pool_provider" "provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "unleash-provider"
  attribute_mapping                  = {
    "google.subject" = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.aud"        = "assertion.aud"
    "attribute.repository" = "assertion.repository"
  }
  oidc {
    issuer_uri        = "https://token.actions.githubusercontent.com"
  }
}

resource "google_project_iam_member" "unleash_sa_binding" {
  project = "off-net-dev"
  role    = "roles/iam.workloadIdentityUser"
  member  = "principalSet://iam.googleapis.com/projects/541105984323/locations/global/workloadIdentityPools/unleash-pool/attribute.repository/TeamDevEx/unleash-nest"
}

resource "google_project_iam_member" "unleash_sa_binding" {
  project = "off-net-dev"
  role    = "roles/artifactregistry.writer"
  member  = "principalSet://iam.googleapis.com/projects/541105984323/locations/global/workloadIdentityPools/unleash-pool/attribute.repository/TeamDevEx/unleash-nest"
}
