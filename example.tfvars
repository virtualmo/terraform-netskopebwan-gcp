#------------------------------------------------------------------------------
#  Copyright (c) 2022 Netskope Inc.
#  All rights reserved.
#------------------------------------------------------------------------------

######################
## Region Variables ##
######################

gcp_profile = {
  project_id = "engineering"
}

gcp_network_config = {
  ge1 = {
    vpc_cidr = "172.16.0.0/28"
  }
  ge2 = {
    vpc_cidr = "172.16.0.16/28"
  }
}

gcp_compute = {
  ssh_key = "1"
}

gcp_ncc_config = {
  cloud_router_asn = "64513"
}

###################################################
##  Netskope Borderless SD-WAN Tenant Variables  ##
###################################################

netskope_tenant = {
  tenant_id      = "6067c"
  tenant_url     = "https://demo54985.infiot.net"
  tenant_token   = "WzEsIjYzNWNhIcmJ0djZCcCswPSJd"
  tenant_bgp_asn = "400"
}

netskope_gateway_config = {
  ha_enabled   = true
  gateway_name = "gcp-gw"
}