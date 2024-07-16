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
  vpc_names = {
    for intf, vpc in local.enabled_interfaces :
    intf => element(coalescelist(var.gcp_network_config[intf].vpc_name != null ? [var.gcp_network_config[intf].vpc_name] : [], [join("-", ["nsg", var.netskope_tenant.tenant_id, var.gcp_profile.region, intf])]), 0)
  }
}

data "google_compute_network" "netskope_sdwan_gw_vpcs" {
  for_each = {
    for intf, vpc in local.enabled_interfaces : intf => vpc if try(var.gcp_network_config[intf].vpc_name, "") != null
  }
  name = local.vpc_names[each.key]
}

resource "google_compute_network" "netskope_sdwan_gw_vpcs" {
  for_each = {
    for intf, vpc in local.enabled_interfaces : intf => vpc if try(var.gcp_network_config[intf].vpc_name, "") == null
  }
  name                    = join("-", ["nsg", var.netskope_tenant.tenant_id, var.gcp_profile.region, each.key])
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

locals {
  vpc_objects = {
    for intf, vpc in local.enabled_interfaces :
    intf => element(coalescelist(try([lookup(data.google_compute_network.netskope_sdwan_gw_vpcs, intf)], []), try([lookup(google_compute_network.netskope_sdwan_gw_vpcs, intf)], []), [""]), 0)
  }
}

resource "google_compute_subnetwork" "netskope_sdwan_gw_subnets" {
  description = "Netskope BWAN GW Subnet"
  for_each = {
    for intf, vpc in local.vpc_objects : intf => vpc
  }
  network                  = local.vpc_objects[each.key].id
  name                     = join("-", ["subnet", var.netskope_tenant.tenant_id, var.gcp_profile.region, each.key])
  private_ip_google_access = true
  region                   = var.gcp_profile.region

  ip_cidr_range = var.gcp_network_config[each.key].vpc_cidr
}