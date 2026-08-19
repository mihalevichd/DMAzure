# Create the VPC
resource "google_compute_network" "wiz_vpc" {
  name                    = "wiz-exercise-vpc"
  auto_create_subnetworks = false
}

# Create a Public Subnet
resource "google_compute_subnetwork" "public_subnet" {
  name          = "wiz-public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.wiz_vpc.id
}

# Create a Private Subnet for K8s
resource "google_compute_subnetwork" "private_subnet" {
  name                     = "wiz-private-subnet"
  ip_cidr_range            = "10.0.2.0/24"
  region                   = var.region
  network                  = google_compute_network.wiz_vpc.id
  private_ip_google_access = true
}

# Intentional Misconfiguration: SSH exposed to the public internet
resource "google_compute_firewall" "allow_ssh_public" {
  name    = "wiz-allow-ssh-public"
  network = google_compute_network.wiz_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["public-ssh"]
}

# Restrict MongoDB access to the Kubernetes private subnet[cite: 1]
resource "google_compute_firewall" "allow_mongo_from_k8s" {
  name    = "wiz-allow-mongo-k8s"
  network = google_compute_network.wiz_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }

  # The CIDR range of the private subnet where GKE lives
  source_ranges = ["10.0.2.0/24"] 
  target_tags   = ["mongodb"]
}
