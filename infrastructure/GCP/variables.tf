variable "project_id" {
  description = "The GCP Project ID"
  type        = string
  default     = "clgcporg127-p001" 
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "us-central1-a"
}
