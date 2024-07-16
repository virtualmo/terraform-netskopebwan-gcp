#------------------------------------------------------------------------------
#  Copyright (c) 2022 Infiot Inc.
#  All rights reserved.
#------------------------------------------------------------------------------

/*
# Least privilege service account for GCE VMs
resource "google_service_account" "netskope_sdwan_gw_svc_iam" {
  account_id  = join("-", ["svc", var.netskope_tenant.tenant_id])
  description = "GCE Appliance SA"

  depends_on = [google_project_service.apis]
}*/