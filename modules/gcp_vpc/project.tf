#------------------------------------------------------------------------------
#  Copyright (c) 2022 Infiot Inc.
#  All rights reserved.
#------------------------------------------------------------------------------

resource "google_compute_project_metadata" "oslogin" {
  metadata = {
    enable-oslogin = "TRUE"
  }
}