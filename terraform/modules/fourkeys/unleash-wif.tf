resource "google_iam_workforce_pool" "pool" {
  workforce_pool_id = "unleash-pool"
  parent            = "organizations/off-net-dev"
  location          = "global"
}


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