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

# NAT-related resources
locals {
  nat_config_regions = {
    for region, conf in var.vpc_regions : region => {
      nat_ip_allocate_option = conf.nat.mode == "AUTO" ? "AUTO_ONLY" : "MANUAL_ONLY"
      min_ports_per_vm       = conf.nat.min_ports_per_vm
      ip_names = conf.nat.mode == "AUTO" ? [] : [
        for i in range(1, conf.nat.num_ips + 1) : format("%s-%04d", region, i)
      ],
    } if conf.nat.mode != "DISABLED"
  }

  nat_ips = toset(flatten([for region, config in local.nat_config_regions : config.ip_names]))
}

resource "google_compute_router" "router" {
  provider = google
  for_each = local.nat_config_regions

  name    = "router-${each.key}"
  project = data.google_project.this.project_id
  region  = each.key
  network = google_compute_network.default[0].self_link
}

resource "google_compute_address" "address" {
  provider = google
  for_each = local.nat_ips

  name         = "nat-ip-${each.key}"
  address_type = "EXTERNAL"
  project      = data.google_project.this.project_id
  region       = substr(each.key, 0, length(each.key) - 5)
}

resource "google_compute_router_nat" "nat" {
  provider = google
  for_each = local.nat_config_regions

  name    = "nat-${each.key}"
  router  = google_compute_router.router[each.key].name
  project = data.google_project.this.project_id
  region  = each.key

  nat_ip_allocate_option = each.value.nat_ip_allocate_option
  nat_ips = each.value.nat_ip_allocate_option == "AUTO_ONLY" ? null : [
    for ip in each.value.ip_names : google_compute_address.address[ip].self_link
  ]

  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES"
  min_ports_per_vm                   = each.value.min_ports_per_vm

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
