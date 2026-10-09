# Copyright 2026 METRO Digital GmbH
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

# Keep the lookup countable so disabling the check also skips the IAM API call.
data "google_service_accounts" "this" {
  count   = var.disable_unmanaged_service_accounts_check ? 0 : 1
  project = data.google_project.this.project_id
}

locals {
  # Derive identities from configured account IDs, avoiding unknown resource
  # emails when accounts are first created or replaced during this operation.
  managed_service_account_emails = toset([
    for account_id in keys(var.service_accounts) :
    format("%s@%s.iam.gserviceaccount.com", account_id, data.google_project.this.project_id)
  ])

  # Service agents normally aren't returned by projects.serviceAccounts.list.
  # Exclude their Google-owned domains defensively, but don't exclude user
  # accounts merely because their account ID starts with "service-".
  unmanaged_service_account_emails = sort(distinct([
    for account in flatten(data.google_service_accounts.this[*].accounts) : account.email
    if !contains(local.managed_service_account_emails, account.email) &&
    account.email != format("%s-compute@developer.gserviceaccount.com", data.google_project.this.number) &&
    !endswith(account.email, "@cloudservices.gserviceaccount.com") &&
    !endswith(account.email, "@system.gserviceaccount.com") &&
    !(endswith(account.email, ".iam.gserviceaccount.com") &&
    !endswith(account.email, format("@%s.iam.gserviceaccount.com", data.google_project.this.project_id)))
  ]))
}

check "unmanaged_service_accounts" {
  assert {
    condition = length(local.unmanaged_service_account_emails) == 0
    error_message = format(
      "Service accounts in project %s are not managed by this module: %s. Add them to service_accounts and import them, or set disable_unmanaged_service_accounts_check = true to disable this check.",
      data.google_project.this.project_id,
      join(", ", local.unmanaged_service_account_emails)
    )
  }
}
