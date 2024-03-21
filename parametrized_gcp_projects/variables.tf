variable "google_artifact_registry" {
  type = object({
    project_id = string
    location   = string
    name       = string
  })
  description = "Details of the Google Artifact Registry"
}
variable "uber_project_id" {
  description = "The id of the uber terraform project"
  type        = string
}
variable "uber_gsa_name" {
  description = "The name of the service account for the uber project"
  type        = string
}
variable "project_data" {
  description = "The values for the each env's projects; key = environmentName; value = data"
  type = map(object({
    id       = string
    short_id = string
    region   = string
    network = object({
      name              = string
      services_subnet   = string
      serverless_subnet = string
    })
    })
  )
}
