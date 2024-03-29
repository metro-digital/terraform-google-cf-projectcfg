# Copyright 2023 METRO Digital GmbH
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

resource "google_project_service" "project" {
  for_each = local.services

  project            = data.google_project.project.project_id
  service            = each.key
  disable_on_destroy = var.enabled_services_disable_on_destroy
}
