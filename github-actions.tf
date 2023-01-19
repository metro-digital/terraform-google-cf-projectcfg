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
  # Check if ANY given service account has a GitHub action repository configured.
  github_actions_enabled = length(compact([
    for sa, config in var.service_accounts : sa if can(length(config.github_action_repositories) > 0)
  ])) > 0 ? 1 : 0

  # We also need to enable some services to make the Workload Identity Federation setup possible.
  github_actions_needed_services = local.github_actions_enabled > 0 ? toset([
    "cloudresourcemanager.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com"
  ]) : toset([])
}

resource "google_project_service" "github-actions" {
  project  = data.google_project.project.project_id
  for_each = local.github_actions_needed_services
  service  = each.key

  # The user may enable/use the needed services somewhere else, too!
  # Hence, we are never disabling them again, even if we initially enabled them here.
  # Keeping the service enabled is way less dangerous than disabling them, even if
  # we do not have a reason to keep them enabled any longer. Users can still disable
  # via CLI / UI if needed.
  disable_on_destroy = false
}

resource "google_iam_workload_identity_pool" "github-actions" {
  provider = google
  count    = local.github_actions_enabled
  project  = data.google_project.project.project_id

  workload_identity_pool_id = "github-actions"
  display_name              = "Github actions"
  description               = "Identity pool github actions pipelines"

  depends_on = [
    google_project_iam_binding.roles,
    google_project_service.github-actions
  ]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  provider = google
  count    = local.github_actions_enabled
  project  = data.google_project.project.project_id

  workload_identity_pool_id          = google_iam_workload_identity_pool.github-actions[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"
  description                        = "OIDC Identity Pool Provider for GitHub Actions pipelines"

  attribute_mapping = var.workload_identity_pool_attribute_mapping

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  depends_on = [
    google_iam_workload_identity_pool.github-actions
  ]
}
