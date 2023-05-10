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

# Get project ID details based on project ID
data "google_project" "project" {
  provider   = google
  project_id = var.project_id
}

# Fetch needed CIDR blocks from google for firewall rules and similar
data "google_netblock_ip_ranges" "iap-forwarders" {
  provider   = google
  range_type = "iap-forwarders"
}

data "external" "metro_netblocks" {
  provider = external
  program  = ["bash", "${path.module}/get-metro-netblocks.sh"]
}

locals {
  metro_netblocks = {
    ipv4 = split(" ", data.external.metro_netblocks.result.ipv4)
    ipv6 = split(" ", data.external.metro_netblocks.result.ipv6)
  }
}

data "google_client_config" "current" {
}

# active IAM roles
data "external" "active-roles" {
  program = ["bash", "${path.module}/get-active-roles-project-iam.sh"]
  query = {
    project_id   = data.google_project.project.project_id
    access_token = data.google_client_config.current.access_token
  }
}

locals {
  role_excludes = compact(concat(
    var.non_authoritative_roles,
    [
      # See: https://cloud.google.com/iam/docs/service-agents
      "\\.serviceAgent$",
      "\\.ServiceAgent$",
      "^roles/cloudbuild.builds.builder$",
      "^roles/securitycenter.notificationServiceAgent$",
      "^roles/monitoring.notificationServiceAgent$",
      "^roles/firebaserules.system$",
      "^roles/container.nodeServiceAgent$"
    ]
  ))

  # Split the list of active roles from the external data source
  active_roles_splitted = split(",", data.external.active-roles.result.roles)
  # exclude all project or org level custom roles
  active_roles_no_custom = [for role in local.active_roles_splitted : role if can(regex("^roles/", role))]
  # get a list of active roles we need to exclude (assigned to service accounts automatically and similar)
  active_roles_to_exclude = compact(flatten([
    for role in local.active_roles_no_custom : [
      for exclude in local.role_excludes : role if can(regex(exclude, role))
    ]
  ]))
  # remove the roles to exclude from the active roles
  active_roles = tolist(setsubtract(local.active_roles_no_custom, local.active_roles_to_exclude))
}
