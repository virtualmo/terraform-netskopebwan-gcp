#------------------------------------------------------------------------------
#  Copyright (c) 2022 Infiot Inc.
#  All rights reserved.
#------------------------------------------------------------------------------

output "gcp_vpc_output" {
  value = {
    vpcs    = local.vpc_objects
    subnets = google_compute_subnetwork.netskope_sdwan_gw_subnets
  }
}
