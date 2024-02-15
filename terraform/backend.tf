terraform {
  backend "gcs" {
    bucket = "offnet-tf-state"
    prefix = "terraform/state"
  }
}