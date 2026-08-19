module "wiz_cloud_events" {
  source                = "https://downloads.wiz.io/customer-files/gcp/wiz-gcp-cloud-events-terraform-module.zip"
  integration_type      = "PROJECT"
  project_id            = "clgcporg127-p001"
  service_account_email = "485384084393-compute@developer.gserviceaccount.com"

  enable_wiz_defend_log_sources = true
}

output "cloud_events_topic" {
  description = "The Cloud Events topic created for GCP Log Collection"
  value = module.wiz_cloud_events.cloud_events_topic
}

output "cloud_events_subscription_id" {
  description = "The Cloud Events subscription ID created for GCP Log Collection"
  value = module.wiz_cloud_events.cloud_events_subscription_id
}
