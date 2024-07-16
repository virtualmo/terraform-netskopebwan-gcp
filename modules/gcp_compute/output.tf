#------------------------------------------------------------------------------
#  Copyright (c) 2022 Infiot Inc.
#  All rights reserved.
#------------------------------------------------------------------------------
locals {
  ncc-primary-bgp-config = <<EOF

  ############################################################################################################
  Following commands have to be executed manually since these are not yet supported by GCP terraform provider.
  ############################################################################################################

  IMPORTANT:
    Cloud routers mandatorily need redundnat interfaces in assigned subnets.
    So we need to first create redundant interfaces before creating peers.

    1) Enter gcloud commands below to complete setting up BGP peering between Netskope Gateway and Cloud Router:

        gcloud compute routers add-interface ${join("-", ["router", var.netskope_tenant.tenant_id, var.gcp_profile.region])} \
          --interface-name=${join("-", ["rtr", var.netskope_tenant.tenant_id, var.gcp_profile.region, "iface1"])} \
          --ip-address=${var.gcp_ncc_config.cloud_router_iface1_ip} \
          --subnetwork=${try(var.gcp_network_config.subnets[local.lan_interface].name, "")} \
          --region=${var.gcp_profile.region} \
          --project=${var.gcp_profile.project_id}

        gcloud compute routers add-interface ${join("-", ["router", var.netskope_tenant.tenant_id, var.gcp_profile.region])} \
          --interface-name=${join("-", ["rtr", var.netskope_tenant.tenant_id, var.gcp_profile.region, "iface2"])} \
          --ip-address=${var.gcp_ncc_config.cloud_router_iface2_ip} \
          --subnetwork=${try(var.gcp_network_config.subnets[local.lan_interface].name, "")} \
          --redundant-interface=${join("-", ["rtr", var.netskope_tenant.tenant_id, var.gcp_profile.region, "iface1"])} \
          --region=${var.gcp_profile.region} \
          --project=${var.gcp_profile.project_id}

        gcloud compute routers add-bgp-peer ${join("-", ["router", var.netskope_tenant.tenant_id, var.gcp_profile.region])} \
          --peer-name=${join("-", ["rtr", var.netskope_tenant.tenant_id, var.gcp_profile.region, "primary", "peer1"])} \
          --interface=${join("-", ["rtr", var.netskope_tenant.tenant_id, var.gcp_profile.region, "iface1"])} \
          --peer-ip-address=${try(google_compute_address.primary_gw_interface_ip[local.lan_interface].address, "")} \
          --peer-asn=${var.netskope_tenant.tenant_bgp_asn} \
          --instance=${google_compute_instance.netskope_sdwan_primary_gw_instance.name} \
          --instance-zone=${local.primary_zone} \
          --region=${var.gcp_profile.region} \
          --advertisement-mode=CUSTOM \
          ${length(var.gcp_ncc_config.cloud_rtr_custom_subnets) > 0 ? join("", ["--set-advertisement-ranges="], [join(",", var.gcp_ncc_config.cloud_rtr_custom_subnets)]) : ""}

        gcloud compute routers add-bgp-peer ${join("-", ["router", var.netskope_tenant.tenant_id, var.gcp_profile.region])} \
          --peer-name=${join("-", ["rtr", var.netskope_tenant.tenant_id, var.gcp_profile.region, "primary", "peer2"])} \
          --interface=${join("-", ["rtr", var.netskope_tenant.tenant_id, var.gcp_profile.region, "iface2"])} \
          --peer-ip-address=${try(google_compute_address.primary_gw_interface_ip[local.lan_interface].address, "")} \
          --peer-asn=${var.netskope_tenant.tenant_bgp_asn} \
          --instance=${google_compute_instance.netskope_sdwan_primary_gw_instance.name} \
          --instance-zone=${local.primary_zone} \
          --region=${var.gcp_profile.region} \
          --advertisement-mode=CUSTOM \
          ${length(var.gcp_ncc_config.cloud_rtr_custom_subnets) > 0 ? join("", ["--set-advertisement-ranges="], [join(",", var.gcp_ncc_config.cloud_rtr_custom_subnets)]) : ""}


    2) If you are manually creating VPC Peering with existing VPCs, please do not forget to delete default routes to Default Internet gateway in peered networks manually.

  EOF

  ncc-secondary-bgp-config = <<EOF

  ############################################################################################################
  Since you have configured to deploy HA gateway, please do not forget to execute the following commands too..
  ############################################################################################################

    1) Enter gcloud commands below to complete setting up BGP peering between Netskope HA Gateway and Cloud Router:

        gcloud compute routers add-bgp-peer ${join("-", ["router", var.netskope_tenant.tenant_id, var.gcp_profile.region])} \
          --peer-name=${join("-", ["rtr", var.netskope_tenant.tenant_id, var.gcp_profile.region, "secondary", "peer1"])} \
          --interface=${join("-", ["rtr", var.netskope_tenant.tenant_id, var.gcp_profile.region, "iface1"])} \
          --peer-ip-address=${try(google_compute_address.secondary_gw_interface_ip[local.lan_interface].address, "")} \
          --peer-asn=${var.netskope_tenant.tenant_bgp_asn} \
          --instance=${try(google_compute_instance.netskope_sdwan_secondary_gw_instance[0].name, "")} \
          --instance-zone=${local.secondary_zone} \
          --region=${var.gcp_profile.region} \
          --advertisement-mode=CUSTOM \
          ${length(var.gcp_ncc_config.cloud_rtr_custom_subnets) > 0 ? join("", ["--set-advertisement-ranges="], [join(",", var.gcp_ncc_config.cloud_rtr_custom_subnets)]) : ""}

        gcloud compute routers add-bgp-peer ${join("-", ["router", var.netskope_tenant.tenant_id, var.gcp_profile.region])} \
          --peer-name=${join("-", ["rtr", var.netskope_tenant.tenant_id, var.gcp_profile.region, "secondary", "peer2"])} \
          --interface=${join("-", ["rtr", var.netskope_tenant.tenant_id, var.gcp_profile.region, "iface2"])} \
          --peer-ip-address=${try(google_compute_address.secondary_gw_interface_ip[local.lan_interface].address, "")} \
          --peer-asn=${var.netskope_tenant.tenant_bgp_asn} \
          --instance=${try(google_compute_instance.netskope_sdwan_secondary_gw_instance[0].name, "")} \
          --instance-zone=${local.secondary_zone} \
          --region=${var.gcp_profile.region} \
          --advertisement-mode=CUSTOM \
          ${length(var.gcp_ncc_config.cloud_rtr_custom_subnets) > 0 ? join("", ["--set-advertisement-ranges="], [join(",", var.gcp_ncc_config.cloud_rtr_custom_subnets)]) : ""}
  EOF

  primary-gw-route-table-rules = <<EOF

    ################################################################################################################
    Since GCP doesn't support ARP responses, we need to set ip rules in Primary GW to route the traffic without ARP.
    ################################################################################################################

      Execute the following commands in Netskope Primary GW.

          echo "1    nsglan" | tee -a /etc/iproute2/rt_tables
          ip route add ${try(google_compute_address.primary_gw_interface_ip[local.lan_interface].address, "")} src ${try(google_compute_address.primary_gw_interface_ip[local.lan_interface].address, "")} dev ${local.interface_mapping[local.lan_interface]} table nsglan
          ip route add default via ${try(var.gcp_network_config.subnets[local.lan_interface].gateway_address, "")} dev ${local.interface_mapping[local.lan_interface]} table nsglan
          ip rule add from ${try(google_compute_address.primary_gw_interface_ip[local.lan_interface].address, "")}/32 table nsglan
          ip rule add to ${try(google_compute_address.primary_gw_interface_ip[local.lan_interface].address, "")}/32 table nsglan

  EOF

  secondary-gw-route-table-rules = <<EOF

    #########################
    Same in Secondary GW too.
    #########################

      Execute the following commands in Netskope Secondary GW.

          echo "1    nsglan" | tee -a /etc/iproute2/rt_tables
          ip route add ${try(google_compute_address.secondary_gw_interface_ip[local.lan_interface].address, "")} src ${try(google_compute_address.secondary_gw_interface_ip[local.lan_interface].address, "")} dev ${local.interface_mapping[local.lan_interface]} table nsglan
          ip route add default via ${try(var.gcp_network_config.subnets[local.lan_interface].gateway_address, "")} dev ${local.interface_mapping[local.lan_interface]} table nsglan
          ip rule add from ${try(google_compute_address.secondary_gw_interface_ip[local.lan_interface].address, "")}/32 table nsglan
          ip rule add to ${try(google_compute_address.secondary_gw_interface_ip[local.lan_interface].address, "")}/32 table nsglan

  EOF
}

output "ncc-primary-bgp-config" {
  value = local.ncc-primary-bgp-config
}

output "ncc-secondary-bgp-config" {
  value = var.netskope_gateway_config.ha_enabled ? local.ncc-secondary-bgp-config : null
}

output "primary-gw-route-table-rules" {
  value = local.primary-gw-route-table-rules
}

output "secondary-gw-route-table-rules" {
  value = var.netskope_gateway_config.ha_enabled ? local.secondary-gw-route-table-rules : null
}

output "public_ips" {
  value = {
    primary = {
      public_ips = google_compute_address.primary_gw_pip
    }
    secondary = {
      public_ips = google_compute_address.secondary_gw_pip
    }
  }
}