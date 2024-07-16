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
    for intf, vpc in local.enabled_interfaces :
    intf => vpc if vpc.overlay == "public"
  }
  private_overlay_interfaces = {
    for intf, vpc in local.enabled_interfaces :
    intf => vpc if vpc.overlay == "private"
  }
  non_overlay_interfaces = setsubtract(keys(local.enabled_interfaces), keys(merge(local.public_overlay_interfaces, local.private_overlay_interfaces)))
}

resource "netskopebwan_policy" "multicloud" {
  name = var.netskope_gateway_config.gateway_policy
}

locals {
  netskopebwan_policy = resource.netskopebwan_policy.multicloud
}

// Gateway Resource 
resource "netskopebwan_gateway" "primary" {
  name  = var.netskope_gateway_config.gateway_name
  model = var.netskope_gateway_config.gateway_model
  role  = var.netskope_gateway_config.gateway_role
  assigned_policy {
    id   = local.netskopebwan_policy.id
    name = local.netskopebwan_policy.name
  }
}

# Netskope GW creation can take a few seconds to
# create all dependent services in backend
resource "time_sleep" "primary_gw_propagation" {
  create_duration = "30s"

  triggers = {
    gateway_id = netskopebwan_gateway.primary.id
  }
}

resource "netskopebwan_gateway" "secondary" {
  count = var.netskope_gateway_config.ha_enabled ? 1 : 0
  name  = "${var.netskope_gateway_config.gateway_name}-ha"
  model = var.netskope_gateway_config.gateway_model
  role  = var.netskope_gateway_config.gateway_role
  assigned_policy {
    id   = local.netskopebwan_policy.id
    name = local.netskopebwan_policy.name
  }
  depends_on = [netskopebwan_gateway.primary, time_sleep.api_delay]
}

resource "time_sleep" "secondary_gw_propagation" {
  count           = var.netskope_gateway_config.ha_enabled ? 1 : 0
  create_duration = "30s"

  triggers = {
    gateway_id = netskopebwan_gateway.secondary[0].id
  }
}

resource "netskopebwan_gateway_interface" "primary" {
  for_each   = local.enabled_interfaces
  gateway_id = time_sleep.primary_gw_propagation.triggers["gateway_id"]
  name       = upper(each.key)
  type       = "ethernet"
  addresses {
    address            = cidrhost(var.gcp_network_config.subnets[each.key].ip_cidr_range, 2)
    address_assignment = "static"
    address_family     = "ipv4"
    dns_primary        = var.netskope_gateway_config.dns_primary
    dns_secondary      = var.netskope_gateway_config.dns_secondary
    gateway            = var.gcp_network_config.subnets[each.key].gateway_address
    mask               = cidrnetmask(var.gcp_network_config.subnets[each.key].ip_cidr_range)
  }
  dynamic "overlay_setting" {
    for_each = lookup(merge(local.public_overlay_interfaces, local.private_overlay_interfaces), each.key, "") != "" ? [1] : []
    content {
      is_backup           = false
      tx_bw_kbps          = 1000000
      rx_bw_kbps          = 1000000
      bw_measurement_mode = "manual"
      tag                 = lookup(local.public_overlay_interfaces, each.key, "") != "" ? "wired" : "private"
    }
  }
  enable_nat  = lookup(local.public_overlay_interfaces, each.key, "") != "" ? true : false
  mode        = "routed"
  is_disabled = false
  zone        = lookup(local.public_overlay_interfaces, each.key, "") != "" ? "untrusted" : "trusted"
}

resource "netskopebwan_gateway_interface" "secondary" {
  for_each = {
    for intf, vpc in local.enabled_interfaces : intf => vpc
    if var.netskope_gateway_config.ha_enabled
  }

  gateway_id = time_sleep.secondary_gw_propagation[0].triggers["gateway_id"]
  name       = upper(each.key)
  type       = "ethernet"
  addresses {
    address            = cidrhost(var.gcp_network_config.subnets[each.key].ip_cidr_range, 3)
    address_assignment = "static"
    address_family     = "ipv4"
    dns_primary        = var.netskope_gateway_config.dns_primary
    dns_secondary      = var.netskope_gateway_config.dns_secondary
    gateway            = ""
    mask               = cidrnetmask(var.gcp_network_config.subnets[each.key].ip_cidr_range)
  }
  dynamic "overlay_setting" {
    for_each = lookup(merge(local.public_overlay_interfaces, local.private_overlay_interfaces), each.key, "") != "" ? [1] : []
    content {
      is_backup           = false
      tx_bw_kbps          = 1000000
      rx_bw_kbps          = 1000000
      bw_measurement_mode = "manual"
      tag                 = lookup(local.public_overlay_interfaces, each.key, "") != "" ? "wired" : "private"
    }
  }
  enable_nat  = lookup(local.public_overlay_interfaces, each.key, "") != "" ? true : false
  mode        = "routed"
  is_disabled = false
  zone        = lookup(local.public_overlay_interfaces, each.key, "") != "" ? "untrusted" : "trusted"
}

// Static Route
resource "netskopebwan_gateway_staticroute" "primary" {
  gateway_id  = time_sleep.primary_gw_propagation.triggers["gateway_id"]
  advertise   = false
  destination = "169.254.169.254/32"
  device      = "GE1"
  install     = true
  nhop        = var.gcp_network_config.subnets[keys(local.public_overlay_interfaces)[0]].gateway_address
}

resource "netskopebwan_gateway_staticroute" "secondary" {
  count       = var.netskope_gateway_config.ha_enabled ? 1 : 0
  gateway_id  = time_sleep.secondary_gw_propagation[0].triggers["gateway_id"]
  advertise   = false
  destination = "169.254.169.254/32"
  device      = "GE1"
  install     = true
  nhop        = var.gcp_network_config.subnets[keys(local.public_overlay_interfaces)[0]].gateway_address
}

resource "netskopebwan_gateway_activate" "primary" {
  gateway_id         = time_sleep.primary_gw_propagation.triggers["gateway_id"]
  timeout_in_seconds = 86400
}

resource "netskopebwan_gateway_activate" "secondary" {
  count              = var.netskope_gateway_config.ha_enabled ? 1 : 0
  gateway_id         = time_sleep.secondary_gw_propagation[0].triggers["gateway_id"]
  timeout_in_seconds = 86400
}