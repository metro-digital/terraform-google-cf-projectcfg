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

locals {
  # get all GitHub repository owners into a helper variable
  workload_identity_pool_repository_owners = distinct(
    flatten(
      [for sa, config in var.service_accounts :
        [for repo in config.github_action_repositories : split("/", repo)[0]]
      ]
    )
  )

  workload_identity_pool_attribute_condition = var.workload_identity_pool_attribute_condition != null ? var.workload_identity_pool_attribute_condition : format(
    "assertion.repository_owner in %s",
    jsonencode(local.workload_identity_pool_repository_owners)
  )
}

resource "google_iam_workload_identity_pool" "github_actions" {
  provider = google
  count    = local.github_actions_enabled
  project  = data.google_project.project.project_id

  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "Identity pool github actions pipelines"

  depends_on = [
    google_project_iam_binding.roles,
    google_project_service.wif
  ]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  provider = google
  count    = local.github_actions_enabled
  project  = data.google_project.project.project_id

  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"
  description                        = "OIDC Identity Pool Provider for GitHub Actions pipelines"

  attribute_mapping = var.workload_identity_pool_attribute_mapping
  # For certain issuer URLs Google enforces an attribute condition. GitHub is one of those.
  # See also: https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines#conditions
  attribute_condition = local.workload_identity_pool_attribute_condition

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  depends_on = [
    google_iam_workload_identity_pool.github_actions
  ]
}
