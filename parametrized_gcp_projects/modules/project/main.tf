resource "google_project" "project" {
  auto_create_network = false
  name                = var.project_name
  project_id          = var.project.id
  folder_id           = var.folder_id
  billing_account     = var.billing_account_id
}

resource "google_project_service" "gcp_services" {
  for_each = toset(var.enabled_gcp_services)
  project  = google_project.project.project_id
  service  = "${each.key}.googleapis.com"
}

# DEPRIVILEGE the default service accounts so that it has minimal permissions
# but DO NOT DELETE them, becuase they can't be restored past 30 days, and they're
# not re-creatable by us.  Google creates them.
resource "google_project_default_service_accounts" "project" {
  project = google_project.project.project_id
  action  = "DEPRIVILEGE"
}

resource "google_compute_network" "network" {
  name                     = var.project.network.name
  project                  = google_project.project.project_id
  auto_create_subnetworks  = false
  enable_ula_internal_ipv6 = false
  mtu                      = 1300
  routing_mode             = "REGIONAL"
}

resource "google_compute_subnetwork" "serverless" {
  name          = var.project.network.serverless_subnet
  network       = google_compute_network.network.id
  project       = google_project.project.project_id
  ip_cidr_range = local.serverless_range
  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
  }
  private_ip_google_access   = true
  private_ipv6_google_access = "DISABLE_GOOGLE_ACCESS"
  purpose                    = "PRIVATE"
  region                     = var.project.region
  stack_type                 = "IPV4_ONLY"
  secondary_ip_range         = []
}

resource "google_compute_subnetwork" "services_pods" {
  name          = var.project.network.services_subnet
  network       = google_compute_network.network.id
  project       = google_project.project.project_id
  ip_cidr_range = local.services_pods_range
  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
  }
  private_ip_google_access   = true
  private_ipv6_google_access = "DISABLE_GOOGLE_ACCESS"
  purpose                    = "PRIVATE"
  region                     = var.project.region
  stack_type                 = "IPV4_ONLY"
  secondary_ip_range = [
    {
      range_name    = "${var.project.short_id}-services"
      ip_cidr_range = local.services_secondary_range
      }, {
      range_name    = "${var.project.short_id}-pods"
      ip_cidr_range = local.pods_secondary_range
    }
  ]
}

# https://cloud.google.com/sql/docs/postgres/configure-private-services-access#terraform
# The connection itself is configured in the database project because it can't have 'project' specified in the TF resource (yet)
resource "google_compute_global_address" "private_ip_alloc" {
  project       = google_project.project.project_id
  name          = "private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.network.id
}
