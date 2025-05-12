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
  serviceaccounts_tag_bindings = merge([
    for sa, config in var.service_accounts : {
      for tag_value in lookup(config, "tags", []) : format("%s#%s", sa, tag_value) => {
        parent    = format("//iam.googleapis.com/projects/%s/serviceAccounts/%s", data.google_project.this.number, google_service_account.service_accounts[sa].unique_id)
        tag_value = tag_value
      }
    }
  ]...)
}

resource "google_tags_tag_binding" "serviceaccounts" {
  for_each = local.serviceaccounts_tag_bindings

  parent    = each.value.parent
  tag_value = each.value.tag_value
}
