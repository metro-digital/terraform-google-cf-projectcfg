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

output "current_user" {
  description = "The email address of the authenticated Google client (provider user)"
  value       = data.google_client_openid_userinfo.provider.email
}

output "gcloud_user" {
  description = "The active account configured in gcloud CLI passed to the bootstrap"
  value       = var.active_gcloud_account
}
