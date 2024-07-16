#------------------------------------------------------------------------------
#  Copyright (c) 2022 Infiot Inc.
#  All rights reserved.
#------------------------------------------------------------------------------

locals {
  enabled_interfaces = {
    for intf, vpc in var.gcp_network_config :
    intf => vpc if vpc != null && startswith(intf, "ge")
  }
  public_overlay_interfaces = {
    for intf, vpc in local.enabled_interfaces : intf => vpc if vpc.overlay == "public"
  }
  private_overlay_interfaces = {
    for intf, vpc in local.enabled_interfaces : intf => vpc if vpc.overlay == "private"
  }
  non_overlay_interfaces = setsubtract(keys(local.enabled_interfaces), keys(merge(local.public_overlay_interfaces, local.private_overlay_interfaces)))
  lan_interfaces         = length(local.non_overlay_interfaces) != 0 ? local.non_overlay_interfaces : keys(local.private_overlay_interfaces)
  cloud_router_config = {
    cloud_router_iface1_ip = try(cidrhost(var.gcp_network_config[tolist(local.lan_interfaces)[0]].vpc_cidr, -3), "")
    cloud_router_iface2_ip = try(cidrhost(var.gcp_network_config[tolist(local.lan_interfaces)[0]].vpc_cidr, -4), "")
  }
}

module "gcp_vpc" {
  source                  = "./modules/gcp_vpc"
  gcp_profile             = var.gcp_profile
  gcp_network_config      = var.gcp_network_config
  gcp_compute             = var.gcp_compute
  gcp_ncc_config          = var.gcp_ncc_config
  netskope_tenant         = var.netskope_tenant
  netskope_gateway_config = var.netskope_gateway_config
}

module "nsg_config" {
  source                  = "./modules/nsg_config"
  gcp_profile             = var.gcp_profile
  gcp_compute             = var.gcp_compute
  netskope_tenant         = var.netskope_tenant
  gcp_ncc_config          = merge(var.gcp_ncc_config, local.cloud_router_config)
  gcp_network_config      = merge(var.gcp_network_config, module.gcp_vpc.gcp_vpc_output)
  netskope_gateway_config = var.netskope_gateway_config
}

locals {
  userdata = {
    primary = {
      userdata = templatefile("modules/gcp_compute/scripts/user-data.sh",
        {
          netskope_gw_default_password = var.netskope_gateway_config.gateway_password,
          netskope_tenant_url          = var.netskope_tenant.tenant_url,
          netskope_gw_activation_key   = module.nsg_config.nsg_config_output.primary.token,
          netskope_gw_bgp_metric       = var.primary_gw_data.bgp_metric,
          netskope_gw_asn              = var.netskope_tenant.tenant_bgp_asn,
          cloud_router_iface1_ip       = local.cloud_router_config.cloud_router_iface1_ip,
          cloud_router_iface2_ip       = local.cloud_router_config.cloud_router_iface2_ip
        }
      )
    }
    secondary = {
      userdata = templatefile("modules/gcp_compute/scripts/user-data.sh",
        {
          netskope_gw_default_password = var.netskope_gateway_config.gateway_password,
          netskope_tenant_url          = var.netskope_tenant.tenant_url,
          netskope_gw_activation_key   = module.nsg_config.nsg_config_output.secondary.token,
          netskope_gw_bgp_metric       = var.secondary_gw_data.bgp_metric,
          netskope_gw_asn              = var.netskope_tenant.tenant_bgp_asn,
          cloud_router_iface1_ip       = local.cloud_router_config.cloud_router_iface1_ip,
          cloud_router_iface2_ip       = local.cloud_router_config.cloud_router_iface2_ip
        }
      )
    }
  }
}

module "gcp_compute" {
  source                  = "./modules/gcp_compute"
  gcp_profile             = var.gcp_profile
  gcp_compute             = var.gcp_compute
  gcp_network_config      = merge(var.gcp_network_config, module.gcp_vpc.gcp_vpc_output)
  netskope_tenant         = var.netskope_tenant
  netskope_gateway_config = merge(var.netskope_gateway_config, module.nsg_config.nsg_config_output, local.userdata)
  gcp_ncc_config          = merge(var.gcp_ncc_config, local.cloud_router_config)
  primary_gw_data         = merge(module.nsg_config.nsg_config_output.primary, local.userdata.primary)
  secondary_gw_data       = merge(module.nsg_config.nsg_config_output.secondary, local.userdata.secondary)
}

module "bgp_config" {
  source                  = "./modules/bgp_config"
  gcp_profile             = var.gcp_profile
  gcp_compute             = var.gcp_compute
  netskope_tenant         = var.netskope_tenant
  gcp_ncc_config          = merge(var.gcp_ncc_config, local.cloud_router_config)
  gcp_network_config      = merge(var.gcp_network_config, module.gcp_vpc.gcp_vpc_output)
  netskope_gateway_config = merge(var.netskope_gateway_config, module.nsg_config.nsg_config_output, local.userdata)
  primary_gw_data         = merge(module.nsg_config.nsg_config_output.primary, local.userdata.primary)
  secondary_gw_data       = merge(module.nsg_config.nsg_config_output.secondary, local.userdata.secondary)
}

module "clients" {
  source          = "./modules/clients"
  count           = var.clients.create_clients ? 1 : 0
  gcp_profile     = var.gcp_profile
  clients         = var.clients
  netskope_tenant = var.netskope_tenant
  primary_gw_data = merge(module.nsg_config.nsg_config_output.primary, module.gcp_compute.public_ips.primary, local.userdata.primary)
  netskope_vpc    = module.gcp_vpc.gcp_vpc_output.vpcs[tolist(local.lan_interfaces)[0]]
}