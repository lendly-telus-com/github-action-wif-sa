resource "google_service_account" "unleash_sa" {
  account_id   = "unleash-sa"
  display_name = "Unleash Service Account"
  project      = "off-net-dev"
}

resource "google_project_iam_binding" "sa_binding" {
  project = "off-net-dev"

  bindings = [
    {
      role    = "roles/iam.workloadIdentityUser"
      members = [
        "serviceAccount:${google_service_account.unleash_sa.email}"
      ]
    },
    {
      role    = "roles/artifactregistry.writer"
      members = [
        "serviceAccount:${google_service_account.unleash_sa.email}"
      ]
    }
  ]
}


resource "google_iam_workforce_pool" "pool" {
  workforce_pool_id = "example-pool"
  parent            = "organizations/off-net-dev"
  location          = "global"
}

resource "google_iam_workforce_pool_provider" "provider" {
  workforce_pool_id   = google_iam_workforce_pool.pool.workforce_pool_id
  location            = google_iam_workforce_pool.pool.location
  provider_id         = "unleash-provider"
  attribute_mapping   = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.aud"        = "assertion.aud"
    "attribute.repository" = "assertion.repository"
  }
  oidc {
    issuer_uri        = "https://token.actions.githubusercontent.com"
    client_id         = "client-id"
    client_secret {
      value {
        plain_text = "client-secret"
      }
    }
    web_sso_config {
      response_type             = "CODE"
      assertion_claims_behavior = "MERGE_USER_INFO_OVER_ID_TOKEN_CLAIMS"
      additional_scopes         = ["groups", "roles"]
    }
  }
  display_name        = "oidc name"
  description         = "A sample OIDC workforce pool provider."
  disabled            = false
  attribute_condition = "true"
}