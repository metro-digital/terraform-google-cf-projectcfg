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

resource "google_compute_global_address" "google_managed_services" {
  provider = google

  name          = "google-managed-services"
  description   = "IP address block used for Google Private IP connectivity"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = local.default_vpc_private_peering.address
  prefix_length = local.default_vpc_private_peering.prefix_length
  network       = google_compute_network.default.self_link
  project       = data.google_project.project.project_id
}

resource "google_service_networking_connection" "service_networking" {
  provider = google

  network                 = google_compute_network.default.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.google_managed_services.name]
}
