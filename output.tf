#------------------------------------------------------------------------------
#  Copyright (c) 2022 Infiot Inc.
#  All rights reserved.
#------------------------------------------------------------------------------

output "ncc-primary-bgp-config" {
  value = module.gcp_compute.ncc-primary-bgp-config
}

output "ncc-secondary-bgp-config" {
  value = var.netskope_gateway_config.ha_enabled ? module.gcp_compute.ncc-secondary-bgp-config : null
}

output "primary-gw-route-table-rules" {
  value = module.gcp_compute.primary-gw-route-table-rules
}

output "secondary-gw-route-table-rules" {
  value = var.netskope_gateway_config.ha_enabled ? module.gcp_compute.secondary-gw-route-table-rules : null
}