variable "gitlab_url" {
  type        = string
  description = "The URL of the GitLab server to register the runner against."
  sensitive   = true
}

# you can set this in your gitlab CI job in variables like:
#     TF_VAR_gitlab_version: ${CI_SERVER_VERSION}
# that way it's always up to date (when you run terraform); probably should re-apply after gitlab upgrades
variable "gitlab_version" {
  type = string
  description = "The semantic version (maj, min, patch) of your Gitlab Omnibus installation"
}

# kept separate from the runner configs because this should not be stored in a static file. Prefer to use secrets management.
variable "runner_registration_token" {
  type        = string
  description = "The token used to register a CI runner with Gitlab."
  sensitive   = true
}

variable "google_service_account" {
  description = "Values for the GSA the runner will use via workload identity (name, display name, iam project roles)"
  type        = object({
    id                = string
    display_name      = string
    project_iam_roles = list(string)
  })
  default = ({
    id                = "gitlab-autopilot-runner"
    display_name      = "Gitlab Autopilot Runner"
    project_iam_roles = [
      # "base level" roles for the service account (https://cloud.google.com/kubernetes-engine/docs/how-to/access-scopes#service_account)
      "roles/monitoring.metricWriter",
      "roles/monitoring.viewer",
      "roles/logging.logWriter",
      #  This allows the service account to get a temporary access token to the resources it's granted permission to (ie. the storage bucket)
      "roles/iam.serviceAccountTokenCreator",
      #  This allows the service account to actually generate the URLs needed to interact with the GCS bucket
      "roles/storage.objectCreator"
    ]
  })
}

variable "gcp" {
  description = "Values to use for GCP (project name, region, zone)"
  type        = object({
    project = string
    region  = string
    zone    = string
  })
}

variable "cluster" {
  description = "Values to use to connect to the cluster the runner will live in (name, location)"
  type        = object({
    name     = string
    location = string
  })
}

variable "gcs" {
  description = "Values for a GCS storage bucket the runner will use for caching"
  type        = object({
    bucket_name = string
  })
}

variable "runner" {
  description = "Values to use to configure the gitlab runner"
  type        = object({
    name                 = string
    namespace            = string
    service_account_name = string
    chart_version        = string
  })
  default = ({
    name                 = "autopilot-runner"
    namespace            = "gitlab-runner"
    service_account_name = "gitlab-autopilot-runner"
    chart_version        = "0.47.0"
  })
}
