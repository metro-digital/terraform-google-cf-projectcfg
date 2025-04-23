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
  # When constructing the final authoritative IAM policy for a project, we need to
  # gather information from multiple sources:
  #
  #   - User Input: Information regarding the project's IAM policy, custom roles, and service accounts.
  #   - Cloud Foundation Panel: Bindings created within this panel.
  #   - PAM (Privileged Access Management): Included unless disabled by user input.
  #   - Existing Bindings: Bindings for non-authoritative roles that are already in place.
  #   - Google Service Agent Bindings: These are added to the list of non-authoritative roles.
  #
  # For better readability and to facilitate understanding, we compile the list of bindings individually from
  # the majority of the aforementioned sources in different maps stored as locals.
  #
  # Each of those maps constructed should follow this structure:
  #   - Key: The name of the role, optionally followed by a "#" and the SHA1 sum
  #          if an IAM condition is present (see explanation below).
  #   - Value: An object with the keys: role, condition, and members.
  #
  # This structure reflects how Google's APIs expect IAM policies to be formatted and aligns with how Google's
  # Terraform provider constructs IAM policies. For more details, see the Terraform IAM policy documentation:
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/iam_policy
  # A role can have exactly one binding without an IAM condition. If a condition is specified, the binding for this
  # role becomes unique, allowing multiple bindings with the same role to exist. The same happens with our definition
  # of the key.


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

  # If the project is managed via Cloud Foundation panel, the following bindings will always exist,
  # as those bindings are created by our self-service portal (Cloud Foundation panel), and will be added back
  # in nightly syncs if removed. Currently all landing zones come with the same set of bindings. As this may
  # changes in the future, we already keep the binding in a dedicated variable for better adjustability.
  project_iam_panel_bindings = {
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

  # Bindings created by Google no matter of what the user configures via input variables
  project_iam_google_default_bindings = {
    # The Google APIs Service Agent usually comes with roles/editor permissions. Changing this is possible,
    # but not advised as this can cause issues with for example managed instance groups.
    # See: https://cloud.google.com/compute/docs/access/service-accounts#google_apis_service_agent
    "roles/editor" = {
      role      = "roles/editor"
      condition = null
      members   = [format("serviceAccount:%s@cloudservices.gserviceaccount.com", data.google_project.this.number)]
    },
    # Normally this binding should exist because it's created by Google Cloud and the role matches regex defined in
    # local.project_iam_non_authoritative_roles, so the module would import the binding.
    # But sometimes the service networking agent looses permissions. Therefore, as we always enable the API we
    # also always grant the permissions.
    "roles/servicenetworking.serviceAgent" = {
      role      = "roles/servicenetworking.serviceAgent"
      condition = null
      members   = [google_project_service_identity.servicenetworking_service_account.member]
    }
  }

  # List of bindings to always create
  project_iam_always_existing_bindings = merge(
    local.project_iam_google_default_bindings,
    # If it's a Cloud Foundation panel project, we also want those bindings
    var.non_cf_panel_project ? {} : local.project_iam_panel_bindings
  )

  # Get all currently existing role bindings and match them against the list of non non-authoritative roles.
  # If a role is marked as non-authoritative we also ignore those with an IAM condition on it.
  project_iam_non_authoritative_role_bindings = { for binding in jsondecode(data.google_project_iam_policy.this.policy_data).bindings :
    # key may needs to contain hashed IAM condition
    (lookup(binding, "condition", null) == null ? binding.role : "${binding.role}#${sha1(jsonencode(binding.condition))}") => {
      role      = binding.role
      members   = binding.members
      condition = lookup(binding, "condition", null)
    } if anytrue([for regex in local.project_iam_non_authoritative_roles : can(regex(regex, binding.role))])
  }

  # PAM bindings are just bindings with an IAM condition specially formatted and matching a regex
  project_iam_pam_bindings = {
    for binding in jsondecode(data.google_project_iam_policy.this.policy_data).bindings :
    # key may needs to contain hashed IAM condition
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

  # We currently do not support IAM conditions for the project level role assignment via service accounts input
  project_iam_service_account_bindings = {
    for role, members in transpose({
      for sa, sa_cfg in var.service_accounts : google_service_account.service_accounts[sa].member => sa_cfg.project_iam_policy_roles
  }) : role => { role = role, members = members, condition = null } }

  # We currently do not support IAM conditions for the project level role assignment via custom role input
  project_iam_custom_role_bindings = {
    for role, config in var.custom_roles : google_project_iam_custom_role.custom_roles[role].role_id => {
      role      = google_project_iam_custom_role.custom_roles[role].id
      members   = config.project_iam_policy_members
      condition = null
    }
  }

  # Construct all IAM policy bindings for the user's input
  project_iam_policy_bindings = { for binding in var.iam_policy :
    (lookup(binding, "condition", null) == null ? binding.role : "${binding.role}#${sha1(jsonencode(binding.condition))}") => {
      role      = binding.role
      members   = binding.members
      condition = lookup(binding, "condition", null)
    }
  }

  # Helper variable that holds every role mentioned in any of the list of bindings generated above.
  # Used to build the final list that merges all the different bindings into the final policy
  project_iam_roles_combined = toset(compact(concat(
    keys(local.project_iam_policy_bindings),
    keys(local.project_iam_custom_role_bindings),
    keys(local.project_iam_service_account_bindings),
    keys(local.project_iam_always_existing_bindings),
    keys(local.project_iam_non_authoritative_role_bindings),
    keys(local.project_iam_pam_bindings)
  )))

  # Merging all different kind of binding sources (always existing ones, user input, non-authoritative roles, PAM, ..)
  # into the final policy to be applied on project level.
  project_iam_bindings_combined = { for role in local.project_iam_roles_combined :
    role => {
      role = distinct(compact(concat(
        [lookup(local.project_iam_policy_bindings, role, { role = "" }).role],
        [lookup(local.project_iam_custom_role_bindings, role, { role = "" }).role],
        [lookup(local.project_iam_service_account_bindings, role, { role = "" }).role],
        [lookup(local.project_iam_always_existing_bindings, role, { role = "" }).role],
        [lookup(local.project_iam_non_authoritative_role_bindings, role, { role = "" }).role],
        [lookup(local.project_iam_pam_bindings, role, { role = "" }).role]
      )))[0]
      # filter out deleted principals as they cant be used in IAM policies
      members = [for member in distinct(compact(concat(
        lookup(local.project_iam_policy_bindings, role, { members = [] }).members,
        lookup(local.project_iam_custom_role_bindings, role, { members = [] }).members,
        lookup(local.project_iam_service_account_bindings, role, { members = [] }).members,
        lookup(local.project_iam_always_existing_bindings, role, { members = [] }).members,
        lookup(local.project_iam_non_authoritative_role_bindings, role, { members = [] }).members,
        lookup(local.project_iam_pam_bindings, role, { members = [] }).members
      ))) : member if !startswith(member, "deleted:")]
      condition = one([for condition in flatten([
        [lookup(local.project_iam_policy_bindings, role, { condition = null }).condition],
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
      # We may have a condition or not, therefore the condition becomes dynamic
      dynamic "condition" {
        # Treat the single potential condition as list of conditions so we can iterate over it
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

  depends_on = [
    google_project_service_identity.servicenetworking_service_account
  ]
}
