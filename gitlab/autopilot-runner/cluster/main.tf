locals {
  gcp_project        = "my-project
  gcp_region         = "my-region"
  gcp_zone           = "my-zone"
  cluster_name       = "autopilot-runner"
}


terraform {
  backend "gcs" {
    bucket = "my-terraform-state"
    prefix = "gitlab/autopilot/cluster"
  }

  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "google" {
  # these values become the default if not overridden elsewhere.
  project     = local.gcp_project
  region      = local.gcp_region
  zone        = local.gcp_zone
}

#----------------------------------------------------------
# GKE cluster
# https://registry.terraform.io/providers/hashicorp/google/4.20.0/docs/resources/container_cluster
#----------------------------------------------------------
resource "google_container_cluster" "primary" {
  provider = google
  name     = local.cluster_name
  # Autopilot clusters *must* be regional.
  location = local.gcp_region

  # Enabling Autopilot for this cluster
  enable_autopilot = true
  resource_labels = {
    "terraform-managed"   = true
  }

  initial_node_count       = 1

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    # there's an error in the google provider starting in version 4.4.1(?) that breaks creating an autopilot cluster
    # adding this empty block fixes it for now?  The bug was reported in 12/2021...still awaiting fix:
    # https://github.com/hashicorp/terraform-provider-google/issues/10782
  }

  maintenance_policy {
    recurring_window {
      # Allow maintenance from 2am to 7am PT, any day of the week
      start_time = "2022-12-13T10:00:00Z"
      end_time   = "2022-12-13T15:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU"
    }
  }
}
