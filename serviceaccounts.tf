# Copyright 2021 METRO Digital GmbH
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
}

data "google_iam_policy" "service_accounts" {
  provider = google
  for_each = var.service_accounts

  dynamic "binding" {
    for_each = each.value.iam
    iterator = display_name

    content {
      role    = display_name.key
      members = display_name.value
    }
  }
}

resource "google_service_account_iam_policy" "service_accounts" {
  provider = google
  for_each = var.service_accounts

  service_account_id = google_service_account.service_accounts[each.key].id
  policy_data        = data.google_iam_policy.service_accounts[each.key].policy_data
}
