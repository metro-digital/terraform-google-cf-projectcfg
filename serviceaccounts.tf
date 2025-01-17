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
  service_account_valid_github_repo_regex = "^[[:alnum:]-]{1,39}\\/([[:alnum:]\\._-]){1,100}$"
}

resource "google_service_account" "service_accounts" {
  provider = google
  for_each = var.service_accounts

  account_id   = each.key
  project      = data.google_project.this.project_id
  display_name = each.value.display_name
  description  = each.value.description

  lifecycle {
    precondition {
      condition     = alltrue([for repo in each.value.github_action_repositories : can(regex(local.service_account_valid_github_repo_regex, repo))])
      error_message = <<-EOE
        At least one invalid repository given for service account '${each.key}'.

        Invalid repositories:
          ${indent(2, join("\n", [for repo in each.value.github_action_repositories : "- ${repo}" if !can(regex(local.service_account_valid_github_repo_regex, repo))]))}

        Repositories must meet the following pattern: <username or organization>/<repository name>

        usernames/organizations can
          - be alpha numerical chars and hyphens
          - be between 1 and 39 chars long

        repository names can
          - be alpha numerical chars, hyphens, underscores and periods
          - be between 1 and 100 chars long
      EOE
    }
  }
}
