# K8s Gitlab Runner with Workload Identity

Terraform, GCP, Kubernetes executor, Runner Helm Chart, and Cache accessed via Workload Identity GCS Cache

High level instructions on doing this manually [here](https://gitlab.com/amygl/gitlab-runner/-/blob/main/docs/install/kubernetes.md#use-workload-identity-to-impersonate-iam-service-accounts) (awaiting MR by Gitlab team as of 12/2/22).

Also Required:

* a GCP storage bucket
  * unless you want to create it in this module, in which case, convert the "data" resource to a "resource" resource.
* a kubernetes cluster with workload identity enabled
  * you should not make the cluster in the same module as you need to use it because the Kubernetes provider won't be able to access it
  * don't need anything super fancy, eg:
  ```hcl
  locals {
    gcp_project        = <GCP_PROJECT>
    gcp_region         = <REGION>
    gcp_zone           = <ZONE>
    cluster_name       = <K8S_CLUSTER_NAME>
    cluster_location   = <K8S_CLUSTER_LOCATION>
  }
  
  #----------------------------------------------------------
  # GKE cluster
  # https://registry.terraform.io/providers/hashicorp/google/4.20.0/docs/resources/container_cluster
  #----------------------------------------------------------
  resource "google_container_cluster" "primary" {
    provider = google
    name     = local.cluster_name
    location = local.cluster_location

    resource_labels = {
      "terraform-managed"   = true
    }

    # We can't create a cluster with no node pool defined, google won't let us,
    # but we want to only use separately managed node pools.  So we create the
    # smallest possible default node pool and immediately delete it.
    # If you make node pools IN the cluster, you have to rebuild the entire
    # cluster if you want to change them.  Ew.
    remove_default_node_pool = true
    initial_node_count       = 1

    maintenance_policy {
      recurring_window {
        start_time = "2020-01-01T01:00:00Z"
        end_time   = "2020-01-01T14:00:00Z"
        recurrence = "FREQ=WEEKLY;BYDAY=FR,SA"
      }
    }

    release_channel {
      channel = "REGULAR"
    }

    workload_identity_config {
      workload_pool = "${local.gcp_project}.svc.id.goog"
    }
  }
  ```
