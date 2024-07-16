#------------------------------------------------------------------------------
#  Copyright (c) 2022 Infiot Inc.
#  All rights reserved.
#------------------------------------------------------------------------------

data "google_compute_zones" "available" {
  status = "UP"
  region = var.gcp_profile.region
}

module "client-network" {
  source       = "terraform-google-modules/network/google"
  version      = "~> 5.2.0"
  project_id   = var.gcp_profile.project_id
  network_name = join("-", ["client", var.netskope_tenant.tenant_id, var.gcp_profile.region])

  delete_default_internet_gateway_routes = true
  routing_mode                           = "REGIONAL"

  subnets = [
    {
      subnet_name           = join("-", ["client", var.netskope_tenant.tenant_id, var.gcp_profile.region])
      subnet_ip             = var.clients.vpc_cidr
      subnet_private_access = true
      subnet_region         = var.gcp_profile.region
    }
  ]
}

resource "google_compute_network_peering" "client_gw" {
  name                 = "client-to-netskope"
  network              = module.client-network.network_self_link
  peer_network         = var.netskope_vpc.self_link
  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "gw_client" {
  name                 = "netskope-to-client"
  network              = var.netskope_vpc.self_link
  peer_network         = module.client-network.network_self_link
  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_firewall" "client" {
  name    = join("-", ["client", var.netskope_tenant.tenant_id, var.gcp_profile.region])
  network = module.client-network.network_name

  allow {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_address" "client" {
  name         = join("-", ["client", var.netskope_tenant.tenant_id, var.gcp_profile.region])
  subnetwork   = module.client-network.subnets_ids[0]
  address_type = "INTERNAL"
  address      = cidrhost(var.clients.vpc_cidr, 2)
}

resource "google_compute_instance" "client" {
  name           = join("-", ["client", var.netskope_tenant.tenant_id, var.gcp_profile.region])
  machine_type   = var.clients.instance_type
  zone           = data.google_compute_zones.available.names[0]
  can_ip_forward = false

  boot_disk {
    initialize_params {
      image = var.clients.image_id
    }
  }
  network_interface {
    subnetwork = module.client-network.subnets_self_links[0]
    network_ip = google_compute_address.client.address
  }
  metadata = {
    user-data = templatefile("modules/clients/scripts/user-data.sh",
      {
        password = var.clients.password
      }
    )
    enable-oslogin = true
    ssh-keys       = var.gcp_profile.ssh_key
  }
}