# Copyright 2022 METRO Digital GmbH
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
  #
  # Please always also update docs/DEFAULT-VPC.md when doing changes here!
  #
  # Network IP range planing:
  #   - we do use 172.16.0.0/12 as it is least used within METRO
  #
  # 172.16.0.0/15 = 172.16.0.0 to 172.17.255.255
  # Used for subnetworks in different regions - allows 32 regions when using /20
  default_vpc_primary_ranges = {
    europe-west1      = "172.16.0.0/20"   # St. Ghislain, Belgium, EU
    europe-west9      = "172.16.16.0/20"  # Paris, France, EU
    europe-west3      = "172.16.32.0/20"  # Frankfurt, Germany EU
    europe-west4      = "172.16.48.0/20"  # Eemshaven, Netherlands, EU
    europe-north1     = "172.16.64.0/20"  # Hamina, Finland, EU
    europe-central2   = "172.16.80.0/20"  # Warsaw, Poland, EU
    europe-southwest1 = "172.16.96.0/20"  # Madrid, Spain, EU
    europe-west8      = "172.16.112.0/20" # Milan, Italy, EU
  }

  # 172.18.0.0/23 = 172.18.0.0 to 172.18.1.255
  # Used for serverless access vpc connectors in different regions

  default_vpc_subnet_connectors = {
    europe-west1      = "172.18.0.0/28"
    europe-west9      = "172.18.0.16/28"
    europe-west3      = "172.18.0.32/28"
    europe-west4      = "172.18.0.48/28"
    europe-north1     = "172.18.0.64/28"
    europe-central2   = "172.18.0.80/28"
    europe-southwest1 = "172.18.0.96/28"
    europe-west8      = "172.18.0.112/28"
  }

  default_vpc_proxy_only = {
    europe-west1      = "172.18.64.0/23"
    europe-west9      = "172.18.66.0/23"
    europe-west3      = "172.18.68.0/23"
    europe-west4      = "172.18.70.0/23"
    europe-north1     = "172.18.72.0/23"
    europe-central2   = "172.18.74.0/23"
    europe-southwest1 = "172.18.76.0/23"
    europe-west8      = "172.18.78.0/23"
  }

  default_vpc_secondary_ranges = {
    europe-west1 = {
      gke = {
        gke-services = "10.0.0.0/20"
        gke-pods     = "10.32.0.0/16"
      }
    }
    europe-west9 = {
      gke = {
        gke-services = "10.0.16.0/20"
        gke-pods     = "10.33.0.0/16"
      }
    }
    europe-west3 = {
      gke = {
        gke-services = "10.0.32.0/20"
        gke-pods     = "10.34.0.0/16"
      }
    }
    europe-west4 = {
      gke = {
        gke-services = "10.0.48.0/20"
        gke-pods     = "10.35.0.0/16"
      }
    }
    europe-north1 = {
      gke = {
        gke-services = "10.0.64.0/20"
        gke-pods     = "10.36.0.0/16"
      }
    }
    europe-central2 = {
      gke = {
        gke-services = "10.0.80.0/20"
        gke-pods     = "10.37.0.0/16"
      }
    }
    europe-southwest1 = {
      gke = {
        gke-services = "10.255.96.0/20"
        gke-pods     = "10.38.0.0/16"
      }
    }
    europe-west8 = {
      gke = {
        gke-services = "10.0.144.0/20"
        gke-pods     = "10.39.0.0/16"
      }
    }
  }

  # 172.20.0.0/16 = 172.20.0.0 to 172.20.255.255
  # Used for VPC peerings (Private Service Access)
  default_vpc_private_peering = {
    address       = "172.20.0.0"
    prefix_length = "16"
  }

  # Helper to get ALL active IPs in a VPC
  default_vpc_active_ranges = compact(concat(
    [for r in keys(var.vpc_regions) : local.default_vpc_primary_ranges[r]],
    [for r in keys(var.vpc_regions) : local.default_vpc_subnet_connectors[r] if var.vpc_regions[r].vpcaccess],
    ["${local.default_vpc_private_peering.address}/${local.default_vpc_private_peering.prefix_length}"],
    # use anytrue as the gke_secondary_ranges parameter is optional, means can be null
    [for r in keys(var.vpc_regions) : local.default_vpc_secondary_ranges[r].gke.gke-pods if anytrue([var.vpc_regions[r].gke_secondary_ranges])],
    [for r in keys(var.vpc_regions) : local.default_vpc_secondary_ranges[r].gke.gke-services if anytrue([var.vpc_regions[r].gke_secondary_ranges])]
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
  ip_cidr_range            = local.default_vpc_primary_ranges[each.key]
  network                  = google_compute_network.default[0].name
  project                  = data.google_project.project.project_id

  dynamic "secondary_ip_range" {
    # use anytrue as the parameter is optional, means can be null
    for_each = anytrue([each.value.gke_secondary_ranges]) ? local.default_vpc_secondary_ranges[each.key].gke : {}
    iterator = secondary_gke
    content {
      ip_cidr_range = secondary_gke.value
      range_name    = secondary_gke.key

    }
  }
  depends_on = [google_project_service.project]
}

resource "google_vpc_access_connector" "default" {
  provider = google
  for_each = var.skip_default_vpc_creation ? {} : {
    for r in keys(var.vpc_regions) : r => {
      cidr = local.default_vpc_subnet_connectors[r]
  } if var.vpc_regions[r].vpcaccess }

  name          = each.key
  region        = each.key
  ip_cidr_range = each.value.cidr
  project       = data.google_project.project.project_id
  network       = google_compute_network.default[0].name
  depends_on = [
    google_project_service.project,
    google_compute_subnetwork.default
  ]
}

resource "google_compute_subnetwork" "proxy-only" {
  provider = google
  for_each = var.skip_default_vpc_creation ? {} : {
    for r in keys(var.vpc_regions) : r => {
      cidr = local.default_vpc_proxy_only[r]
      # use anytrue as the parameter is optional, means can be null
  } if anytrue([var.vpc_regions[r].proxy_only]) }

  name          = "proxy-only-${each.key}"
  region        = each.key
  ip_cidr_range = each.value.cidr
  project       = data.google_project.project.project_id
  purpose       = "INTERNAL_HTTPS_LOAD_BALANCER"
  role          = "ACTIVE"
  network       = google_compute_network.default[0].name
}
