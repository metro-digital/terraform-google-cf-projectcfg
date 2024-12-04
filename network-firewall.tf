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

resource "google_compute_firewall" "allow_all_internal" {
  provider = google
  count    = var.skip_default_vpc_creation ? 0 : 1

  name        = "fw-allow-all-internal"
  description = "Allows all traffic from inside VPC"
  network     = google_compute_network.default[0].name
  project     = data.google_project.project.project_id

  allow {
    protocol = "all"
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  source_ranges = local.default_vpc_active_ranges
}

resource "google_compute_firewall" "allow_icmp_metro_public" {
  provider = google
  count    = var.skip_default_vpc_creation ? 0 : 1

  name        = "fw-allow-icmp-metro-public"
  description = "Allows ICMP (ping) traffic from all known Metro IP Addresses (public)"
  network     = google_compute_network.default[0].name
  project     = data.google_project.project.project_id

  allow {
    protocol = "icmp"
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  target_tags = [
    "fw-allow-icmp-metro-public",
  ]

  source_ranges = local.metro_netblocks.ipv4
}

resource "google_compute_firewall" "allow_http_metro_public" {
  provider = google
  count    = var.skip_default_vpc_creation ? 0 : 1

  name        = "fw-allow-http-metro-public"
  description = "Allows HTTP traffic from all known Metro IP Addresses (public)"
  network     = google_compute_network.default[0].name
  project     = data.google_project.project.project_id

  allow {
    protocol = "tcp"
    ports    = [80]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  target_tags = [
    "fw-allow-http-metro-public",
  ]

  source_ranges = local.metro_netblocks.ipv4
}

resource "google_compute_firewall" "allow_https_metro_public" {
  provider = google
  count    = var.skip_default_vpc_creation ? 0 : 1

  name        = "fw-allow-https-metro-public"
  description = "Allows HTTPS traffic from all known Metro IP Addresses (public)"
  network     = google_compute_network.default[0].name
  project     = data.google_project.project.project_id

  allow {
    protocol = "tcp"
    ports    = [443]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  target_tags = [
    "fw-allow-https-metro-public",
  ]

  source_ranges = local.metro_netblocks.ipv4
}

resource "google_compute_firewall" "allow_ssh_metro_public" {
  provider = google
  count    = var.skip_default_vpc_creation ? 0 : 1

  name        = "fw-allow-ssh-metro-public"
  description = "Allows SSH traffic from all known Metro IP Addresses (public)"
  network     = google_compute_network.default[0].name
  project     = data.google_project.project.project_id

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  target_tags = [
    "fw-allow-ssh-metro-public",
  ]

  source_ranges = local.metro_netblocks.ipv4
}

resource "google_compute_firewall" "allow_ssh_iap" {
  provider = google
  count    = var.skip_default_vpc_creation ? 0 : 1

  name        = "fw-allow-ssh-iap"
  description = "Allows SSH traffic from all known IP Addresses used by Cloud Identity-Aware Proxy"
  network     = google_compute_network.default[0].name
  project     = data.google_project.project.project_id

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  target_tags = [
    "fw-allow-ssh-iap",
  ]

  source_ranges = data.google_netblock_ip_ranges.iap_forwarders.cidr_blocks
}

