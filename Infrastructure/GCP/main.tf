# Create the storage bucket for MongoDB backups
resource "google_storage_bucket" "mongo_backups" {
  name          = "${var.project_id}-mongo-backups-public"
  location      = "US"
  force_destroy = true

  # Add this line to comply with the CloudLabs org policy
  uniform_bucket_level_access = true

  # Ensure public access prevention is NOT enforced so we can make it public
  public_access_prevention = "inherited"
}

# Make the bucket publicly readable and listable (Intentional Misconfiguration)
resource "google_storage_bucket_iam_binding" "public_read" {
  bucket = google_storage_bucket.mongo_backups.name
  role   = "roles/storage.objectViewer"

  members = [
    "allUsers",
  ]
}

# Wiz GCP Integration Module
module "wiz" {
  source                           = "https://wizio-public-fedramp.s3-us-gov-west-1.amazonaws.com/deployment-v3/gcp/terraform/2651/wiz-gcp-project-terraform-module.zip"
  project_id                       = "clgcporg127-p001"
  wiz_managed_identity_external_id = "wiz589ba918d1d9691dac0a64c7fd7@aw-fedramp-us1.iam.gserviceaccount.com"
  serverless_scanning              = true
  data_scanning                    = true
  enable_shadow_data               = true
  forensic                         = true
}
