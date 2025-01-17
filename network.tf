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
  # handle null value once via local
  vpc_regions = coalesce(var.vpc_regions, {})
}

resource "google_compute_network" "default" {
  provider = google
  count    = length(local.vpc_regions) > 0 ? 1 : 0

  name                    = "default"
  description             = "Default VPC network for the project"
  project                 = data.google_project.this.project_id
  auto_create_subnetworks = false
  # ensure necessary services are enabled and permissions granted
  depends_on = [
    google_project_service.this,
    google_project_iam_policy.this,
    google_project_iam_custom_role.custom_roles,
  ]
}

# create a default subnet in each enabled region
resource "google_compute_subnetwork" "default" {
  provider = google
  for_each = local.vpc_regions

  name                     = "default-${each.key}"
  description              = "Default subnet in ${each.key}"
  region                   = each.key
  private_ip_google_access = true
  ip_cidr_range            = local.default_vpc_primary_ranges[each.key]
  network                  = google_compute_network.default[0].name
  project                  = data.google_project.this.project_id

  dynamic "secondary_ip_range" {
    # use anytrue as the parameter is optional, means can be null
    for_each = each.value.gke_secondary_ranges ? local.default_vpc_secondary_ranges[each.key].gke : {}
    iterator = secondary_gke
    content {
      ip_cidr_range = secondary_gke.value
      range_name    = secondary_gke.key

    }
  }
  depends_on = [google_project_service.this]
}

resource "google_vpc_access_connector" "default" {
  provider      = google
  for_each      = { for k, v in local.vpc_regions : k => v.serverless_vpc_access if v.serverless_vpc_access != null }
  name          = each.key
  region        = each.key
  ip_cidr_range = local.default_vpc_subnet_connectors[each.key]
  project       = data.google_project.this.project_id
  network       = google_compute_network.default[0].name

  min_instances = each.value.min_instances
  max_instances = each.value.max_instances
  machine_type  = each.value.machine_type

  depends_on = [
    google_project_service.this,
    google_compute_subnetwork.default
  ]
}

resource "google_compute_subnetwork" "proxy_only" {
  provider = google
  for_each = { for k, v in local.vpc_regions : k => v if v.proxy_only }

  name          = "proxy-only-${each.key}"
  region        = each.key
  ip_cidr_range = local.default_vpc_proxy_only[each.key]
  project       = data.google_project.this.project_id
  purpose       = "INTERNAL_HTTPS_LOAD_BALANCER"
  role          = "ACTIVE"
  network       = google_compute_network.default[0].name
}

resource "google_dns_policy" "logging" {
  provider = google
  count    = var.skip_default_vpc_dns_logging_policy ? 0 : length(google_compute_network.default)

  name        = "logging"
  description = "Enable DNS logging to be compliant with Cloud policies"
  project     = var.project_id

  enable_logging = true

  networks {
    network_url = google_compute_network.default[0].id
  }

  depends_on = [
    google_project_service.this
  ]
}
