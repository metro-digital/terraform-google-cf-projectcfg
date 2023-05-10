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

output "project_id" {
  description = "GCP project ID"
  value       = data.google_project.project.project_id

  depends_on = [
    # external data sources
    data.external.active-roles,
    data.external.metro_netblocks,
    data.external.sa_non_authoritative_role_members,
    # iam project roles
    google_project_iam_binding.roles,
    google_project_iam_binding.custom_roles,
  ]
}

output "service_accounts" {
  description = "List of service accounts created"
  value = {
    for name, data in google_service_account.service_accounts : name => data.email
  }

  depends_on = [
    google_service_account.service_accounts
  ]
}

output "metro_netblocks" {
  description = <<-EOD
    METRO public netblocks detected and used by this module

    Structure:
    {
      ipv4 = list(string)
      ipv6 = list(string)
    }
  EOD
  value       = local.metro_netblocks
}
