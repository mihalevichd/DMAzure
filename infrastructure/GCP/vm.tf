# Intentional Misconfiguration: Overly permissive CSP permissions[cite: 1]
resource "google_service_account" "overly_permissive_sa" {
  account_id   = "wiz-vulnerable-vm-sa"
  display_name = "Vulnerable VM Service Account"
}

# Grants the VM the ability to create/delete other VMs[cite: 1]
resource "google_project_iam_member" "compute_admin" {
  project = var.project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:${google_service_account.overly_permissive_sa.email}"
}

# Intentional Misconfiguration: 1+ year outdated version of Linux[cite: 1]
resource "google_compute_instance" "vulnerable_vm" {
  name         = "wiz-mongodb-vm"
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["public-ssh"]

  boot_disk {
    initialize_params {
      # Ubuntu 18.04 is several years outdated
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.wiz_vpc.id
    subnetwork = google_compute_subnetwork.public_subnet.id
    
    # Assigns a public IP to satisfy the public internet exposure requirement[cite: 1]
    access_config {}
  }

  service_account {
    email  = google_service_account.overly_permissive_sa.email
    scopes = ["cloud-platform"]
  }
  # Automates the installation of an outdated MongoDB, sets up Auth, and configures the backup cron job
  metadata_startup_script = <<-EOT
    #!/bin/bash
    # 1. Install Outdated MongoDB (4.4)
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    sudo apt-get update
    sudo apt-get install -y mongodb-org=4.4.29 mongodb-org-server=4.4.29 mongodb-org-shell=4.4.29 mongodb-org-mongos=4.4.29 mongodb-org-tools=4.4.29

    # 2. Configure MongoDB to listen on all interfaces and enable authorization
    sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.1/' /etc/mongod.conf
    echo -e "security:\n  authorization: enabled" | sudo tee -a /etc/mongod.conf
    
    # Start MongoDB temporarily without auth to create the admin user
    sudo systemctl start mongod
    sleep 10
    mongo admin --eval 'db.createUser({user: "admin", pwd: "wizpassword123", roles: [{role: "userAdminAnyDatabase", db: "admin"}, "readWriteAnyDatabase"]})'
    
    # Restart with auth enabled
    sudo systemctl restart mongod

    # 3. Create Daily Backup Script to Public Bucket[cite: 1]
    cat << 'EOF' > /home/ubuntu/backup.sh
    #!/bin/bash
    TIMESTAMP=$(date +"%F")
    mongodump --username admin --password wizpassword123 --authenticationDatabase admin --out /tmp/mongo_backup_$TIMESTAMP
    gsutil cp -r /tmp/mongo_backup_$TIMESTAMP gs://${var.project_id}-mongo-backups-public/
    rm -rf /tmp/mongo_backup_$TIMESTAMP
    EOF
    
    chmod +x /home/ubuntu/backup.sh

    # 4. Schedule daily backup via Cron[cite: 1]
    (crontab -l 2>/dev/null; echo "0 2 * * * /home/ubuntu/backup.sh") | crontab -
  EOT
}
