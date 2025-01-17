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


data "google_service_account_iam_policy" "this" {
  for_each           = var.service_accounts
  service_account_id = google_service_account.service_accounts[each.key].name
}

locals {
  service_accounts_iam_non_authoritative_role_bindings = {
    for sa, config in var.service_accounts : sa => {
      for binding in lookup(jsondecode(data.google_service_account_iam_policy.this[sa].policy_data), "bindings", []) :
      (lookup(binding, "condition", null) == null ? binding.role : "${binding.role}#${sha1(jsonencode(binding.condition))}") => {
        role      = binding.role
        members   = binding.members
        condition = lookup(binding, "condition", null)
      } if anytrue([for regex in config.iam_policy_non_authoritative_roles : can(regex(regex, binding.role))])
    }
  }

  service_accounts_wif_bindings = {
    for sa, config in var.service_accounts : sa => {
      "roles/iam.workloadIdentityUser" = {
        role      = "roles/iam.workloadIdentityUser"
        condition = null
        members = compact(concat(
          [
            for repo in config.github_action_repositories : format(
              "principalSet://iam.googleapis.com/%s/attribute.repository/%s",
              google_iam_workload_identity_pool.github_actions[0].name,
              repo
            )
          ],
          [
            for runtime_sa in config.runtime_service_accounts : format(
              "principal://iam.googleapis.com/%s/subject/system:serviceaccount:%s:%s",
              google_iam_workload_identity_pool.runtime_k8s[runtime_sa.cluster_id].name,
              runtime_sa.namespace,
              runtime_sa.service_account
            )
          ]
        ))
      }
    }
  }

  service_accounts_iam_policy = {
    for sa, config in var.service_accounts : sa => { for binding in config.iam_policy :
      (lookup(binding, "condition", null) == null ? binding.role : "${binding.role}#${sha1(jsonencode(binding.condition))}") => {
        role      = binding.role
        members   = binding.members
        condition = lookup(binding, "condition", null)
      }
    }
  }

  service_accounts_iam_roles_combined = {
    for sa, config in var.service_accounts : sa => toset(compact(concat(
      keys(local.service_accounts_iam_policy[sa]),
      keys(local.service_accounts_wif_bindings[sa]),
      keys(local.service_accounts_iam_non_authoritative_role_bindings[sa])
    )))
  }

  service_accounts_iam_bindings_combined = {
    for sa, config in var.service_accounts : sa => {
      for role in local.service_accounts_iam_roles_combined[sa] :
      role => {
        role = distinct(compact(concat(
          [lookup(local.service_accounts_iam_policy[sa], role, { role = "" }).role],
          [lookup(local.service_accounts_wif_bindings[sa], role, { role = "" }).role],
          [lookup(local.service_accounts_iam_non_authoritative_role_bindings[sa], role, { role = "" }).role],
        )))[0]
        members = distinct(compact(concat(
          lookup(local.service_accounts_iam_policy[sa], role, { members = [] }).members,
          lookup(local.service_accounts_wif_bindings[sa], role, { members = [] }).members,
          lookup(local.service_accounts_iam_non_authoritative_role_bindings[sa], role, { members = [] }).members,
        )))
        condition = one([for condition in flatten([
          [lookup(local.service_accounts_iam_policy[sa], role, { condition = null }).condition],
          [lookup(local.service_accounts_wif_bindings[sa], role, { condition = null }).condition],
          [lookup(local.service_accounts_iam_non_authoritative_role_bindings[sa], role, { condition = null }).condition],
        ]) : condition if condition != null])
      }
    }
  }
}

data "google_iam_policy" "service_accounts" {
  provider = google
  for_each = local.service_accounts_iam_bindings_combined

  dynamic "binding" {
    for_each = each.value

    content {
      role    = binding.value.role
      members = binding.value.members

      # we may have a condition or not, therefor the condition becomes dynamic
      dynamic "condition" {
        # thread the single potential condition as list of conditions so we can iterate over it
        # and create an empty set if no condition exists (condition is null)
        for_each = toset([for condition in [binding.value.condition] : condition if condition != null])
        content {
          title       = condition.value.title
          expression  = condition.value.expression
          description = lookup(condition.value, "description", null)
        }
      }
    }
  }
}

resource "google_service_account_iam_policy" "service_accounts" {
  provider = google
  for_each = var.service_accounts

  service_account_id = google_service_account.service_accounts[each.key].id
  policy_data        = data.google_iam_policy.service_accounts[each.key].policy_data
}
