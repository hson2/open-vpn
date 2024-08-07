variable "network_name" {
  description = "The name of the VPC network"
}

variable "static_ip" {
  description = "The static IP address"
}

variable "service_account_email" {
  description = "The service account email"
}

variable "zone" {
  description = "The GCP zone"
}

variable "instance_tag" {
  description = "The network tag to apply to the instance and firewall rule"
}

variable "instance_image_name" {
  description = "The instance image used to create the VM instance"
}

variable "instance_name" {
  description = "The instance image used to create the VM instance"
}

variable "instance_port" {
  description = "The instance image used to create the VM instance"
}

variable "bucket_name" {
  description = "The bucket name used to store ovpn files"
}

variable "objects" {
  type = list(string)
  description = "The objects to pull from storage during startup"
}

resource "google_compute_instance" "openvpn_instance" {
  name         = var.instance_name
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.instance_image_name
    }
  }

  network_interface {
    network = var.network_name

    access_config {
      nat_ip = var.static_ip
    }
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags = [var.instance_tag]

  metadata_startup_script = <<-EOF
    #cloud-config
    runcmd:
      - |
        if [ ! -f /var/log/first-boot.log ]; then
          #install gsutil
          sudo apt update
          sudo apt install -y apt-transport-https ca-certificates gnupg curl
          curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
          echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
          sudo apt-get update && sudo apt-get install -y google-cloud-cli

          cd /home/$(whoami)/open-vpn
          %{ for obj in var.objects }
          gsutil cp gs://${var.bucket_name}/${obj} ${obj}
          %{ endfor }
          sudo chmod +x setup_openvpn.sh
          sudo ./setup_openvpn.sh --clients 3 --server_ip ${var.static_ip} --server_port ${var.instance_port} --bucket_name ${var.bucket_name}
          sudo touch /var/log/first-boot.log
        fi
        sudo systemctl stop openvpn-server@server.service
        sudo systemctl start openvpn-server@server.service        
  EOF
}
