# Copyright 2024 METRO Digital GmbH
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
  enabled_firewall_rules = {
    all_internal  = var.skip_default_vpc_creation ? 0 : var.firewall_rules["all_internal"] ? 1 : 0
    allow_ssh_iap = var.skip_default_vpc_creation ? 0 : var.firewall_rules["allow_ssh_iap"] ? 1 : 0
    allow_rdp_iap = var.skip_default_vpc_creation ? 0 : var.firewall_rules["allow_rdp_iap"] ? 1 : 0
  }
}

resource "google_compute_firewall" "allow_all_internal" {
  provider = google
  count    = local.enabled_firewall_rules.all_internal

  name        = "fw-allow-all-internal"
  description = "Allows all traffic from inside VPC"
  network     = google_compute_network.default[0].name
  project     = data.google_project.this.project_id

  allow {
    protocol = "all"
  }

  source_ranges = local.default_vpc_active_ranges
}

resource "google_compute_firewall" "allow_ssh_iap" {
  provider = google
  count    = local.enabled_firewall_rules.allow_ssh_iap

  name        = "fw-allow-ssh-iap"
  description = "Allows SSH traffic from all known IP Addresses used by Cloud Identity-Aware Proxy"
  network     = google_compute_network.default[0].name
  project     = data.google_project.this.project_id

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  target_tags = [
    "fw-allow-ssh-iap",
  ]

  source_ranges = data.google_netblock_ip_ranges.iap_forwarders.cidr_blocks
}

resource "google_compute_firewall" "allow_rdp_iap" {
  provider = google
  count    = local.enabled_firewall_rules.allow_rdp_iap

  name        = "fw-allow-rdp-iap"
  description = "Allows RDP traffic from all known IP Addresses used by Cloud Identity-Aware Proxy"
  network     = google_compute_network.default[0].name
  project     = data.google_project.this.project_id

  allow {
    protocol = "tcp"
    ports    = [3389]
  }

  target_tags = [
    "fw-allow-rdp-iap",
  ]

  source_ranges = data.google_netblock_ip_ranges.iap_forwarders.cidr_blocks
}
