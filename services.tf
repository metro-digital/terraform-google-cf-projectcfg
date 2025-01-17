# Copyright 2025 METRO Digital GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  services = toset(
    distinct(
      concat(
        # 1. These base APIs should be enabled regardless of the usage of the
        # projectcfg module
        [
          "iam.googleapis.com",
          "compute.googleapis.com",
          "dns.googleapis.com",
          "iap.googleapis.com",
          "servicenetworking.googleapis.com"
        ],
        # 2. Enable vpcaccess.googleapis.com if one network requires it
        [for r in keys(var.vpc_regions) : "vpcaccess.googleapis.com" if var.vpc_regions[r].vpcaccess],
        # 3. All services provided by the user
        var.enabled_services
      )
    )
  )
}

resource "google_project_service" "this" {
  for_each = local.services

  project            = data.google_project.this.project_id
  service            = each.key
  disable_on_destroy = var.enabled_services_disable_on_destroy
}

# servicenetworking.googleapis.com is always enabled by this module
# but sometimes this permission is not set on the needed service account.
# This resource makes sure the account is created, so we can add it to to projects IAM policy.
resource "google_project_service_identity" "servicenetworking_service_account" {
  provider = google-beta

  project = data.google_project.this.project_id
  service = "servicenetworking.googleapis.com"

  depends_on = [
    google_project_service.this
  ]
}
