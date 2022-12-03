terraform {
  backend "gcs" {
    bucket      = <TF_STATE_BUCKET>
    prefix      = "gitlab-runner"
  }

  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "google" {
  # these values become the default if not overridden elsewhere.
  project     = var.gcp.project
  region      = var.gcp.region
  zone        = var.gcp.zone
}

# The google_client_config data source fetches a token from the
# Google Authorization server, which expires in 1 hour by default.
data "google_client_config" "default" {}

data "google_container_cluster" "runner_cluster" {
  name     = var.cluster.name
  location = var.cluster.location
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.runner_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.runner_cluster.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.runner_cluster.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.runner_cluster.master_auth[0].cluster_ca_certificate)
  }
}
