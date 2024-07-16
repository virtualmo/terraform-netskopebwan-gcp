#------------------------------------------------------------------------------
#  Copyright (c) 2022 Infiot Inc.
#  All rights reserved.
#------------------------------------------------------------------------------

terraform {
  required_version = ">=0.13"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.26.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.7.2"
    }
    netskopebwan = {
      source  = "netskopeoss/netskopebwan"
      version = "0.0.2"
    }
  }
}