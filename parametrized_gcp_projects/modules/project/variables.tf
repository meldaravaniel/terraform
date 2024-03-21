variable "project" {
  description = "The values for the project"
  type = object({
    id       = string # A globally unique identifier for the project
    short_id = string # A suffix to use in naming resources
    region   = string
    network = object({ # Data to use when creating the network and subnets
      name              = string
      services_subnet   = string
      serverless_subnet = string
    })
  })

  validation {
    # {3, 28} looks wrong, but that's because the regex explicitly checks the first and last chars, so we subtract 2 from the length requirement.
    condition     = can(regex("^[a-z][a-z0-9-]{3,28}[a-z0-9]$", var.project.id))
    error_message = "Must be from 6 to 30 characters; only contain lower case letters, numbers, or hyphens; start with a letter; not end with a hyphen"
  }
  validation {
    condition     = !can(regex("^.*(google|null|undefined|ssl).*$", var.project.id))
    error_message = "May not contain the words: 'google', 'null', 'undefined', or 'ssl'."
  }
  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.project.short_id))
    error_message = "Must be from 3 to 5 characters long, lowercase letters only."
  }

}
variable "project_name" {
  type        = string
  description = "A human-readable name for the project; does not need to be unique, and can be updated later"
  validation {
    condition     = can(regex("^.{4,30}$", var.project_name))
    error_message = "Must be from 4 to 30 characters"
  }
  validation {
    condition     = can(regex("^[a-zA-Z0-9\\s'\"!-]*$", var.project_name))
    error_message = "May only contain lower/upper letters, numbers, hyphens, single/double quotes, spaces, or exclamation points"
  }
}
variable "folder_id" {
  type        = string
  description = "The id of the folder in which to create the project"
}
variable "billing_account_id" {
  type        = string
  description = "The ID of the billing account to assign to the project"
}
variable "enabled_gcp_services" {
  description = "The list of apis necessary for the project"
  type        = list(string)
  default = [
    "container",                  # for Google Kubernetes Engine
    "compute",                    # for GKE and GCS
    "logging", "monitoring",      # for observability
    "sqladmin",                   # for making/interacting with sql instances
    "cloudkms", "iamcredentials", # for IAM Roles/Permissions
    "run", "iap", "vpcaccess",    # for VPC Native stuff
    "servicenetworking",          # for using private services access (connecting VPC to CloudSQL)
    "cloudresourcemanager",       # for Resource Manager
    "secretmanager",              # for storing a few secrets
    "cloudfunctions",
    "eventarc", "cloudbuild",
    "pubsub",
    "artifactregistry", # for Artifact Registry
    "datamigration"     # necessary for migrating db instnaces from A to B
  ]
}
