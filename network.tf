# Copyright 2021 METRO Digital GmbH
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
  # Network IP range planing:
  #   - we do use 172.16.0.0/12 as it is least used within METRO
  #
  # 172.16.0.0/15 = 172.16.0.0 to 172.17.255.255
  # Used for subnetworks in different regions
  default_vpc_subnets = {
    europe-west1  = "172.16.0.0/20"
    europe-west2  = "172.16.16.0/20"
    europe-west3  = "172.16.32.0/20"
    europe-west4  = "172.16.48.0/20"
    europe-north1 = "172.16.65.0/20"
  }

  # 172.18.0.0/15 = 172.19.0.0 to 172.19.255.255
  # Used for serverless access vpc connectors in different regions
  default_vpc_subnet_connectors = {
    europe-west1  = "172.18.0.0/28"
    europe-west2  = "172.18.0.16/28"
    europe-west3  = "172.18.0.32/28"
    europe-west4  = "172.18.0.48/28"
    europe-north1 = "172.18.0.64/28"
  }

  default_vpc_private_peering = {
    address       = "172.20.0.0"
    prefix_length = "16"
  }

  # Helper to get ALL active IPs in a VPC
  default_vpc_active_subnets = compact(concat(
    [for r in keys(var.vpc_regions) : local.default_vpc_subnets[r]],
    [for r in keys(var.vpc_regions) : local.default_vpc_subnet_connectors[r] if var.vpc_regions[r].vpcaccess],
    ["${local.default_vpc_private_peering.address}/${local.default_vpc_private_peering.prefix_length}"]
    )
  )
}

resource "google_compute_network" "default" {
  provider = google
  count    = var.skip_default_vpc_creation ? 0 : 1

  name                    = "default"
  description             = "Default VPC network for the project"
  project                 = data.google_project.project.project_id
  auto_create_subnetworks = false
  # ensure necessary services are enabled and permissions granted
  depends_on = [
    google_project_service.project,
    google_project_iam_binding.roles,
    google_project_iam_custom_role.custom_roles,
    google_project_iam_binding.custom_roles
  ]
}

# create a default subnet in each enabled region
resource "google_compute_subnetwork" "default" {
  provider = google
  for_each = var.skip_default_vpc_creation ? {} : var.vpc_regions

  name                     = "default-${each.key}"
  description              = "Default subnet in ${each.key}"
  region                   = each.key
  private_ip_google_access = true
  ip_cidr_range            = local.default_vpc_subnets[each.key]
  network                  = google_compute_network.default[0].name
  project                  = data.google_project.project.project_id
  depends_on               = [google_project_service.project]
}

resource "google_vpc_access_connector" "default" {
  provider = google
  for_each = var.skip_default_vpc_creation ? {} : {
    for r in keys(var.vpc_regions) : r => {
      cidr = local.default_vpc_subnet_connectors[r]
  } if var.vpc_regions[r].vpcaccess }

  name          = "vpcaccess-${each.key}"
  region        = each.key
  ip_cidr_range = each.value.cidr
  project       = data.google_project.project.project_id
  network       = google_compute_network.default[0].name
  depends_on = [
    google_project_service.project,
    google_compute_subnetwork.default
  ]

}
