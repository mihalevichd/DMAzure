# Kubernetes cluster deployed in a private subnet[cite: 1]
resource "google_container_cluster" "primary" {
  name     = "wiz-k8s-cluster"
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.wiz_vpc.id
  subnetwork = google_compute_subnetwork.private_subnet.id

  # Enforce private cluster nodes while allowing public endpoint for kubectl access
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "wiz-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    machine_type = "e2-medium"
  }
}
