/*data "external" "gcp_cloud_router_interfaces" {
  program = ["modules/gcp_compute/scripts/gcp_bgp_peer.sh"]

  query = {
    # arbitrary map from strings to strings, passed
    # to the external program as the data query.
    cloud_router  = join("-", ["router", var.netskope_tenant.tenant_id, var.gcp_profile.region]),
    tenant_id     = var.netskope_tenant.tenant_id,
    region        = var.gcp_profile.region,
    cloud_rtr_ip1 = var.gcp_ncc_config.cloud_router_iface1_ip,
    cloud_rtr_ip2 = var.gcp_ncc_config.cloud_router_iface2_ip,
    subnet        = var.gcp_network_config.subnets[local.lan_interface].name,
    project       = var.gcp_profile.project_id
  }

  depends_on = [
    google_network_connectivity_hub.netskope-sdwan-ncc-hub,
    google_network_connectivity_spoke.netskope-sdwan-ncc-spoke-primary,
    google_compute_router.netskope-sdwan-cloud-router,
  ]
}

output "t" {
  value = data.external.gcp_cloud_router_interfaces.result
}*/