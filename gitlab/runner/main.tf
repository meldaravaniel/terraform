#----------------------------------------------------------
# runner service account and permissions
#----------------------------------------------------------

resource "google_service_account" "runner" {
  provider     = google
  account_id   = var.google_service_account.id
  display_name = var.google_service_account.display_name
}

# NOTE: DO NOT USE Binding or Policy; that may affect the other environments using this role.
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam#google_project_iam_member
resource "google_project_iam_member" "runner" {
  count    = length(var.google_service_account.project_iam_roles)
  provider = google
  project  = var.gcp.project
  role     = element(var.google_service_account.project_iam_roles, count.index)
  member   = "serviceAccount:${google_service_account.runner.email}"
}

resource "google_storage_bucket_iam_member" "cache_member" {
  bucket = data.google_storage_bucket.runner_cache.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.runner.email}"
}

# Creates an IAM binding between the GSA and KSA service accounts
resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.runner.name
  role               = "roles/iam.workloadIdentityUser"
  members            = [
    "serviceAccount:${var.gcp.project}.svc.id.goog[${kubernetes_namespace.runner_namespace.id}/${kubernetes_service_account.ksa.metadata[0].name}]"
  ]
}

#----------------------------------------------------------
# node pool
#----------------------------------------------------------
resource "google_container_node_pool" "runner" {
  name    = var.node_pool.name
  cluster = data.google_container_cluster.runner_cluster.name

  node_config {
    preemptible  = true
    machine_type = var.node_pool.machine_type
    image_type   = var.node_pool.image_type

    service_account = google_service_account.runner.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      "terraform-managed" = true
    }
  }

  autoscaling {
    max_node_count = var.node_pool.max_node_count
    min_node_count = var.node_pool.min_node_count
  }
}

#----------------------------------------------------------
# gcs bucket for distributed caching with the runners (assumes it's created already, but you can use resource instead, to create it)
#-----------------------------------------------------------
data "google_storage_bucket" "runner_cache" {
  name = var.gcs.bucket_name
}

#----------------------------------------------------------
# kubernetes
#----------------------------------------------------------
resource "kubernetes_namespace" "runner_namespace" {
  #  this could be created in the helm chart...
  metadata {
    name = var.runner.namespace
  }

  # establish an explicit relationship with the node pool
  # so that terraform will destroy resources in the right order
  depends_on = [
    google_container_node_pool.runner
  ]
}

resource "kubernetes_service_account" "ksa" {
  #  this could be created in the helm chart...maybe. but would require re-kajiggering of the rersource.google_service_account_iam_binding.workload_identity_binding
  metadata {
    namespace   = kubernetes_namespace.runner_namespace.id
    name        = var.runner.service_account_name
    #   This annotation allows the kubernetes service account to act as the google service account via Workload Identity
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.runner.email
    }
  }
}

# this role is required for the K8s service account to correctly initialize runner pods
resource "kubernetes_role" "gitlab-runner-admin" {
  # this could be created in the helm chart...
  metadata {
    name      = "gitlab-runner-admin"
    namespace = kubernetes_namespace.runner_namespace.id
    labels    = {
      terraformManaged = true
    }
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["list", "get", "watch", "create", "delete"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["create"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/attach"]
    verbs      = ["list", "get", "create", "delete", "update"]
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["list", "get", "create", "delete", "update"]
  }
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["list", "get", "create", "delete", "update"]
  }
}

resource "kubernetes_role_binding" "ksa-gitlab-runner-admin-binding" {
  #  this could be created in the helm chart...
  metadata {
    name      = "gitlab-ci-secrets-role-binding"
    namespace = kubernetes_namespace.runner_namespace.id
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.gitlab-runner-admin.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.ksa.metadata[0].name
    namespace = kubernetes_namespace.runner_namespace.id
  }
}

#----------------------------------------------------------
# gitlab runner (helm based configuration)
# https://docs.gitlab.com/runner/install/kubernetes.html
#----------------------------------------------------------

# The config.toml *can* be directly included in the helm resource below, 
# but I opted to not because the tabs MUST stay correct and it's too easy 
# to mess them up here.
# If you need more stuff in the toml, edit the file, include any vars you 
# need (surrounding them in ${}) and add them to the vars in this block.
# I've chosen to preface the vars with "TF_" just so they're easier to spot
# in the files.
# Orrrr you can just choose to not have vars and put them in the file, but
# then you have to maintain them in multiple places. Sad.
data "template_file" "runner_config" {
  template = file("${path.module}/templates/config.tpl")
  vars     = {
    TF_namespace   = kubernetes_namespace.runner_namespace.metadata[0].name
    TF_bucket_name = data.google_storage_bucket.runner_cache.name
  }
}

# You *can* use terraform's yamlencode method in the helm resource below if you want.
# works the same as the runner config resource above.  Add more vars if you want, or
# just configure the more 'static' things directly in the file.  NGL, I'm kind of using
# these template files because I think they're fun.  But also so that this file is 
# easier to look at.
data "template_file" "helm_chart_values" {
  template = file("${path.module}/templates/values.tpl")
  vars = {
    TF_gitlab_url = var.gitlab_url
    TF_kubernetes_service_account = kubernetes_service_account.ksa.metadata[0].name
    TF_runner_name = var.runner.name
    TF_runner_config = data.template_file.runner_config.rendered
  }
}

resource "helm_release" "gitlab-runner" {
  name       = var.runner.name
  repository = "https://charts.gitlab.io"
  chart      = "gitlab-runner"
  version    = var.runner.chart_version
  namespace  = kubernetes_namespace.runner_namespace.id

  # This is not set using the template_files so that it does not get printed
  # in Terraform's plan/apply output.
  set_sensitive {
    name  = "runnerRegistrationToken"
    value = var.runner_registration_token
  }
  
  # Terraform doesn't always re-kick the Helm provider...so just force it to.
  force_update = true
  values       = data.template_file.runner_config.rendered
}
