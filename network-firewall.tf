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

resource "google_compute_firewall" "allow-all-internal" {
  provider = google

  name        = "fw-allow-all-internal"
  description = "Allows all traffic from inside VPC"
  network     = google_compute_network.default.name
  project     = data.google_project.project.project_id

  allow {
    protocol = "all"
  }

  source_ranges = local.default_vpc_active_subnets
}

resource "google_compute_firewall" "allow-icmp-metro-public" {
  provider = google

  name        = "fw-allow-icmp-metro-public"
  description = "Allows ICMP (ping) traffic from all known Metro IP Addresses (public)"
  network     = google_compute_network.default.name
  project     = data.google_project.project.project_id

  allow {
    protocol = "icmp"
  }

  target_tags = [
    "fw-allow-icmp-metro-public",
  ]

  source_ranges = local.metro_netblocks.all_public_v4
}

resource "google_compute_firewall" "allow-http-metro-public" {
  provider = google

  name        = "fw-allow-http-metro-public"
  description = "Allows HTTP traffic from all known Metro IP Addresses (public)"
  network     = google_compute_network.default.name
  project     = data.google_project.project.project_id

  allow {
    protocol = "tcp"
    ports    = [80]
  }

  target_tags = [
    "fw-allow-http-metro-public",
  ]

  source_ranges = local.metro_netblocks.all_public_v4
}

resource "google_compute_firewall" "allow-https-metro-public" {
  provider = google

  name        = "fw-allow-https-metro-public"
  description = "Allows HTTPS traffic from all known Metro IP Addresses (public)"
  network     = google_compute_network.default.name
  project     = data.google_project.project.project_id

  allow {
    protocol = "tcp"
    ports    = [443]
  }

  target_tags = [
    "fw-allow-https-metro-public",
  ]

  source_ranges = local.metro_netblocks.all_public_v4
}

resource "google_compute_firewall" "allow-ssh-metro-public" {
  provider = google

  name        = "fw-allow-ssh-metro-public"
  description = "Allows SSH traffic from all known Metro IP Addresses (public)"
  network     = google_compute_network.default.name
  project     = data.google_project.project.project_id

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  target_tags = [
    "fw-allow-ssh-metro-public",
  ]

  source_ranges = local.metro_netblocks.all_public_v4
}

resource "google_compute_firewall" "allow-ssh-iap" {
  provider = google

  name        = "fw-allow-ssh-iap"
  description = "Allows SSH traffic from all known IP Addresses used by Cloud Identity-Aware Proxy"
  network     = google_compute_network.default.name
  project     = data.google_project.project.project_id

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  target_tags = [
    "fw-allow-ssh-iap",
  ]

  source_ranges = data.google_netblock_ip_ranges.iap-forwarders.cidr_blocks
}

resource "google_compute_firewall" "allow-all-iap" {
  provider = google

  name        = "fw-allow-all-iap"
  description = "Allows ALL traffic from all known IP Addresses used by Cloud Identity-Aware Proxy"
  network     = google_compute_network.default.name
  project     = data.google_project.project.project_id

  allow {
    protocol = "all"
  }

  target_tags = [
    "fw-allow-all-iap",
  ]

  source_ranges = data.google_netblock_ip_ranges.iap-forwarders.cidr_blocks
}
