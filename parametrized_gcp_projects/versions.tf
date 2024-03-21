terraform {
  required_version = "~> 1.7"

  backend "gcs" {
    bucket = "${YOUR BUCKET HERE}"
    prefix = "${YOUR PREFIX HERE}"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.16"
    }
  }
}

provider "google" {
  # To run this locally, you can impersonate the uber terraform GSA. 
  # Your account will need Service Account Token Creator permissions on that account.
  # After that, run: 
  # `export GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token /
  # --impersonate-service-account=${uber gsa name}@${uber project id}.iam.gserviceaccount.com)` in the terminal to set
  # the temporary token so that Terraform can use it.
}
