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
  always_add_permissions = {
    "roles/editor" = [
      format("serviceAccount:%s@cloudservices.gserviceaccount.com", data.google_project.project.number)
    ]
  }

  sa_roles = compact(flatten(concat([for sa, sa_cfg in var.service_accounts : sa_cfg.project_roles if sa_cfg.project_roles != null])))

  managed_roles = toset(
    compact(
      concat(
        keys(local.always_add_permissions),
        local.active_roles,
        keys(var.roles),
        local.sa_roles
      )
    )
  )
}

resource "google_project_iam_binding" "roles" {
  provider = google
  for_each = local.managed_roles

  project = data.google_project.project.project_id
  role    = each.key

  members = compact(
    concat(
      contains(keys(var.roles), each.key) ? var.roles[each.key] : [],
      contains(keys(local.always_add_permissions), each.key) ? local.always_add_permissions[each.key] : [],
      [for sa, sa_cfg in var.service_accounts :
        "serviceAccount:${google_service_account.service_accounts[sa].email}"
        if contains(sa_cfg.project_roles != null ? sa_cfg.project_roles : [], each.key)
      ]
    )
  )

  depends_on = [
    google_service_account.service_accounts
  ]
}

# Custom roles
resource "google_project_iam_custom_role" "custom_roles" {
  provider = google
  for_each = var.custom_roles

  role_id     = each.key
  title       = each.value.title
  description = each.value.description
  permissions = each.value.permissions
  project     = data.google_project.project.project_id
}

resource "google_project_iam_binding" "custom_roles" {
  provider = google
  for_each = var.custom_roles

  project = data.google_project.project.project_id
  role    = "projects/${data.google_project.project.project_id}/roles/${google_project_iam_custom_role.custom_roles[each.key].role_id}"
  members = each.value.members

  depends_on = [
    google_project_service.project,
    google_service_account.service_accounts
  ]
}
