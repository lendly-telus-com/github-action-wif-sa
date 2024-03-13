resource "google_service_account" "unleash_sa" {
  account_id   = "unleash-sa"
  display_name = "Unleash Service Account"
  project      = "off-net-dev"
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

