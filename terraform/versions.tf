terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>5.0.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~>3.5.1"
    }

    null = {
      source  = "hashicorp/null"
      version = "~>3.2.1"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~>2.4.0"
    }

    external = {
      source  = "hashicorp/external"
      version = "~>2.3.1"
    }
  }

  required_version = ">= 1.5.0"
}