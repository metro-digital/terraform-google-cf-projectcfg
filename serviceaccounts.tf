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

resource "google_service_account" "service_accounts" {
  provider = google
  for_each = var.service_accounts

  account_id   = each.key
  project      = data.google_project.project.project_id
  display_name = each.value.display_name
  description  = each.value.description
}

locals {
  non_authoritative_roles = {
    for binding in flatten([
      for sa, config in var.service_accounts : [
        for role in config.iam_non_authoritative_roles : {
          format("%s#%s", sa, role) = {
            sa           = sa
            role         = role
            sa_unique_id = google_service_account.service_accounts[sa].unique_id
          }
        }
      ] if config.iam_non_authoritative_roles != null
    ]) : keys(binding)[0] => binding[keys(binding)[0]]
  }
}

data "external" "sa_non_authoritative_role_members" {
  for_each = local.non_authoritative_roles

  program = ["bash", "${path.module}/get-sa-iam-role-members.sh"]
  query = {
    project_id   = data.google_project.project.project_id
    access_token = data.google_client_config.current.access_token
    sa_unique_id = each.value.sa_unique_id
    role         = each.value.role
  }

  depends_on = [
    google_service_account.service_accounts
  ]
}

# Please check service_accounts variable description for details
data "google_iam_policy" "service_accounts" {
  provider = google
  for_each = var.service_accounts

  # authoritative roles without roles/iam.workloadIdentityUser
  dynamic "binding" {
    for_each = {
      for role, members in each.value.iam : role => members if role != "roles/iam.workloadIdentityUser"
    }
    iterator = binding

    content {
      role    = binding.key
      members = binding.value
    }
  }

  # non-authoritative roles without roles/iam.workloadIdentityUser
  dynamic "binding" {
    for_each = {
      for non_authoritiv_role, role_config in local.non_authoritative_roles :
      non_authoritiv_role => role_config if role_config.sa == each.key && non_authoritiv_role != "roles/iam.workloadIdentityUser"
    }
    iterator = binding

    content {
      role    = binding.value.role
      members = split(",", data.external.sa_non_authoritative_role_members[binding.key].result.members)
    }
  }

  binding {
    members = compact(concat(
      # GitHub repos
      each.value.github_action_repositories != null ? [
        for repo in each.value.github_action_repositories : format(
          "principalSet://iam.googleapis.com/%s/attribute.repository/%s",
          google_iam_workload_identity_pool.github-actions[0].name,
          repo
        )
      ] : [],
      # if roles/iam.workloadIdentityUser is given by user in the authoritative iam section pick this data
      contains(keys(each.value.iam), "roles/iam.workloadIdentityUser") ? each.value.iam["roles/iam.workloadIdentityUser"] :
      # else pick existing data fetched via script if role exists in the authoritative iam parameter
      # reading from the local instead of each.value.iam_non_authoritative_roles as this could be null
      # and the local already has null handling
      contains(keys(local.non_authoritative_roles), "${each.key}#roles/iam.workloadIdentityUser") ? split(
        ",", data.external.sa_non_authoritative_role_members["${each.key}#roles/iam.workloadIdentityUser"].result.members
        # otherwise do not pick any data
      ) : [],
    ))
    role = "roles/iam.workloadIdentityUser"
  }

  depends_on = [
    google_service_account.service_accounts
  ]
}

resource "google_service_account_iam_policy" "service_accounts" {
  provider = google
  for_each = var.service_accounts

  service_account_id = google_service_account.service_accounts[each.key].id
  policy_data        = data.google_iam_policy.service_accounts[each.key].policy_data

  depends_on = [
    google_service_account.service_accounts
  ]
}

# servicenetworking.googleapis.com is always enabled by this module
# but sometimes this permission is not set on the needed service account.
# This resource makes sure it's always there.
resource "google_project_service_identity" "servicenetworking-service-account" {
  provider = google-beta

  project = data.google_project.project.project_id
  service = "servicenetworking.googleapis.com"
}

resource "google_project_iam_member" "servicenetworking-service-account-binding" {
  project = data.google_project.project.project_id
  role    = "roles/servicenetworking.serviceAgent"
  member  = "serviceAccount:${google_project_service_identity.servicenetworking-service-account.email}"

  depends_on = [
    google_project_service.project
  ]
}
