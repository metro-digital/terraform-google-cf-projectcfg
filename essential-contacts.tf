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

resource "google_project_service" "essential_contacts" {
  project = data.google_project.this.project_id
  count   = length(var.essential_contacts) > 0 ? 1 : 0
  service = "essentialcontacts.googleapis.com"

  # The user may enable/use the needed service somewhere else, too! Hence,
  # we will never disabling it again, even if we initially enabled it here. Keeping
  # the service enabled is a lot less dangerous than disabling it, even if we do
  # not have a reason to keep it enabled any longer. Users can still disable it via
  # the CLI / UI if need be.
  disable_on_destroy = false
}

resource "google_essential_contacts_contact" "contact" {
  for_each                            = var.essential_contacts
  parent                              = data.google_project.this.id
  email                               = each.key
  language_tag                        = each.value.language
  notification_category_subscriptions = each.value.categories

  depends_on = [
    google_project_service.essential_contacts,
    google_project_iam_policy.this
  ]
}
