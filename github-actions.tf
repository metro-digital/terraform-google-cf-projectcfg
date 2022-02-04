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
  github_actions_enabled = length(compact([
    for sa, config in var.service_accounts : sa if can(length(config.github_action_repositories) > 0)
  ])) > 0 ? 1 : 0
}

resource "google_iam_workload_identity_pool" "github-actions" {
  count    = local.github_actions_enabled
  provider = google-beta
  project  = data.google_project.project.project_id

  workload_identity_pool_id = "github-actions"
  display_name              = "Github actions"
  description               = "Identity pool github actions pipelines"

  depends_on = [
    google_project_iam_binding.roles
  ]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  count    = local.github_actions_enabled
  provider = google-beta
  project  = data.google_project.project.project_id

  workload_identity_pool_id          = google_iam_workload_identity_pool.github-actions[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"
  description                        = "OIDC Identity Pool Provider for GitHub Actions pipelines"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
