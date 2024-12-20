# Copyright 2024 METRO Digital GmbH
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

resource "google_project_iam_custom_role" "custom_roles" {
  provider = google
  for_each = var.custom_roles

  project     = data.google_project.this.project_id
  role_id     = each.key
  title       = each.value.title
  description = each.value.description
  permissions = each.value.permissions
}
