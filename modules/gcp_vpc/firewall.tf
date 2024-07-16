#------------------------------------------------------------------------------
#  Copyright (c) 2022 Infiot Inc.
#  All rights reserved.
#------------------------------------------------------------------------------
resource "google_compute_firewall" "netskope_sdwan_gw_public_fw" {
  for_each = toset(keys(local.public_overlay_interfaces))
  name     = join("-", ["fw", var.netskope_tenant.tenant_id, var.gcp_profile.region, each.key])
  network  = local.vpc_objects[each.key].name

  allow {
    protocol = "tcp"
    ports    = [22, 3389]
  }

  allow {
    protocol = "udp"
    ports    = [4500]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "netskope_sdwan_gw_private_fw" {
  for_each = local.lan_interfaces
  name     = join("-", ["fw", var.netskope_tenant.tenant_id, var.gcp_profile.region, each.key])
  network  = local.vpc_objects[each.key].name

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}