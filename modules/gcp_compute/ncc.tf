#------------------------------------------------------------------------------
#  Copyright (c) 2022 Infiot Inc.
#  All rights reserved.
#------------------------------------------------------------------------------

resource "google_network_connectivity_hub" "netskope-sdwan-ncc-hub" {
  count   = var.gcp_ncc_config.create_cloud_router ? 1 : 0
  name    = join("-", ["ncc-hub", var.netskope_tenant.tenant_id, var.gcp_profile.region])
  project = var.gcp_profile.project_id

  depends_on = [time_sleep.api_delay]
}

resource "google_network_connectivity_spoke" "netskope-sdwan-ncc-spoke-primary" {
  count    = var.gcp_ncc_config.create_cloud_router ? 1 : 0
  name     = join("-", ["ncc-spoke-primary", var.netskope_tenant.tenant_id, var.gcp_profile.region])
  location = var.gcp_profile.region
  hub      = google_network_connectivity_hub.netskope-sdwan-ncc-hub[0].id

  linked_router_appliance_instances {
    instances {
      virtual_machine = google_compute_instance.netskope_sdwan_primary_gw_instance.self_link
      ip_address      = google_compute_address.primary_gw_interface_ip[tolist(local.lan_interfaces)[0]].address
    }
    site_to_site_data_transfer = true
  }
}

resource "google_network_connectivity_spoke" "netskope-sdwan-ncc-spoke-secondary" {
  count    = var.netskope_gateway_config.ha_enabled && var.gcp_ncc_config.create_cloud_router ? 1 : 0
  name     = join("-", ["ncc-spoke-secondary", var.netskope_tenant.tenant_id, var.gcp_profile.region])
  location = var.gcp_profile.region
  hub      = google_network_connectivity_hub.netskope-sdwan-ncc-hub[0].id

  linked_router_appliance_instances {
    instances {
      virtual_machine = try(google_compute_instance.netskope_sdwan_secondary_gw_instance[0].self_link, null)
      ip_address      = try(google_compute_address.secondary_gw_interface_ip[tolist(local.lan_interfaces)[0]].address, null)
    }
    site_to_site_data_transfer = true
  }
}

resource "google_compute_router" "netskope-sdwan-cloud-router" {
  description = "Netskope BWAN Cloud Router"
  count   = var.gcp_ncc_config.create_cloud_router ? 1 : 0
  name    = join("-", ["router", var.netskope_tenant.tenant_id, var.gcp_profile.region])
  network = var.gcp_network_config.vpcs[tolist(local.lan_interfaces)[0]].name
  encrypted_interconnect_router = false
  bgp {
    asn = var.gcp_ncc_config.cloud_router_asn
  }
}

/*
// Unsupported Code.
// Open issue: https://github.com/hashicorp/terraform-provider-google/issues/11206
resource "google_compute_router_interface" "netskope-sdwan-ncc-rtr-iface1" {
  name       = join("-",["rtr", var.site_id, "iface1)
  router     = google_compute_router.netskope-sdwan-cloud-router.name
  region     = var.region
}
resource "google_compute_router_interface" "netskope-sdwan-ncc-rtr-iface2" {
  name       = join("-",["rtr", var.site_id, "iface2)
  router     = google_compute_router.netskope-sdwan-cloud-router.name
  region     = var.region
}
resource "google_compute_router_peer" "netskope-sdwan-ncc-spoke-peer1" {
  name                      = join("-",["rtr-peer", var.site_id, "1)
  router                    = google_compute_router.netskope-sdwan-cloud-router.name
  region                    = var.region
  peer_ip_address           = local.netskope_sdwan_gw1_iface2_ip
  peer_asn                  = var.netskope_gw_asn
  advertised_route_priority = 10
  interface                 = google_compute_router_interface.netskope-sdwan-ncc-rtr-iface1.name
  ip_address                = local.cloud_rtr_iface1_ip
}
resource "google_compute_router_peer" "netskope-sdwan-ncc-spoke-peer2" {
  name                      = join("-",["rtr-peer", var.site_id, "2)
  router                    = google_compute_router.netskope-sdwan-cloud-router.name
  region                    = var.region
  peer_ip_address           = local.netskope_sdwan_gw1_iface2_ip
  peer_asn                  = var.netskope_gw_asn
  advertised_route_priority = 20
  interface                 = google_compute_router_interface.netskope-sdwan-ncc-rtr-iface2.name
  ip_address                = local.cloud_rtr_iface2_ip
}
*/

# Cloud routers mandatorily need redundnat interfaces in assigned subnets.
# So we need to first create redundant interfaces before creating peers.

# https://cloud.google.com/network-connectivity/docs/network-connectivity-center/how-to/creating-router-appliances#create-redundant-interfaces