#----------------------------------------------------------
# runner service account and permissions
#----------------------------------------------------------

resource "google_service_account" "autopilot-runner" {
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
  member   = "serviceAccount:${google_service_account.autopilot-runner.email}"
}

resource "google_storage_bucket_iam_member" "cache-member" {
  bucket = data.google_storage_bucket.runner_cache.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.autopilot-runner.email}"
}

# Creates an IAM binding between the GSA and KSA service accounts
resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.autopilot-runner.name
  role               = "roles/iam.workloadIdentityUser"
  members            = [
    "serviceAccount:${data.google_container_cluster.cluster.workload_identity_config[0].workload_pool}[${kubernetes_namespace.runner_namespace.id}/${kubernetes_service_account.ksa.metadata[0].name}]"
  ]
}

#----------------------------------------------------------
# gcs bucket for distributed caching with the runners
#-----------------------------------------------------------
data "google_storage_bucket" "runner_cache" {
  name = var.gcs.bucket_name
}

#----------------------------------------------------------
# kubernetes
#----------------------------------------------------------
resource "kubernetes_namespace" "runner_namespace" {
  metadata {
    name = var.runner.namespace
  }
}

resource "kubernetes_service_account" "ksa" {
  metadata {
    namespace   = kubernetes_namespace.runner_namespace.id
    name        = var.runner.service_account_name
    #   This annotation allows the kubernetes service account to act as the google service account via Workload Identity
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.autopilot-runner.email
    }
  }
}

# this role is required for the K8s service account to correctly initialize runner pods
resource "kubernetes_role" "gitlab-runner-admin" {
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
# I decided to go with the template file because the toml requires very
# precise tab indentation and it's too easy to mess up using format in
# this file and then stuff breaks and you don't THINK you changed anything,
# but really it's that you have too many or too few spaces/tabs.  Gross.
data "template_file" "runner_config" {
  template = file("${path.module}/templates/config.tpl")
  vars     = {
    namespace   = kubernetes_namespace.runner_namespace.metadata[0].name
    bucket_name = data.google_storage_bucket.runner_cache.name
  }
}

resource "helm_release" "gitlab-runner" {
  name       = var.runner.name
  repository = "https://charts.gitlab.io"
  chart      = "gitlab-runner"
  version    = var.runner.chart_version
  namespace  = kubernetes_namespace.runner_namespace.id

  set_sensitive {
    name  = "runnerRegistrationToken"
    value = var.runner_registration_token
  }
  force_update = true

  # TODO: the resource limints and requests are still a WIP.  This "works" for most of the jobs I have, but some runner pods
  #       end up waiting a bit.  The resources on the main runner workload MUST be more than are allocated to the runner pods 
  #       in config.toml.
  values = [
    yamlencode({
      image = {
        tag = var.gitlab_version
      }
      gitlabUrl = var.gitlab_url
      logLevel = "info"
      logFormat = "json"
      rbac = {
        serviceAccountName = kubernetes_service_account.ksa.metadata[0].name
      }
      resources = {
        limits = {
          cpu = "1000m"
          memory = "1024Mi"
        }
        requests = {
          cpu = "500m"
          memory = "512Mi"
        }
      }
      podSecurityPolicy = {
        resourceNames = [var.runner.name]
      }
      metrics = {
        enabled = true
      }
      runners = {
        config = data.template_file.runner_config.rendered
        executor = "kubernetes"
        locked = false
        name = var.runner.name
        runUntagged = true
      }
    })
  ]
}
