#------------------------------------------------------------------------------
#  Copyright (c) 2022 Infiot Inc.
#  All rights reserved.
#------------------------------------------------------------------------------

data "google_compute_zones" "available" {
  status = "UP"
  region = var.gcp_profile.region
}

locals {
  primary_zone   = var.gcp_compute.primary_zone != null ? var.gcp_compute.primary_zone : data.google_compute_zones.available.names[0]
  secondary_zone = var.gcp_compute.secondary_zone != null ? var.gcp_compute.secondary_zone : data.google_compute_zones.available.names[1]
}

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
  lan_interfaces         = length(local.non_overlay_interfaces) != 0 ? local.non_overlay_interfaces : keys(local.private_overlay_interfaces)
}

locals {
  interface_mapping = {
    "ge1" = "ens4"
    "ge2" = "ens5"
    "ge3" = "ens6"
    "ge4" = "ens7"
  }
  lan_interface = tolist(local.lan_interfaces)[0]
}