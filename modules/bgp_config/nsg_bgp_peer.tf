// BGP Peer
resource "netskopebwan_gateway_bgpconfig" "gcp_rtr1_primary" {
  gateway_id = var.primary_gw_data.id
  name       = "cloud-router-primary"
  neighbor   = var.gcp_ncc_config.cloud_router_iface1_ip
  remote_as  = var.gcp_ncc_config.cloud_router_asn
}

resource "netskopebwan_gateway_bgpconfig" "gcp_rtr2_primary" {
  gateway_id = var.primary_gw_data.id
  name       = "cloud-router-secondary"
  neighbor   = var.gcp_ncc_config.cloud_router_iface2_ip
  remote_as  = var.gcp_ncc_config.cloud_router_asn
}

// BGP Peer
resource "netskopebwan_gateway_bgpconfig" "gcp_rtr1_secondary" {
  count      = var.netskope_gateway_config.ha_enabled ? 1 : 0
  gateway_id = var.secondary_gw_data.id
  name       = "cloud-router-primary"
  neighbor   = var.gcp_ncc_config.cloud_router_iface1_ip
  remote_as  = var.gcp_ncc_config.cloud_router_asn
}

resource "netskopebwan_gateway_bgpconfig" "gcp_rtr2_secondary" {
  count      = var.netskope_gateway_config.ha_enabled ? 1 : 0
  gateway_id = var.secondary_gw_data.id
  name       = "cloud-router-secondary"
  neighbor   = var.gcp_ncc_config.cloud_router_iface2_ip
  remote_as  = var.gcp_ncc_config.cloud_router_asn
}