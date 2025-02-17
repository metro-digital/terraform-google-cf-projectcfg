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
  # Get certain data for Cloud Foundation panel managed projects from labels
  #
  # Existence of values is enforced via post condition on data.google_project. We can therefore blindly assume the
  # labels exist and reference them (or use dummy data in case the module operates in non_cf_panel_project mode).
  #
  # Conditionally storing the label values into a local, and defaulting to a special string in case of non_cf_panel_project mode
  # to avoid repeatedly writing this if statement at every usage.
  cf_mesh_env        = var.non_cf_panel_project ? "not-a-cf-panel-project" : data.google_project.this.labels["cf_mesh_env"]
  cf_customer_id     = var.non_cf_panel_project ? "not-a-cf-panel-project" : data.google_project.this.labels["cf_customer_id"]
  cf_project_id      = var.non_cf_panel_project ? "not-a-cf-panel-project" : data.google_project.this.labels["cf_project_id"]
  cf_landing_zone_id = var.non_cf_panel_project ? "not-a-cf-panel-project" : data.google_project.this.labels["cf_landing_zone_id"]

  env_group_domain = {
    qa                     = "metrosystems.net"
    prod                   = "cloudfoundation.metro.digital"
    not-a-cf-panel-project = "invalid.tld"
  }

  region_sets = {
    eu = [
      "europe-central2",
      "europe-north1",
      "europe-southwest1",
      "europe-west1",
      "europe-west3",
      "europe-west4",
      "europe-west8",
      "europe-west9",
      "europe-west10",
      "europe-west12",
    ]
    asia = [
      "asia-east1",
      "asia-east2",
      "asia-northeast1",
      "asia-northeast2",
      "asia-northeast3",
      "asia-south1",
      "asia-south2",
      "asia-southeast1",
      "asia-southeast2",
      "me-central1",
      "me-central2",
      "me-west1",
    ]
  }

  # Landing zones defined in the Cloud Foundation panel and their respective regions.
  # Storing this in dedicated local and merging it into local.landing_zone_regions
  # as this allows to use local.panel_landing_zone_regions for example in certain
  # postcondition checks for data.google_project.this.
  panel_landing_zone_regions = {
    applications-non-prod-eu   = local.region_sets.eu
    applications-prod-eu       = local.region_sets.eu
    applications-non-prod-asia = local.region_sets.asia
    applications-prod-asia     = local.region_sets.asia
    # The on-premise connectivity landing zone uses this module should not contain any VPC related resource, as any VPC
    # in this landing zone is managed by Cloud Foundation's on-premise connectivity product.
    on-prem-connectivity = []
  }

  landing_zone_regions = merge(
    local.panel_landing_zone_regions,
    {
      # Special "fake landing zone" if module operates in non_cf_panel_project mode that supports any kind of region
      not-a-cf-panel-project = distinct(flatten(values(local.region_sets)))
    }
  )

  # the observer, developer and manager group strings become invalid groups if the module
  # operates in non_cf_panel_project mode so ensure you only use them when
  # var.non_cf_panel_project is false
  observer_group_member = format(
    "group:%s.%s-observer@%s",
    local.cf_customer_id,
    local.cf_project_id,
    local.env_group_domain[local.cf_mesh_env]
  )

  developer_group_member = format(
    "group:%s.%s-developer@%s",
    local.cf_customer_id,
    local.cf_project_id,
    local.env_group_domain[local.cf_mesh_env]
  )

  manager_group_member = format(
    "group:%s.%s-manager@%s",
    local.cf_customer_id,
    local.cf_project_id,
    local.env_group_domain[local.cf_mesh_env]
  )
}
