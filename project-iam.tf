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
  # Helper variables used later in this block to check if binding is caused by
  # PAM by checking the condition against those.
  pam_condition_expression_regex = "^request.time < timestamp\\(\"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\"\\)$"
  pam_condition_title            = "Created by: PAM"

  # Build a list of all roles where we want to keep the existing bindings
  project_iam_non_authoritative_roles = compact(concat(
    var.iam_policy_non_authoritative_roles,
    # Certain bindings in the projects IAM policy are caused by service agents.
    # Those against usually use special roles, see
    # https://cloud.google.com/iam/docs/service-agents
    [
      "^roles/[a-zA-Z\\.]+[sS]{1}erviceAgent$",
      "^roles/cloudbuild.builds.builder$",
      "^roles/firebaserules.system$",
    ]
  ))

  # List of bindings to always create no matter of what the user configures via input variables
  project_iam_always_existing_bindings = {
    "roles/editor" = {
      role      = "roles/editor"
      condition = null
      members   = [format("serviceAccount:%s@cloudservices.gserviceaccount.com", data.google_project.this.number)]
    },
    # Normally this should be done by Google Cloud and the role matches regex defined in
    # local.project_iam_non_authoritative_roles, so the module would import the binding.
    # But sometimes the service networking agent sometimes looses permissions, as we always enable the API we
    # also always grant the permissions.
    "roles/servicenetworking.serviceAgent" = {
      role      = "roles/servicenetworking.serviceAgent"
      condition = null
      members   = [google_project_service_identity.servicenetworking_service_account.member]
    }
    # The following bindings will always exist, as those bindings are created by our self-service portal
    # (Cloud Foundation panel), and will be added back if removed in nightly syncs.
    "roles/browser" = {
      role      = "roles/browser"
      condition = null
      members   = [local.manager_group_member, local.developer_group_member, local.observer_group_member]
    },
    "roles/cloudsupport.techSupportEditor" = {
      role      = "roles/cloudsupport.techSupportEditor"
      condition = null
      members   = [local.manager_group_member]
    },
    "organizations/1049006825317/roles/CF_Project_Billing_Viewer" = {
      role      = "organizations/1049006825317/roles/CF_Project_Billing_Viewer"
      condition = null
      members   = [local.manager_group_member]
    },
    "organizations/1049006825317/roles/CF_Project_Manager" = {
      role      = "organizations/1049006825317/roles/CF_Project_Manager"
      condition = null
      members   = [local.manager_group_member]
    }
  }

  project_iam_non_authoritative_role_bindings = {
    for binding in jsondecode(data.google_project_iam_policy.this.policy_data).bindings :
    (lookup(binding, "condition", null) == null ? binding.role : "${binding.role}#${sha1(jsonencode(binding.condition))}") => {
      role      = binding.role
      members   = binding.members
      condition = lookup(binding, "condition", null)
    } if anytrue([for regex in local.project_iam_non_authoritative_roles : can(regex(regex, binding.role))])
  }

  project_iam_pam_bindings = {
    for binding in jsondecode(data.google_project_iam_policy.this.policy_data).bindings :
    (lookup(binding, "condition", null) == null ? binding.role : "${binding.role}#${sha1(jsonencode(binding.condition))}") => {
      role      = binding.role
      members   = binding.members
      condition = lookup(binding, "condition", null)
      } if(lookup(binding, "condition", null) == null ? false : (
        var.iam_policy_keep_pam_bindings &&
        binding.condition.title == local.pam_condition_title &&
        can(regex(local.pam_condition_expression_regex, binding.condition.expression))
      )
    )
  }

  project_iam_service_account_bindings = {
    for role, members in transpose({
      for sa, sa_cfg in var.service_accounts : google_service_account.service_accounts[sa].member => sa_cfg.project_iam_policy_roles
  }) : role => { role = role, members = members, condition = null } }

  project_iam_custom_role_bindings = {
    for role, config in var.custom_roles : google_project_iam_custom_role.custom_roles[role].role_id => {
      role      = google_project_iam_custom_role.custom_roles[role].role_id
      members   = config.members
      condition = null
    }
  }

  project_iam_policy = { for binding in var.iam_policy :
    (lookup(binding, "condition", null) == null ? binding.role : "${binding.role}#${sha1(jsonencode(binding.condition))}") => {
      role      = binding.role
      members   = binding.members
      condition = lookup(binding, "condition", null)
    }
  }



  project_iam_roles_combined = toset(compact(concat(
    keys(local.project_iam_policy),
    keys(local.project_iam_custom_role_bindings),
    keys(local.project_iam_service_account_bindings),
    keys(local.project_iam_always_existing_bindings),
    keys(local.project_iam_non_authoritative_role_bindings),
    keys(local.project_iam_pam_bindings)
  )))

  project_iam_bindings_combined = { for role in local.project_iam_roles_combined :
    role => {
      role = distinct(compact(concat(
        [lookup(local.project_iam_policy, role, { role = "" }).role],
        [lookup(local.project_iam_custom_role_bindings, role, { role = "" }).role],
        [lookup(local.project_iam_service_account_bindings, role, { role = "" }).role],
        [lookup(local.project_iam_always_existing_bindings, role, { role = "" }).role],
        [lookup(local.project_iam_non_authoritative_role_bindings, role, { role = "" }).role],
        [lookup(local.project_iam_pam_bindings, role, { role = "" }).role]
      )))[0]
      members = distinct(compact(concat(
        lookup(local.project_iam_policy, role, { members = [] }).members,
        lookup(local.project_iam_custom_role_bindings, role, { members = [] }).members,
        lookup(local.project_iam_service_account_bindings, role, { members = [] }).members,
        lookup(local.project_iam_always_existing_bindings, role, { members = [] }).members,
        lookup(local.project_iam_non_authoritative_role_bindings, role, { members = [] }).members,
        lookup(local.project_iam_pam_bindings, role, { members = [] }).members
      )))
      condition = one([for condition in flatten([
        [lookup(local.project_iam_policy, role, { condition = null }).condition],
        [lookup(local.project_iam_custom_role_bindings, role, { condition = null }).condition],
        [lookup(local.project_iam_service_account_bindings, role, { condition = null }).condition],
        [lookup(local.project_iam_always_existing_bindings, role, { condition = null }).condition],
        [lookup(local.project_iam_non_authoritative_role_bindings, role, { condition = null }).condition],
        [lookup(local.project_iam_pam_bindings, role, { condition = null }).condition],
      ]) : condition if condition != null])
    }
  }
}

data "google_iam_policy" "this" {
  dynamic "binding" {
    for_each = local.project_iam_bindings_combined

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

resource "google_project_iam_policy" "this" {
  project     = data.google_project.this.project_id
  policy_data = data.google_iam_policy.this.policy_data
}
