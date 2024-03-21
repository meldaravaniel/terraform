data "google_organization" "org" {
  organization = var.org_id
}

data "google_billing_account" "billing" {
  display_name = var.billing_account_name
}

# Create a folder to keep our application projects in
resource "google_folder" "folder" {
  display_name = var.folder_name
  parent       = data.google_organization.org.name
}

locals {
  uber_gsa = "${var.uber_gsa_name}@${var.uber_project_id}.iam.gserviceaccount.com"
}

resource "google_folder_iam_member" "folder_owner" {
  folder = google_folder.folder.id
  role   = "roles/owner"
  member = "serviceAccount:${local.uber_gsa}"
}

# For all projects created in the folder, do not give them a default network
resource "google_org_policy_policy" "skip_default_network_creation" {
  name   = "${google_folder.folder.id}/policies/compute.skipDefaultNetworkCreation"
  parent = google_folder.folder.id

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# For all projects created in the folder, do not grant the default service account any IAM permissions
resource "google_org_policy_policy" "prevent_default_gsa_grants" {
  name   = "${google_folder.folder.id}/policies/iam.automaticIamGrantsForDefaultServiceAccounts"
  parent = google_folder.folder.id

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Project ids can NEVER BE REUSED, even if you delete the project.
# therefore: Better to use an ID that means NOTHING and change the 
# name and the resources within than to delete and waste names
module "test" {
  source = "./modules/project"

  depends_on = [
    google_org_policy_policy.skip_default_network_creation,
    google_org_policy_policy.prevent_default_gsa_grants
  ]

  project            = var.project_data["test"]
  project_name       = "My Test Project"
  folder_id          = google_folder.folder.folder_id
  billing_account_id = data.google_billing_account.billing.id
}
