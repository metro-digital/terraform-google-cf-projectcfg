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
  # checked in post condition for data.google_project.project
  env_group_domain = {
    qa   = "metrosystems.net"
    prod = "cloudfoundation.metro.digital"
  }
  group_domain = local.env_group_domain[data.google_project.this.labels["cf_mesh_env"]]

  observer_group = format(
    "%s.%s-observer@%s",
    data.google_project.this.labels["cf_customer_id"],
    data.google_project.this.labels["cf_project_id"],
    local.group_domain
  )
  observer_group_member = "group:${local.observer_group}"

  developer_group = format(
    "%s.%s-developer@%s",
    data.google_project.this.labels["cf_customer_id"],
    data.google_project.this.labels["cf_project_id"],
    local.group_domain
  )
  developer_group_member = "group:${local.developer_group}"


  manager_group = format(
    "%s.%s-manager@%s",
    data.google_project.this.labels["cf_customer_id"],
    data.google_project.this.labels["cf_project_id"],
    local.group_domain
  )
  manager_group_member = "group:${local.manager_group}"
}
