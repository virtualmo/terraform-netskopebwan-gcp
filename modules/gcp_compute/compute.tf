#------------------------------------------------------------------------------
#  Copyright (c) 2022 Infiot Inc.
#  All rights reserved.
#------------------------------------------------------------------------------
resource "google_compute_address" "primary_gw_pip" {
  for_each     = toset(keys(local.public_overlay_interfaces))
  name         = join("-", ["nsg", var.primary_gw_data.id, each.key, "pip"])
  address_type = "EXTERNAL"
}

resource "google_compute_address" "secondary_gw_pip" {
  for_each     = var.netskope_gateway_config.ha_enabled ? toset(keys(local.public_overlay_interfaces)) : toset([])
  name         = join("-", ["nsg", var.secondary_gw_data.id, each.key, "pip"])
  address_type = "EXTERNAL"
}

resource "google_compute_address" "primary_gw_interface_ip" {
  for_each     = local.enabled_interfaces
  name         = join("-", ["nsg", var.primary_gw_data.id, each.key])
  subnetwork   = var.gcp_network_config.subnets[each.key].id
  address_type = "INTERNAL"
  address      = cidrhost(var.gcp_network_config.subnets[each.key].ip_cidr_range, 2)
}

resource "google_compute_address" "secondary_gw_interface_ip" {
  for_each     = var.netskope_gateway_config.ha_enabled ? local.enabled_interfaces : {}
  name         = join("-", ["nsg", var.secondary_gw_data.id, each.key])
  subnetwork   = var.gcp_network_config.subnets[each.key].id
  address_type = "INTERNAL"
  address      = cidrhost(var.gcp_network_config.subnets[each.key].ip_cidr_range, 3)
}

resource "google_compute_instance" "netskope_sdwan_primary_gw_instance" {
  name         = join("-", ["nsg", var.primary_gw_data.id])
  machine_type = var.gcp_compute.instance_type
  zone         = local.primary_zone

  boot_disk {
    initialize_params {
      image = var.gcp_compute.image_id
    }
  }

  can_ip_forward = true

  dynamic "network_interface" {
    for_each = keys(local.enabled_interfaces)
    content {
      subnetwork = var.gcp_network_config.subnets[network_interface.value].self_link
      network_ip = google_compute_address.primary_gw_interface_ip[network_interface.value].address
      dynamic "access_config" {
        for_each = lookup(local.public_overlay_interfaces, network_interface.value, "") != "" ? [1] : []
        content {
          nat_ip = google_compute_address.primary_gw_pip[network_interface.value].address
        }
      }
    }
  }
  /*
  metadata_startup_script = templatefile("modules/gcp_compute/scripts/startup-script.sh",
    {
      netskope_ip = try(google_compute_address.primary_gw_interface_ip[local.lan_interface].address, ""),
      gcp_gw_ip   = var.gcp_network_config.subnets[local.lan_interface].gateway_address,
      interface   = local.interface_mapping[local.lan_interface],
    }
  )
*/

  metadata = {
    user-data      = var.primary_gw_data.userdata
    enable-oslogin = true
    ssh-keys       = var.gcp_profile.ssh_key
  }
}

resource "google_compute_instance" "netskope_sdwan_secondary_gw_instance" {
  count        = var.netskope_gateway_config.ha_enabled ? 1 : 0
  name         = join("-", ["nsg", var.secondary_gw_data.id])
  machine_type = var.gcp_compute.instance_type
  zone         = local.secondary_zone

  boot_disk {
    initialize_params {
      image = var.gcp_compute.image_id
    }
  }

  can_ip_forward = true

  dynamic "network_interface" {
    for_each = keys(local.enabled_interfaces)
    content {
      subnetwork = var.gcp_network_config.subnets[network_interface.value].self_link
      network_ip = google_compute_address.secondary_gw_interface_ip[network_interface.value].address
      dynamic "access_config" {
        for_each = lookup(local.public_overlay_interfaces, network_interface.value, "") != "" ? [1] : []
        content {
          nat_ip = google_compute_address.secondary_gw_pip[network_interface.value].address
        }
      }
    }
  }

  /*  metadata_startup_script = templatefile("modules/gcp_compute/scripts/startup-script.sh",
    {
      netskope_ip = try(google_compute_address.secondary_gw_interface_ip[local.lan_interface].address, ""),
      gcp_gw_ip   = var.gcp_network_config.subnets[local.lan_interface].gateway_address,
      interface   = local.interface_mapping[local.lan_interface],
    }
  )
*/

  metadata = {
    user-data      = var.secondary_gw_data.userdata
    enable-oslogin = true
    ssh-keys       = var.gcp_profile.ssh_key
  }
}