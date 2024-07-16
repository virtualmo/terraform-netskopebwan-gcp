#------------------------------------------------------------------------------
#  Copyright (c) 2022 Infiot Inc.
#  All rights reserved.
#------------------------------------------------------------------------------
##################################
## Profile and Region Variables ##
##################################
variable "gcp_profile" {
  description = "GCP Config Profile"
  type = object({
    project_id = string
    region     = optional(string, "us-west2")
    ssh_key    = optional(string, "")
  })
}

variable "clients" {
  description = "Optional Client / Host VPC configuration"
  type = object({
    create_clients = optional(bool, false) # Blob to deploy optional Client in a new VPC for end to end testing.
    image_id       = optional(string, "projects/gce-uefi-images/global/images/ubuntu-1804-bionic-v20180911")
    vpc_cidr       = optional(string, "192.168.255.0/28")
    instance_type  = optional(string, "t3.large")
    password       = optional(string, "infiot")
    ports          = optional(list(string), ["3389", "22"])
  })
  default = {
    create_clients = false
  }
}

###########################
## Netskope GW Variables ##
###########################

variable "netskope_tenant" {
  description = "Netskope Tenant Details"
  type = object({
    tenant_id      = string
    tenant_url     = string
    tenant_token   = string
    tenant_bgp_asn = optional(string, "400")
  })
}

variable "netskope_vpc" {
  type = any
}

variable "primary_gw_data" { # This will be computed during run
  type = object({
    id         = optional(string, "")
    token      = optional(string, "")
    userdata   = optional(string, "")
    bgp_metric = optional(string, "")
    public_ips = optional(any)
    interfaces = optional(any)
  })
  default = {
    bgp_metric = "10"
  }
}

variable "secondary_gw_data" { # This will be computed during run
  type = object({
    id         = optional(string, "")
    token      = optional(string, "")
    userdata   = optional(string, "")
    bgp_metric = optional(string, "")
    public_ips = optional(any)
    interfaces = optional(any)
  })
  default = {
    bgp_metric = "20"
  }
}