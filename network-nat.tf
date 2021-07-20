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

# NAT-related resources
locals {
  nat_config_regions = {
    for r in keys(var.vpc_regions) : r => [
      for i in range(1, var.vpc_regions[r].nat + 1) : format("%s-%04d", r, i)
    ] if var.vpc_regions[r].nat > 0
  }

  nat_ips = toset(flatten([for region, ips in local.nat_config_regions : ips]))
}

resource "google_compute_router" "router" {
  provider = google
  for_each = local.nat_config_regions

  name    = "router-${each.key}"
  project = data.google_project.project.project_id
  region  = each.key
  network = google_compute_network.default.self_link
}

resource "google_compute_address" "address" {
  provider = google
  for_each = local.nat_ips

  name         = "nat-ip-${each.key}"
  address_type = "EXTERNAL"
  project      = data.google_project.project.project_id
  region       = substr(each.key, 0, length(each.key) - 5)
}

resource "google_compute_router_nat" "nat" {
  provider = google
  for_each = local.nat_config_regions

  name                               = "nat-${each.key}"
  router                             = google_compute_router.router[each.key].name
  project                            = data.google_project.project.project_id
  region                             = each.key
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [for ip in each.value : google_compute_address.address[ip].self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
}
