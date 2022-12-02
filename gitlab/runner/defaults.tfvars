gitlab_url             = <GITLAB_URL>
google_service_account = {
  id           = <GSA_NAME>
  display_name = <GSA_DISPLAY_NAME>
}
gcp = {
  project = <GCP_PROJECT>
  region  = <GCP_REGION>
  zone    = <GCP_ZONE>
}
node_pool = {
  name           = <NODE_POOL_NAME>
  machine_type   = <MACHINE_TYPE>
  image_type     = "COS_CONTAINERD"
  min_node_count = <MIN>
  max_node_count = <MAX>
}
cluster = {
  name     = <K8S_CLUSTER_NAME>
  location = <K8S_LOCATION>
}
gcs = {
  bucket_name = <RUNNER_CACHE_BUCKET_NAME>
}
runner = {
  name = "gitlab-runner"
  namespace = "gitlab-runner"
  service_account_name = <KSA_NAME>
  chart_version = "0.47.0"
  image = "gitlab/gitlab-runner:<RUNNER_IMAGE_TAG>"
}
